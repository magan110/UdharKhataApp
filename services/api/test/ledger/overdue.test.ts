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
it('D16 complete summary matches both roles after allocation and corrections',async()=>{
 const s=setup();const credit=async(amountPaise:number,dueDate:string|null)=>s.call({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'credit',amountPaise,dueDate,occurredAtMs:Date.now()});
 const early=(await (await credit(300,'2026-01-01')).json() as {data:{entry:{id:string}}}).data.entry;
 await credit(500,'2026-01-02');await credit(100,null);await s.call(s.payment({amountPaise:400}));
 for(const [path,user] of [['/v1/shops/shop/customers/link/due','owner'],['/v1/me/ledgers/shop/due','customer']])expect(await (await s.get(path+'?asOfDate=2026-01-02',user)).json()).toMatchObject({data:{asOfDate:'2026-01-02',balancePaise:500,overduePaise:0,asOfServerSeq:4}});
 await s.call({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'correction',correctsEntryId:early.id,targetAmountPaise:100,expectedRevision:0,correctionReason:'Fix',occurredAtMs:Date.now()});
 expect(await (await s.get('/v1/me/ledgers/shop/due?asOfDate=2026-01-03','customer')).json()).toMatchObject({data:{balancePaise:300,overduePaise:200,asOfServerSeq:5}});
 for(const query of ['', '?asOfDate=2026-02-30','?asOfDate=2026-01-01&limit=1','?asOfDate=2026-01-01&asOfDate=2026-01-02'])expect((await s.get('/v1/me/ledgers/shop/due'+query,'customer')).status).toBe(400);
 expect((await s.get('/v1/shops/shop/customers/link/due?asOfDate=2026-01-03','other')).status).toBe(404);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");expect((await s.get('/v1/me/ledgers/shop/due?asOfDate=2026-01-03','customer')).status).toBe(404);
});
it('D16 due totals read the complete ledger beyond history page limits',async()=>{
 const s=setup();
 for(let n=0;n<105;n++)expect((await s.call({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'credit',amountPaise:1,dueDate:'2026-01-01',occurredAtMs:Date.now()})).status).toBe(201);
 expect(await (await s.get('/v1/me/ledgers/shop/due?asOfDate=2026-01-02','customer')).json()).toMatchObject({data:{balancePaise:105,overduePaise:105,asOfServerSeq:105}});
});
it('D16 summary freshness describes the read snapshot for old and empty ledgers',async()=>{
 const s=setup();const start=Date.now();
 const empty=(await (await s.get('/v1/me/ledgers/shop/due?asOfDate=2026-01-02','customer')).json() as {data:{asOfMs:number;asOfServerSeq:number}}).data;
 expect(empty.asOfMs).toBeGreaterThanOrEqual(start);expect(empty.asOfServerSeq).toBe(0);
 await env.DB.prepare(`INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,effect_paise,due_date,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms) VALUES ('old','link','shop','customer','credit',100,100,'2026-01-01','owner',?,1,1)`).bind(crypto.randomUUID()).run();
 const old=(await (await s.get('/v1/me/ledgers/shop/due?asOfDate=2026-01-02','customer')).json() as {data:{asOfMs:number;overduePaise:number}}).data;
 expect(old.asOfMs).toBeGreaterThanOrEqual(start);expect(old.overduePaise).toBe(100);
});
