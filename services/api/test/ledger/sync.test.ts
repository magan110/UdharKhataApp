import {beforeEach,expect,it,vi} from 'vitest';
import {applyD1Migrations} from 'cloudflare:test';
import {env} from 'cloudflare:workers';
import {createApp} from '../../src/http/router';
beforeEach(async()=>{
 await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'),...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
 await applyD1Migrations(env.DB,env.MIGRATIONS);
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','o','owner','Owner',1),('customer','c','customer','Customer',1),('other','x','owner','Other',1),('stranger','s','customer','Stranger',1); INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Store','active',1),('other','other','Other store','active',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1),('shared','other','customer','active',1),('stranger','shop','stranger','active',1)");
});
function setup(){
 const events:unknown[]=[];
 const app=createApp({db:env.DB,authenticate:async r=>{const id=r.headers.get('Authorization');return id?{userId:id,role:id==='customer'?'customer' as const:'owner' as const}:null;},logger:e=>events.push(e)});
 const get=(query='',user='owner',link='link')=>app.fetch(new Request('https://test/v1/shops/shop/customers/'+link+'/sync'+query,{headers:{Authorization:user}}));
 const body=(overrides={})=>({clientOperationId:crypto.randomUUID(),linkId:'link',kind:'credit',amountPaise:50000,note:'Synthetic',dueDate:null,occurredAtMs:Date.now(),...overrides});
 const post=(command:unknown)=>app.fetch(new Request('https://test/v1/shops/shop/entries',{method:'POST',headers:{Authorization:'owner','Content-Type':'application/json'},body:JSON.stringify(command)}));
 return {app,get,body,post,events};
}
interface Page {items:{id:string;serverSeq:number;clientOperationId:string;effectPaise:number}[];nextCursor:string|null;hasMore:boolean;highWaterSeq:number;appliedThroughSeq:number;snapshotAtMs:number;balance:{balancePaise:number;ledgerVersion:number}}
async function page(response:Response){expect(response.status).toBe(200);return (await response.json() as {data:Page}).data;}
it('scopedIncrementalSnapshot',async()=>{
 const s=setup(),a=s.body(),b=s.body();await s.post(a);await s.post(b);
 const first=await page(await s.get('?afterSeq=0&limit=1'));
 expect(first.items[0].clientOperationId).toBe(a.clientOperationId);expect(first.hasMore).toBe(true);expect(first.balance).toMatchObject({balancePaise:100000,ledgerVersion:2});
 await s.post(s.body());
 const next=await page(await s.get('?cursor='+first.nextCursor+'&limit=1'));
 expect(next.items[0].clientOperationId).toBe(b.clientOperationId);expect(next.hasMore).toBe(false);expect(next.highWaterSeq).toBe(first.highWaterSeq);expect(next.snapshotAtMs).toBe(first.snapshotAtMs);expect(next.balance).toEqual(first.balance);
 const latest=await page(await s.get('?afterSeq='+next.appliedThroughSeq));expect(latest.items).toHaveLength(1);expect(latest.balance.ledgerVersion).toBe(3);
 expect(JSON.stringify(s.events)).not.toContain('Synthetic');
});
it('sparseSequencesAndEmptyPage',async()=>{
 const s=setup();await s.post(s.body());await s.post(s.body({linkId:'stranger'}));await s.post(s.body());
 const result=await page(await s.get('?afterSeq=1'));expect(result.items.map(e=>e.serverSeq)).toEqual([3]);expect(result.appliedThroughSeq).toBe(3);
 const empty=await page(await s.get('?afterSeq=3'));expect(empty.items).toEqual([]);expect(empty.appliedThroughSeq).toBe(3);expect(empty.nextCursor).toBeNull();
 expect((await s.get('?afterSeq=4')).status).toBe(409);
});
it('foreignExpiredAndAmbiguousCursor',async()=>{
 const s=setup();await s.post(s.body());await s.post(s.body());const first=await page(await s.get('?limit=1'));
 for(const query of ['?limit=101','?afterSeq=-1','?afterSeq=01','?afterSeq=1.1','?afterSeq=0&afterSeq=1','?unknown=1','?cursor='+first.nextCursor+'&afterSeq=0'])expect((await s.get(query)).status).toBe(400);
 expect((await s.get('?cursor='+first.nextCursor,'owner','stranger')).status).toBe(409);
 expect((await s.get('?cursor='+first.nextCursor,'other')).status).toBe(404);
 const publicHistory=await s.app.fetch(new Request('https://test/v1/shops/shop/customers/link/entries?cursor='+first.nextCursor,{headers:{Authorization:'owner'}}));expect(publicHistory.status).toBe(409);
 const clock=vi.spyOn(Date,'now').mockReturnValue(Date.now()+3600001);try{expect((await s.get('?cursor='+first.nextCursor)).status).toBe(409);}finally{clock.mockRestore();}
});
it('accessRemovedBetweenPages',async()=>{
 const s=setup();await s.post(s.body());await s.post(s.body());const first=await page(await s.get('?limit=1'));
 expect((await s.get('','customer')).status).toBe(403);expect((await s.get('','')).status).toBe(401);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");expect((await s.get('?cursor='+first.nextCursor)).status).toBe(404);
});
it('agedCreditAndPaymentKeepBody',async()=>{
 const s=setup(),occurredAtMs=Date.now()-7*86400000;
 expect((await s.post(s.body({occurredAtMs}))).status).toBe(201);
 const payment={clientOperationId:crypto.randomUUID(),linkId:'link',kind:'payment',amountPaise:10000,paymentMethod:'cash',occurredAtMs};expect((await s.post(payment)).status).toBe(201);
 const result=await page(await s.get());expect(result.balance.balancePaise).toBe(40000);
 expect(await env.DB.prepare('SELECT MIN(occurred_at_ms) AS at FROM ledger_entries').first('at')).toBe(occurredAtMs);
 const now=Date.now(),clock=vi.spyOn(Date,'now').mockReturnValue(now);try{expect((await s.post(s.body({occurredAtMs:now+300001}))).status).toBe(400);}finally{clock.mockRestore();}
});
it('oldReceiptHashStillReplays',async()=>{
 const s=setup(),body=s.body();const committed=await s.post(body);expect(committed.status).toBe(201);const original=await committed.json();
 const clock=vi.spyOn(Date,'now').mockReturnValue(Date.now()+10*86400000);
 try{const replay=await s.post(body);expect(replay.status).toBe(200);expect(await replay.json()).toMatchObject({data:{...(original as {data:object}).data,replayed:true}});}finally{clock.mockRestore();}
 expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM ledger_entries').first('n')).toBe(1);
});
it('discardedCommittedResponseReplaysAndPullsOneEffect',async()=>{
 const s=setup(),body=s.body();await s.post(body);expect((await s.post(body)).status).toBe(200);const result=await page(await s.get());expect(result.items).toHaveLength(1);expect(result.items[0].clientOperationId).toBe(body.clientOperationId);expect(result.balance.balancePaise).toBe(50000);
 expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM sync_operations').first('n')).toBe(1);
 expect(await env.DB.prepare('SELECT SUM(effect_paise) AS n FROM ledger_entries').first('n')).toBe(50000);
});
