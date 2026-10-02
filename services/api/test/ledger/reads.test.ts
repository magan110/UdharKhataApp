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
 const events:unknown[]=[];const occurredAtMs=Date.now();
 const app=createApp({db:env.DB,authenticate:async r=>{const id=r.headers.get('Authorization');return id?{userId:id,role:['customer','stranger'].includes(id)?'customer' as const:'owner' as const}:null;},logger:e=>events.push(e)});
 const get=(path:string,user='owner')=>app.fetch(new Request('https://test'+path,{headers:{Authorization:user}}));
 const post=async(kind='credit',amountPaise=50000,shop='shop',linkId='link',owner='owner',operation=crypto.randomUUID())=>app.fetch(new Request(`https://test/v1/shops/${shop}/entries`,{method:'POST',headers:{Authorization:owner,'Content-Type':'application/json'},body:JSON.stringify({clientOperationId:operation,linkId,kind,amountPaise,occurredAtMs,...(kind==='payment'?{paymentMethod:'cash'}:{note:'Rice',dueDate:'2026-10-15'})})}));
 return {get,post,events};
}
interface ReadData {entries:{kind:string;effectPaise:number}[];balance:{balancePaise:number};page:{nextCursor:string;hasMore:boolean};customers:{id:string}[];links:{id:string;shopId:string}[];snapshotAtMs:number;totalBalancePaise:number}
async function data(response:Response){expect(response.status).toBe(200);return (await response.json() as {data:ReadData}).data;}
it('D10 owner/customer history reconciles a fixed snapshot across pages and concurrent new entries',async()=>{
 const s=setup();expect((await s.post()).status).toBe(201);const op=crypto.randomUUID();expect((await s.post('payment',20000,'shop','link','owner',op)).status).toBe(201);
 expect((await s.post('payment',20000,'shop','link','owner',op)).status).toBe(200);
 const owner=await data(await s.get('/v1/shops/shop/customers/link/entries?limit=1'));
 const customer=await data(await s.get('/v1/me/ledgers/shop/entries?limit=1','customer'));
 expect(owner.entries).toEqual(customer.entries);expect(owner.balance).toEqual(customer.balance);
 expect(owner.balance).toMatchObject({balancePaise:30000,ledgerVersion:2});expect(owner.entries[0]).toMatchObject({kind:'credit',amountPaise:50000,note:'Rice',dueDate:'2026-10-15'});
 expect(owner.page.hasMore).toBe(true);
 expect((await s.post()).status).toBe(201);
 const next=await data(await s.get('/v1/shops/shop/customers/link/entries?limit=1&cursor='+owner.page.nextCursor));
 expect(next.entries).toHaveLength(1);expect(next.entries[0].kind).toBe('payment');expect(next.page).toEqual({hasMore:false,nextCursor:null});expect(next.balance).toEqual(owner.balance);expect(next.snapshotAtMs).toBe(owner.snapshotAtMs);
 expect(owner.entries[0].effectPaise+next.entries[0].effectPaise).toBe(30000);
 expect((await data(await s.get('/v1/me/ledgers/shop/entries','customer'))).balance.balancePaise).toBe(80000);
 expect(JSON.stringify(s.events)).not.toMatch(/Rice|amountPaise|cursor=/);
});
it('D10 cursors reject tampering, role/route/account/scope reuse, expiry and key rotation',async()=>{
 const s=setup();await s.post();await s.post();
 const page=await data(await s.get('/v1/shops/shop/customers/link/entries?limit=1'));
 const cursor=page.page.nextCursor as string;
 for(const path of ['/v1/shops/shop/customers/stranger/entries','/v1/shops/other/customers/shared/entries','/v1/me/ledgers/shop/entries']){
  const r=await s.get(path+'?cursor='+cursor,path.includes('/me/')?'customer':path.includes('/other/')?'other':'owner');expect(r.status).toBe(409);expect(await r.json()).toMatchObject({error:{code:'CURSOR_INVALID'}});
 }
 const bad=(cursor[0]==='A'?'B':'A')+cursor.slice(1);expect((await s.get('/v1/shops/shop/customers/link/entries?cursor='+bad)).status).toBe(409);
 expect((await s.get('/v1/shops/shop/customers/link/entries?cursor=bad')).status).toBe(409);
 const now=Date.now();const clock=vi.spyOn(Date,'now').mockReturnValue(now+3600001);
 try{expect((await s.get('/v1/shops/shop/customers/link/entries?cursor='+cursor)).status).toBe(409);}finally{clock.mockRestore();}
 await env.DB.exec('DELETE FROM cursor_keys');expect((await s.get('/v1/shops/shop/customers/link/entries?cursor='+cursor)).status).toBe(409);
});
it('D10 traverses more than 100 customers without omissions or accepting another account list cursor',async()=>{
 const s=setup();
 await env.DB.batch(Array.from({length:105},(_,i)=>env.DB.prepare("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES (?,?,'customer','Synthetic',1)").bind('many'+i,'many'+i)));
 await env.DB.batch(Array.from({length:105},(_,i)=>env.DB.prepare("INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES (?,'shop',?,'active',1)").bind('many'+i,'many'+i)));
 const first=await data(await s.get('/v1/shops/shop/customers'));expect(first.customers).toHaveLength(50);
 const seen=first.customers.map(c=>c.id);let cursor=first.page.nextCursor;
 while(cursor){const page=await data(await s.get('/v1/shops/shop/customers?cursor='+cursor));seen.push(...page.customers.map(c=>c.id));cursor=page.page.nextCursor;}
 expect(seen).toHaveLength(107);expect(new Set(seen).size).toBe(107);
 expect((await s.get('/v1/shops/other/customers?cursor='+first.page.nextCursor,'other')).status).toBe(409);
 const customer=await data(await s.get('/v1/me/ledgers?limit=1','customer'));
 expect((await s.get('/v1/me/ledgers?cursor='+customer.page.nextCursor,'stranger')).status).toBe(409);
 const history=await data(await s.get('/v1/me/ledgers/shop/entries','customer'));expect(history.entries).toEqual([]);
 for(const path of ['/v1/me/ledgers/shop/entries','/v1/shops/shop/customers'])expect((await s.get(path+'?limit=100',path.includes('/me/')?'customer':'owner')).status).toBe(200);
});
it('D10 continuation reauthorizes access; list high-water excludes links inserted between pages',async()=>{
 const s=setup();await s.post();await s.post();
 const page=await data(await s.get('/v1/shops/shop/customers/link/entries?limit=1'));
 const list=await data(await s.get('/v1/shops/shop/customers?limit=1'));
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('new','new','customer','New',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('new','shop','new','active',1)");
 const second=await data(await s.get('/v1/shops/shop/customers?cursor='+list.page.nextCursor));expect(second.customers.map(c=>c.id)).toEqual(['stranger']);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");
 expect((await s.get('/v1/shops/shop/customers/link/entries?cursor='+page.page.nextCursor)).status).toBe(404);
});
it('D10 lists paginate all links and shop totals include every retained ledger without exposing other customers',async()=>{
 const s=setup();await s.post();await s.post('payment',20000);await s.post('credit',70000,'other','shared','other');
 const a=await data(await s.get('/v1/shops/shop/customers?limit=1'));expect(a.customers).toHaveLength(1);expect(a.page.hasMore).toBe(true);
 const b=await data(await s.get('/v1/shops/shop/customers?limit=1&cursor='+a.page.nextCursor));expect(b.customers).toHaveLength(1);expect(b.customers[0].id).not.toBe(a.customers[0].id);expect(b.page.hasMore).toBe(false);
 const shops=await data(await s.get('/v1/me/ledgers?limit=1','customer'));expect(shops.links).toHaveLength(1);expect(shops.page.hasMore).toBe(true);
 const more=await data(await s.get('/v1/me/ledgers?limit=1&cursor='+shops.page.nextCursor,'customer'));expect(more.links).toHaveLength(1);expect(more.links[0].id).not.toBe(shops.links[0].id);expect(more.page.hasMore).toBe(false);
 expect(JSON.stringify([shops,more])).not.toMatch(/stranger|google_sub|createdByUserId|customerUserId/);
 const summary=await data(await s.get('/v1/shops/shop'));expect(summary).toMatchObject({totalBalancePaise:30000,customerCount:2});
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");
 expect((await data(await s.get('/v1/shops/shop'))).totalBalancePaise).toBe(30000);
 expect((await data(await s.get('/v1/me/ledgers','customer'))).links.map(x=>x.shopId)).toEqual(['other']);
});
it('D10 rejects private reads and malformed page queries; empty authorized ledger is a real empty snapshot',async()=>{
 const s=setup();await s.post();
 for(const [path,user,status] of [['/v1/shops/shop/customers/link/entries','other',404],['/v1/shops/shop/customers/link/entries','customer',403],['/v1/me/ledgers/shop/entries','stranger',200],['/v1/me/ledgers/other/entries','stranger',404],['/v1/me/ledgers','owner',403],['/v1/me/ledgers','',401]] as const){
  const r=await s.get(path,user);expect(r.status).toBe(status);if(status===200)expect(await data(r)).toMatchObject({entries:[],balance:{balancePaise:0,ledgerVersion:0},page:{hasMore:false,nextCursor:null}});
 }
 for(const query of ['limit=0','limit=101','limit=1.5','limit=01','limit=1&limit=2','customerId=stranger','cursor=','cursor=x&cursor=y'])expect((await s.get('/v1/me/ledgers/shop/entries?'+query,'customer')).status).toBe(400);
 await env.DB.exec("UPDATE users SET deleted_at_ms=2 WHERE id='owner'");expect((await s.get('/v1/me/ledgers/shop/entries','customer')).status).toBe(404);
});
