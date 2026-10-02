import {beforeEach,expect,it} from 'vitest';
import {applyD1Migrations} from 'cloudflare:test';
import {env} from 'cloudflare:workers';
import {SessionService} from '../../src/auth/sessions';
import {createApp} from '../../src/http/router';
beforeEach(async()=>{
 await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'),...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
 await applyD1Migrations(env.DB,env.MIGRATIONS);
 await env.DB.exec("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','o','owner','Owner',1),('customer','c','customer','Customer',1),('other','x','owner','Other',1),('stranger','s','customer','Stranger',1); INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Store','active',1),('other','other','Other store','active',1); INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1),('shared','other','customer','active',1),('stranger','shop','stranger','active',1)");
});
async function setup(){
 const events:unknown[]=[];const occurredAtMs=Date.now();
 const sessions=new SessionService(env.DB);
 const credentials=new Map<string,string>();
 for(const [id,sub,role] of [['owner','o','owner'],['other','x','owner'],['customer','c','customer']] as const){const session=await sessions.exchange({sub,name:id},role,'synthetic-device');credentials.set(id,'Bearer '+session.accessToken);}
 const app=createApp({db:env.DB,sessions,logger:e=>events.push(e)});
 const get=(path:string,user='owner')=>app.fetch(new Request('https://test'+path,{headers:{Authorization:credentials.get(user)??''}}));
 const post=async(kind='credit',amountPaise=50000,shop='shop',linkId='link',owner='owner',operation=crypto.randomUUID())=>app.fetch(new Request(`https://test/v1/shops/${shop}/entries`,{method:'POST',headers:{Authorization:credentials.get(owner)??'','Content-Type':'application/json'},body:JSON.stringify({clientOperationId:operation,linkId,kind,amountPaise,occurredAtMs,...(kind==='payment'?{paymentMethod:'cash'}:{note:'Rice',dueDate:'2026-10-15'})})}));
 return {get,post,events};
}
interface ReadData {entries:{kind:string;effectPaise:number}[];balance:{balancePaise:number};page:{nextCursor:string;hasMore:boolean};customers:{id:string}[];links:{id:string;shopId:string}[];snapshotAtMs:number;totalBalancePaise:number}
async function data(response:Response){expect(response.status).toBe(200);return (await response.json() as {data:ReadData}).data;}
it('D20 limits statement starts while allowing scoped snapshot continuations',async()=>{
 const s=await setup();await s.post();await s.post();
 const path='/v1/shops/shop/customers/link/statement';const first=await data(await s.get(path+'?limit=1'));
 for(let n=1;n<6;n++)expect((await s.get(path)).status).toBe(200);
 const limited=await s.get(path);expect(limited.status).toBe(429);expect(limited.headers.get('Retry-After')).toBe('60');
 await s.post();const next=await data(await s.get(path+'?limit=1&cursor='+first.page.nextCursor));expect(next.entries).toHaveLength(1);expect(next.page.hasMore).toBe(false);expect(next.balance).toEqual(first.balance);
 for(let n=0;n<50;n++)expect((await s.get(path+'?limit=1&cursor='+first.page.nextCursor)).status).toBe(200);
 expect((await s.get('/v1/shops/other/customers/shared/statement?cursor='+first.page.nextCursor,'other')).status).toBe(409);
 expect((await s.get(path+'?cursor='+first.page.nextCursor,'customer')).status).toBe(403);
 await env.DB.exec("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");expect((await s.get(path+'?cursor='+first.page.nextCursor)).status).toBe(404);
});
it('D20 unauthorized and invalid statement requests do not consume export quota',async()=>{
 const s=await setup();const path='/v1/shops/shop/customers/link/statement';
 for(let n=0;n<7;n++){expect((await s.get(path,'other')).status).toBe(404);expect((await s.get(path+'?from=2026-01-01')).status).toBe(400);}
 for(let n=0;n<6;n++)expect((await s.get(path)).status).toBe(200);
 expect((await s.get(path)).status).toBe(429);
});
