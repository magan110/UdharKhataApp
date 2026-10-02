import {beforeEach,expect,it} from 'vitest';
import {applyD1Migrations} from 'cloudflare:test';
import {env} from 'cloudflare:workers';
import {createApp} from '../../src/http/router';
beforeEach(async()=>{
 await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'),...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
 await applyD1Migrations(env.DB,env.MIGRATIONS);
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','o','owner','Owner',1),('customer','c','customer','Customer',1),('other','x','owner','Other',1); INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Store','active',1),('other','other','Other','active',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1)");
});
function setup(){
 const events:unknown[]=[];
 const app=createApp({db:env.DB,authenticate:async request=>{const id=request.headers.get('Authorization');return id?{userId:id,role:id==='customer'?'customer' as const:'owner' as const}:null;},logger:e=>events.push(e)});
 const call=(body:unknown,owner='owner',shop='shop')=>app.fetch(new Request(`https://test/v1/shops/${shop}/entries`,{method:'POST',headers:{Authorization:owner,'Content-Type':'application/json'},body:JSON.stringify(body)}));
 const payment=(overrides={})=>({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'payment',amountPaise:20000,paymentMethod:'cash',occurredAtMs:Date.now(),...overrides});
 const credit=()=>call({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'credit',amountPaise:50000,occurredAtMs:Date.now()});
 const get=(path:string,user:string)=>app.fetch(new Request('https://test'+path,{headers:{Authorization:user}}));
 return {call,payment,credit,get,events};
}
const state=()=>env.DB.prepare("SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id='link'").first();
it('D09 partial Cash payment reconciles owner/customer views and original receipt replay after another entry',async()=>{
 const s=setup();expect((await s.credit()).status).toBe(201);
 const body=s.payment(),first=await s.call(body);expect(first.status).toBe(201);
 const data=(await first.json() as {data:Record<string,unknown>}).data;
 expect(data).toMatchObject({entry:{kind:'payment',amountPaise:20000,effectPaise:-20000,paymentMethod:'cash',note:null,dueDate:null},balance:{balancePaise:30000,ledgerVersion:2},replayed:false});
 for(const [path,user] of [['/v1/shops/shop/customers/link/balance','owner'],['/v1/me/ledgers/shop/balance','customer']])expect(await (await s.get(path,user)).json()).toMatchObject({data:{balancePaise:30000,ledgerVersion:2}});
 expect(await env.DB.prepare('SELECT SUM(effect_paise) AS balance FROM ledger_entries').first('balance')).toBe(30000);
 expect((await s.credit()).status).toBe(201);
 const replay=await s.call(body);expect(replay.status).toBe(200);expect(await replay.json()).toMatchObject({data:{...data,replayed:true}});
 expect(await state()).toEqual({balance_paise:80000,version:3});
 expect((await s.call({...body,paymentMethod:'upi'})).status).toBe(409);
 expect(JSON.stringify(s.events)).not.toContain('amountPaise');
});
it('D09 full UPI payment leaves zero; overpayment returns current authorized balance with no effect',async()=>{
 const s=setup();await s.credit();
 const over=await s.call(s.payment({amountPaise:50001}));expect(over.status).toBe(409);
 expect(await over.json()).toMatchObject({error:{code:'BALANCE_CONFLICT',details:{balance:{balancePaise:50000,ledgerVersion:1}}}});
 expect(await state()).toEqual({balance_paise:50000,version:1});
 expect((await s.call(s.payment({amountPaise:50000,paymentMethod:'upi'}))).status).toBe(201);
 expect(await state()).toEqual({balance_paise:0,version:2});
 expect((await s.call(s.payment({amountPaise:1}))).status).toBe(409);
 expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM sync_operations').first('count')).toBe(2);
});
it('D09 concurrent payments cannot overdraw and concurrent duplicate payments have one effect',async()=>{
 const s=setup();await s.credit();
 const duplicate=s.payment();expect((await Promise.all([s.call(duplicate),s.call(duplicate)])).map(r=>r.status).sort()).toEqual([200,201]);
 expect(await state()).toEqual({balance_paise:30000,version:2});
 const responses=await Promise.all([s.call(s.payment()),s.call(s.payment())]);expect(responses.map(r=>r.status).sort()).toEqual([201,409]);
 expect(await state()).toEqual({balance_paise:10000,version:3});
 expect(await env.DB.prepare('SELECT SUM(effect_paise) AS balance FROM ledger_entries').first('balance')).toBe(10000);
});
it('D09 invalid/forged fields and cross-shop/customer/removed access payment attempts change no balance',async()=>{
 const s=setup();await s.credit();
 for(const overrides of [{amountPaise:0},{amountPaise:-1},{amountPaise:0.1},{amountPaise:10000001},{paymentMethod:'bank'},{paymentMethod:null},{dueDate:'2026-12-01'},{effectPaise:-1},{occurredAtMs:Date.now()+600000},{clientOperationId:'bad'}])expect((await s.call(s.payment(overrides))).status).toBe(400);
 for(const [owner,shop,status] of [['other','shop',404],['owner','other',404],['customer','shop',403],['','shop',401]] as const)expect((await s.call(s.payment(),owner,shop)).status).toBe(status);
 expect((await s.call(s.payment({linkId:'missing'}))).status).toBe(404);
 const body=s.payment();expect((await s.call(body)).status).toBe(201);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");
 expect((await s.call(body)).status).toBe(404);
 expect(await state()).toEqual({balance_paise:30000,version:2});
});
it('D09 failed payment receipt rolls back entry, effective projection and balance',async()=>{
 const s=setup();await s.credit();
 await env.DB.exec("CREATE TRIGGER test_receipt_failure BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'SYNTHETIC_FAILURE'); END");
 expect((await s.call(s.payment())).status).toBe(500);
 expect(await state()).toEqual({balance_paise:50000,version:1});
 for(const table of ['ledger_entries','entry_effective','sync_operations'])expect(await env.DB.prepare(`SELECT COUNT(*) AS count FROM ${table}`).first('count')).toBe(1);
});
