import {beforeEach,expect,it} from 'vitest';
import {applyD1Migrations} from 'cloudflare:test';
import {env} from 'cloudflare:workers';
import {createApp} from '../../src/http/router';

beforeEach(async()=>{
 await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'),...['spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
 await applyD1Migrations(env.DB,env.MIGRATIONS);
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','o','owner','Owner',1),('customer','c','customer','Customer',1),('other','x','owner','Other',1); INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Store','active',1),('other','other','Other','active',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1)");
});
function setup(){
 const events:unknown[]=[];
 const app=createApp({db:env.DB,authenticate:async request=>{
 const id=request.headers.get('Authorization');return id?{userId:id,role:id==='customer'?'customer' as const:'owner' as const}:null;
 },logger:e=>events.push(e)});
 const call=(body:unknown,owner='owner',shop='shop')=>app.fetch(new Request(`https://test/v1/shops/${shop}/entries`,{method:'POST',headers:{Authorization:owner,'Content-Type':'application/json'},body:JSON.stringify(body)}));
 const command=(overrides={})=>({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'credit',amountPaise:50000,note:'SENSITIVE_NOTE',dueDate:'2026-12-15',occurredAtMs:Date.now(),...overrides});
 return {call,command,events,app};
}
const state=()=>env.DB.prepare("SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id='link'").first();
it('D08 credit posts exact effect, immutable entry and atomic receipt; original replay survives later credits',async()=>{
 const s=setup(),body=s.command();
 const first=await s.call(body);expect(first.status).toBe(201);
 const data=(await first.json() as {data:Record<string,unknown>}).data;
 expect(data).toMatchObject({entry:{kind:'credit',amountPaise:50000,effectPaise:50000,shopId:'shop',linkId:'link'},balance:{balancePaise:50000,ledgerVersion:1},replayed:false});
 expect((await s.call(s.command({amountPaise:1}))).status).toBe(201);
 const replay=await s.call(body);expect(replay.status).toBe(200);
 expect(await replay.json()).toMatchObject({data:{...data,replayed:true}});
 expect(await state()).toEqual({balance_paise:50001,version:2});
 expect(await env.DB.prepare('SELECT SUM(effect_paise) AS balance FROM ledger_entries').first('balance')).toBe(50001);
 expect((await s.call({...body,amountPaise:50001})).status).toBe(409);
 await expect(env.DB.prepare('UPDATE ledger_entries SET amount_paise=1').run()).rejects.toThrow();
 expect(JSON.stringify(s.events)).not.toContain('SENSITIVE_NOTE');
});
it('D08 concurrent duplicate credits have one effect and distinct credits serialize',async()=>{
 const s=setup(),body=s.command();
 const responses=await Promise.all([s.call(body),s.call(body)]);
 expect(responses.map(r=>r.status).sort()).toEqual([200,201]);
 expect(await state()).toEqual({balance_paise:50000,version:1});
 const distinct=await Promise.all([s.call(s.command({amountPaise:1})),s.call(s.command({amountPaise:2}))]);
 expect(distinct.map(r=>r.status)).toEqual([201,201]);
 expect(await state()).toEqual({balance_paise:50003,version:3});
});
it('D08 invalid amounts, dates, timestamps, notes and forged fields create no entry',async()=>{
 const s=setup();
 for(const overrides of [{amountPaise:0},{amountPaise:-1},{amountPaise:1.1},{amountPaise:10000001},{amountPaise:'50000'},{note:'x'.repeat(501)},{dueDate:'2026-02-30'},{occurredAtMs:Date.now()+600000},{kind:'payment'},{effectPaise:1},{clientOperationId:crypto.randomUUID()+'\n'}]) expect((await s.call(s.command(overrides))).status).toBe(400);
 expect(await state()).toEqual({balance_paise:0,version:0});
 for(const amountPaise of [1,10000000]) expect((await s.call(s.command({amountPaise}))).status).toBe(201);
});
it('D08 wrong owner, customer writes, missing auth, wrong link and removed access are denied',async()=>{
 const s=setup();
 for(const [owner,shop,status] of [['other','shop',404],['customer','shop',403],['','shop',401],['owner','other',404]] as const) expect((await s.call(s.command(),owner,shop)).status).toBe(status);
 expect((await s.call(s.command({linkId:'missing'}))).status).toBe(404);
 const body=s.command();expect((await s.call(body)).status).toBe(201);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");
 expect((await s.call(body)).status).toBe(404);
 expect(await state()).toEqual({balance_paise:50000,version:1});
});
it('D08 later receipt failure rolls back entry, effective row and balance',async()=>{
 const s=setup();await env.DB.exec("CREATE TRIGGER test_receipt_failure BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'SYNTHETIC_FAILURE'); END");
 expect((await s.call(s.command())).status).toBe(500);
 expect(await state()).toEqual({balance_paise:0,version:0});
 for(const table of ['ledger_entries','entry_effective','sync_operations'])expect(await env.DB.prepare(`SELECT COUNT(*) AS count FROM ${table}`).first('count')).toBe(0);
});
it('D08 balance overflow rejects credit without changing state',async()=>{
 const s=setup();await env.DB.exec("UPDATE ledger_accounts SET balance_paise=9007199254740991 WHERE shop_customer_id='link'");
 const response=await s.call(s.command({amountPaise:1}));expect(response.status).toBe(409);
 expect(await state()).toEqual({balance_paise:9007199254740991,version:0});
});

it('D08 balance reads match independent effects and deny cross-tenant/customer access',async()=>{
 const s=setup();expect((await s.call(s.command())).status).toBe(201);
 const get=(path:string,user:string)=>s.app.fetch(new Request('https://test'+path,{headers:{Authorization:user}}));
 for(const [path,user] of [['/v1/shops/shop/customers/link/balance','owner'],['/v1/me/ledgers/shop/balance','customer']]) {
  const response=await get(path,user);expect(response.status).toBe(200);expect(await response.json()).toMatchObject({data:{balancePaise:50000,ledgerVersion:1,asOfServerSeq:1}});
 }
 expect((await get('/v1/shops/shop/customers/link/balance','other')).status).toBe(404);
 expect((await get('/v1/me/ledgers/other/balance','customer')).status).toBe(404);
 expect((await get('/v1/me/ledgers/shop/balance','owner')).status).toBe(403);
});
it('D08 authorization removed between pre-read and commit rejects the entire command',async()=>{
 const s=setup(),{postCredit}=await import('../../src/ledger/commands');
 const guarded=new Proxy(env.DB,{get(target,key){
  if(key==='batch')return async(statements:D1PreparedStatement[])=>{
   await env.DB.exec("UPDATE shops SET status='closed',closed_at_ms=2 WHERE id='shop'");return target.batch(statements);
  };
  const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
 }});
 await expect(postCredit(guarded,{userId:'owner',role:'owner'},'shop',s.command() as import('../../src/ledger/commands').CreditCommand)).rejects.toMatchObject({code:'NOT_FOUND'});
 expect(await state()).toEqual({balance_paise:0,version:0});
});
it('D08 body cap and invalid route IDs fail without posting',async()=>{
 const s=setup();const body=s.command({note:'x'.repeat(5000)});
 expect((await s.call(body)).status).toBe(413);
 expect((await s.call(s.command(),'owner','bad.id')).status).toBe(400);
 expect(await state()).toEqual({balance_paise:0,version:0});
});
