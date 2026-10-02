import {beforeEach,expect,it} from 'vitest';
import {applyD1Migrations} from 'cloudflare:test';
import {env} from 'cloudflare:workers';
import {createApp} from '../../src/http/router';
beforeEach(async()=>{
 await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'),...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
 await applyD1Migrations(env.DB,env.MIGRATIONS);
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','o','owner','Owner',1),('customer','c','customer','Customer',1),('other','x','owner','Other',1),('stranger','s','customer','Stranger',1); INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Store','active',1),('other','other','Other store','active',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1),('shared','other','customer','active',1),('stranger','shop','stranger','active',1)");
});

function app(){return createApp({db:env.DB,authenticate:async r=>{const id=r.headers.get('Authorization');return id?{userId:id,role:['customer','stranger'].includes(id)?'customer' as const:'owner' as const}:null;}});}
async function call(path:string,user='customer',body?:unknown){return app().fetch(new Request('https://test'+path,{method:body===undefined?'GET':'POST',headers:{Authorization:user,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})}));}
async function seed(){await env.DB.prepare("INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,effect_paise,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms) VALUES ('entry','link','shop','customer','credit',500,500,'owner',?,1,1)").bind(crypto.randomUUID()).run();}
it('isolates disputes, deduplicates open reports and preserves balance on resolution',async()=>{
 await seed();const path='/v1/me/ledgers/shop/entries/entry/disputes';
 for(const [user,status] of [['',401],['owner',403],['stranger',404]] as const)expect((await call(path,user,{reason:'Wrong'})).status).toBe(status);
 const first=await call(path,'customer',{reason:'Wrong'});expect(first.status).toBe(201);const d=(await first.json() as {data:{id:string}}).data;
 expect((await call(path,'customer',{reason:'Retry'})).status).toBe(200);
 expect((await call('/v1/shops/shop/disputes','other')).status).toBe(404);
 const resolve='/v1/shops/shop/disputes/'+d.id+'/resolve';expect((await call(resolve,'other',{resolutionNote:'Checked'})).status).toBe(404);
 expect((await call(resolve,'owner',{resolutionNote:'Checked'})).status).toBe(200);
 expect((await call(resolve,'owner',{resolutionNote:'Different'})).status).toBe(409);
 expect(await env.DB.prepare("SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id='link'").first()).toEqual({balance_paise:500,version:1});
 expect((await call(path,'customer',{reason:' '})).status).toBe(400);
 expect((await call(path,'customer',{reason:'x'.repeat(501)})).status).toBe(400);
 expect((await (await call('/v1/me/disputes','stranger')).json() as {data:{items:unknown[]}}).data.items).toEqual([]);
});
it('tracks private requests and removes access while retaining money and history',async()=>{
 await seed();for(const [user,body,status] of [['',{kind:'account_deletion'},401],['customer',{kind:'shop_deletion',shopId:'shop'},403],['owner',{kind:'access_removal',shopId:'shop'},403],['other',{kind:'shop_deletion',shopId:'shop'},404],['customer',{kind:'account_deletion',shopId:'shop'},400]] as const)expect((await call('/v1/me/data-requests',user,body)).status).toBe(status);
 expect((await call('/v1/me/data-requests','customer',{kind:'account_deletion'})).status).toBe(202);
 expect((await call('/v1/me/ledgers/shop/access-removal','customer',{})).status).toBe(200);
 expect((await call('/v1/me/ledgers/shop/access-removal','customer',{})).status).toBe(200);
 expect((await call('/v1/me/ledgers/shop/entries/entry/disputes','customer',{reason:'Wrong'})).status).toBe(404);
 expect(await env.DB.prepare("SELECT balance_paise FROM ledger_accounts WHERE shop_customer_id='link'").first()).toEqual({balance_paise:500});
 expect((await env.DB.prepare('SELECT COUNT(*) n FROM ledger_entries').first<{n:number}>())?.n).toBe(1);
 expect((await (await call('/v1/me/data-requests')).json() as {data:{requests:unknown[]}}).data.requests).toHaveLength(2);
 expect((await (await call('/v1/me/data-requests','owner')).json() as {data:{requests:unknown[]}}).data.requests).toEqual([]);
});
it('paginates selected shop independently of other-shop reports and rejects foreign anchors',async()=>{
 await seed();
 await env.DB.prepare("INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,effect_paise,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms) VALUES ('shared-entry','shared','other','customer','credit',500,500,'other',?,1,1)").bind(crypto.randomUUID()).run();
 await env.DB.batch(Array.from({length:105},(_,i)=>env.DB.prepare("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms,resolved_at_ms,resolved_by_user_id,owner_note) VALUES (?,'entry','link','customer','Checked','resolved',?,?, 'owner','Checked')").bind('report'+String(i).padStart(3,'0'),i+1,i+1)));
 await env.DB.batch(Array.from({length:105},(_,i)=>env.DB.prepare("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms,resolved_at_ms,resolved_by_user_id,owner_note) VALUES (?,'shared-entry','shared','customer','Checked','resolved',?,?, 'other','Checked')").bind('foreign'+String(i).padStart(3,'0'),i+1000,i+1000)));
 type Page={items:{id:string;shopId:string}[];hasMore:boolean;nextCursor:string|null};
 const read=async(path:string,user='customer')=>(await (await call(path,user)).json() as {data:Page}).data;
 for(const [path,user] of [['/v1/me/disputes?shopId=shop','customer'],['/v1/shops/shop/disputes','owner']] as const){const first=await read(path,user);expect(first.items).toHaveLength(100);expect(first.hasMore).toBe(true);expect(first.items.every(x=>x.shopId==='shop')).toBe(true);const second=await read(path+(path.includes('?')?'&':'?')+'before='+first.nextCursor,user);expect(second.items).toHaveLength(5);expect(second.nextCursor).toBeNull();expect(new Set([...first.items,...second.items].map(x=>x.id)).size).toBe(105);}
 for(const path of ['/v1/me/disputes?shopId=shop&before=foreign104','/v1/shops/shop/disputes?before=foreign104'])expect((await call(path,path.includes('/shops/')?'owner':'customer')).status).toBe(409);
 for(const query of ['before=','before=a&before=b','other=x','shopId=shop'])expect((await call('/v1/shops/shop/disputes?'+query,'owner')).status).toBe(400);
 expect((await call('/v1/me/disputes?shopId=shop&before=missing')).status).toBe(409);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=999 WHERE id='link'");expect((await call('/v1/me/disputes?shopId=shop&before=report104')).status).toBe(404);
});
it('accepts full bounded reason and resolution, repeats same resolution and rejects missing entry',async()=>{
 await seed();const result=await call('/v1/me/ledgers/shop/entries/entry/disputes','customer',{reason:'x'.repeat(500)});expect(result.status).toBe(201);const row=(await result.json() as {data:{id:string}}).data;
 const path='/v1/shops/shop/disputes/'+row.id+'/resolve';expect((await call(path,'owner',{resolutionNote:'y'.repeat(500)})).status).toBe(200);expect((await call(path,'owner',{resolutionNote:'y'.repeat(500)})).status).toBe(200);
 expect((await call('/v1/shops/shop/disputes/missing/resolve','owner',{resolutionNote:'Checked'})).status).toBe(404);
 expect((await call('/v1/me/ledgers/shop/entries/missing/disputes','customer',{reason:'Wrong'})).status).toBe(404);
});
it('D21 paginates scoped disputes without silently losing an old shop behind newer disputes',async()=>{
 await seed();
 await env.DB.prepare("INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,effect_paise,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms) VALUES ('otherentry','shared','other','customer','credit',100,100,'other',?,1,1)").bind(crypto.randomUUID()).run();
 const rows: D1PreparedStatement[]=[];
 for(let i=0;i<105;i++)for(const foreign of [false,true])rows.push(env.DB.prepare("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,owner_note,created_at_ms,resolved_at_ms,resolved_by_user_id) VALUES (?,?,?,'customer',?,'resolved','Checked',?,9999,?)").bind(`${foreign?'new':'old'}-${String(i).padStart(3,'0')}`,foreign?'otherentry':'entry',foreign?'shared':'link','x'.repeat(500),foreign?i+200:i+2,foreign?'other':'owner'));
 await env.DB.batch(rows);
 const first=await call('/v1/me/disputes?shopId=shop');expect(first.status).toBe(200);
 const page=(await first.json() as {data:{items:{id:string;shopId:string}[];hasMore:boolean;nextCursor:string}}).data;
 expect(page.items).toHaveLength(100);expect(page.hasMore).toBe(true);expect(page.items.every(x=>x.shopId==='shop')).toBe(true);
 const second=(await (await call('/v1/me/disputes?shopId=shop&before='+page.nextCursor)).json() as {data:{items:{id:string}[];hasMore:boolean;nextCursor:null}}).data;
 expect(second.items).toHaveLength(5);expect(second.hasMore).toBe(false);expect(second.nextCursor).toBeNull();
 expect(new Set([...page.items,...second.items].map(x=>x.id)).size).toBe(105);
 expect((await call('/v1/me/disputes?shopId=shop&before=new-000')).status).toBe(409);
 expect((await call('/v1/me/disputes?shopId=other','stranger')).status).toBe(404);
 for(const path of ['/v1/me/disputes?unknown=x','/v1/me/disputes?shopId=shop&shopId=other','/v1/me/disputes?shopId=shop&before=bad%0A','/v1/shops/shop/disputes?shopId=other'])expect((await call(path,path.includes('/shops/')?'owner':'customer')).status).toBe(400);
 const owned=(await (await call('/v1/shops/shop/disputes','owner')).json() as {data:{items:unknown[];hasMore:boolean}}).data;expect(owned.items).toHaveLength(100);expect(owned.hasMore).toBe(true);
});
