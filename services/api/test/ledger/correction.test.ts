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
it('D14 correction races and receipt replay preserve immutable originals',async()=>{
 const s=setup();const original=(await (await s.credit()).json() as {data:{entry:{id:string}}}).data.entry;
 const body={clientOperationId:crypto.randomUUID(),linkId:'link',kind:'correction',correctsEntryId:original.id,targetAmountPaise:45000,expectedRevision:0,correctionReason:'Fix',occurredAtMs:Date.now()};
 const duplicate=await Promise.all([s.call(body),s.call(body)]);expect(duplicate.map(r=>r.status).sort()).toEqual([200,201]);
 expect(await duplicate[0].json()).toMatchObject({data:{entry:{kind:'correction',effectPaise:-5000,revision:1},balance:{balancePaise:45000}}});
 expect(await env.DB.prepare('SELECT amount_paise FROM ledger_entries WHERE id=?').bind(original.id).first('amount_paise')).toBe(50000);
 const race=await Promise.all([s.call({...body,clientOperationId:crypto.randomUUID(),expectedRevision:1,targetAmountPaise:40000}),s.call({...body,clientOperationId:crypto.randomUUID(),expectedRevision:1,targetAmountPaise:35000})]);expect(race.map(r=>r.status).sort()).toEqual([201,409]);expect(await race.find(r=>r.status===409)!.json()).toMatchObject({error:{code:'REVISION_CONFLICT'}});
 expect((await s.call(body)).status).toBe(200);expect((await s.call({...body,correctionReason:'Changed'})).status).toBe(409);
 const payment=(await (await s.call(s.payment())).json() as {data:{entry:{id:string}}}).data.entry;
 expect((await s.call({...body,clientOperationId:crypto.randomUUID(),expectedRevision:2,targetAmountPaise:0})).status).toBe(409);
 expect((await s.call({...body,clientOperationId:crypto.randomUUID(),correctsEntryId:payment.id,targetAmountPaise:0})).status).toBe(201);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");expect((await s.call(body)).status).toBe(404);
});
it('D14 invalid targets and receipt failure preserve all financial state',async()=>{
 const s=setup();const original=(await (await s.credit()).json() as {data:{entry:{id:string}}}).data.entry;
 const body={clientOperationId:crypto.randomUUID(),linkId:'link',kind:'correction',correctsEntryId:original.id,targetAmountPaise:45000,expectedRevision:0,correctionReason:'Fix',occurredAtMs:Date.now()};
 for(const fields of [{targetAmountPaise:-1},{targetAmountPaise:0.1},{targetAmountPaise:10000001},{expectedRevision:-1},{correctionReason:' '},{correctionReason:'x'.repeat(241)},{effectPaise:-5000}])expect((await s.call({...body,...fields})).status).toBe(400);
 expect((await s.call({...body,correctsEntryId:'missing'})).status).toBe(404);
 expect((await s.call(body,'customer')).status).toBe(403);expect((await s.call(body,'other')).status).toBe(404);
 await env.DB.exec("CREATE TRIGGER test_receipt_failure BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'SYNTHETIC_FAILURE'); END");
 expect((await s.call(body)).status).toBe(500);
 expect(await env.DB.prepare("SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id='link'").first()).toEqual({balance_paise:50000,version:1});
 expect(await env.DB.prepare('SELECT effective_paise,revision FROM entry_effective WHERE entry_id=?').bind(original.id).first()).toEqual({effective_paise:50000,revision:0});
 expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM ledger_entries').first('n')).toBe(1);
});
