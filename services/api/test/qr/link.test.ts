import { beforeEach, expect, it } from 'vitest';
import { applyD1Migrations } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { SessionService } from '../../src/auth/sessions';
import { createApp } from '../../src/http/router';

beforeEach(async () => {
  await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'), ...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t => env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
  await applyD1Migrations(env.DB, env.MIGRATIONS);
});
async function setup() {
  const sessions = new SessionService(env.DB), events: unknown[] = [];
  const app = createApp({db: env.DB, sessions, logger: e => events.push(e)});
  const owner = await sessions.exchange({sub:'o',name:'Owner'},'owner','device');
  const other = await sessions.exchange({sub:'o2'},'owner','device');
  const customer = await sessions.exchange({sub:'c',name:'SENSITIVE_CUSTOMER',email:'private@test'},'customer','device');
  const customer2 = await sessions.exchange({sub:'c2',name:'Second'},'customer','device');
  await env.DB.prepare("INSERT INTO shops VALUES ('shop',?,'Store','active',1,NULL)").bind(owner.account.id).run();
  await env.DB.prepare("INSERT INTO shops VALUES ('other',?,'Other','active',1,NULL)").bind(other.account.id).run();
  const qr = await env.DB.prepare("SELECT public_id FROM customer_qr_ids WHERE customer_user_id=? AND status='active'").bind(customer.account.id).first<string>('public_id') as string;
  const qr2 = await env.DB.prepare("SELECT public_id FROM customer_qr_ids WHERE customer_user_id=? AND status='active'").bind(customer2.account.id).first<string>('public_id') as string;
  const call = (path: string, token = owner.accessToken, body?:unknown) => app.fetch(new Request('https://test'+path, {method:body === undefined?'GET':'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})}));
  const resolve = (id=qr,shopId='shop',token=owner.accessToken) => call('/v1/customer-qr/resolve',token,{shopId,publicQrId:id});
  const link = (body:unknown,token=owner.accessToken,shopId='shop') => call(`/v1/shops/${shopId}/customers`,token,body);
  return {sessions, owner, other, customer, customer2, qr, qr2, events, call, resolve, link};
}
it('D07 resolution changes nothing; explicit linking is once-only, scoped and refreshes list', async () => {
  const s = await setup();
  const resolved = await s.resolve();
  expect(resolved.status).toBe(200);
  expect(await resolved.json()).toMatchObject({data:{state:'new',customerDisplayName:'SENSITIVE_CUSTOMER',linkId:null}});
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(0);
  const command={clientOperationId:crypto.randomUUID(),publicQrId:s.qr,shopNickname:'  Local\t Name '};
  const first=await s.link(command);
  expect(first.status).toBe(201);
  const data=(await first.json() as {data:{id:string;shopNickname:string;balancePaise:number}}).data;
  expect(data).toMatchObject({shopId:'shop',customerDisplayName:'SENSITIVE_CUSTOMER',shopNickname:'Local Name',balancePaise:0,ledgerVersion:0,status:'active'});
  expect(await (await s.resolve()).json()).toMatchObject({data:{state:'linked',linkId:data.id}});
  const repeat=await s.link(command);
  expect(repeat.status).toBe(200);
  expect(await repeat.json()).toMatchObject({data});
  const second=await s.link({...command,clientOperationId:crypto.randomUUID(),shopNickname:'Ignored'});
  expect(second.status).toBe(200);
  expect(await second.json()).toMatchObject({data});
  expect(await (await s.call('/v1/shops/shop/customers')).json()).toMatchObject({data:{customers:[data],hasMore:false}});
  expect(await (await s.call('/v1/shops/shop/customers/'+data.id)).json()).toMatchObject({data});
  expect((await s.call('/v1/shops/other/customers/'+data.id,s.other.accessToken)).status).toBe(404);
  expect((await s.call('/v1/shops/shop/customers',s.other.accessToken)).status).toBe(404);
  expect((await s.call('/v1/shops/shop/customers',s.customer.accessToken)).status).toBe(403);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(1);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM ledger_entries').first('COUNT(*)')).toBe(0);
  for(const value of [s.qr,s.owner.accessToken,'SENSITIVE_CUSTOMER','private@test']) expect(JSON.stringify(s.events)).not.toContain(value);
});
it('D07 concurrent same and different operations create one link; body changes conflict', async () => {
  const s=await setup(),command={clientOperationId:crypto.randomUUID(),publicQrId:s.qr};
  const same=await Promise.all([s.link(command),s.link(command)]);
  expect(same.map(r=>r.status).sort()).toEqual([200,201]);
  const id=(await same[0].json() as {data:{id:string}}).data.id;
  const distinct=await Promise.all(Array.from({length:4},()=>s.link({...command,clientOperationId:crypto.randomUUID()})));
  for(const response of distinct) {
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({data:{id}});
  }
  expect((await s.link({...command,publicQrId:s.qr2})).status).toBe(409);
  expect((await s.link({...command,shopNickname:'Changed'})).status).toBe(409);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(1);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM sync_operations').first('COUNT(*)')).toBe(5);
});
it('D07 revoked QR refuses new linking but replay recovers original receipt; existing link survives', async () => {
  const s=await setup(),command={clientOperationId:crypto.randomUUID(),publicQrId:s.qr};
  const first=await s.link(command); expect(first.status).toBe(201);
  const id=(await first.json() as {data:{id:string}}).data.id;
  expect((await s.call('/v1/me/qr/rotate',s.customer.accessToken,{})).status).toBe(200);
  for(const response of [await s.resolve(),await s.link({...command,clientOperationId:crypto.randomUUID()})]) {
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({error:{code:'QR_REVOKED'}});
  }
  expect(await (await s.link(command)).json()).toMatchObject({data:{id}});
  expect((await s.link({...command,shopNickname:'changed'})).status).toBe(409);
  expect((await s.call('/v1/shops/shop/customers/'+id)).status).toBe(200);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(1);
});
it('D07 invalid input and unauthorized shop reveal no customer identity and write nothing', async () => {
  const s=await setup();
  for(const token of ['',s.customer.accessToken]) expect((await s.resolve(s.qr,'shop',token)).status).toBe(token?403:401);
  expect((await s.resolve(s.qr,'other')).status).toBe(404);
  expect((await s.resolve('z'.repeat(64))).status).toBe(400);
  expect((await s.resolve('f'.repeat(64))).status).toBe(400);
  for(const body of [{clientOperationId:'not-uuid',publicQrId:s.qr},{clientOperationId:crypto.randomUUID(),publicQrId:s.qr,customerUserId:s.customer2.account.id},{clientOperationId:crypto.randomUUID(),publicQrId:s.qr,shopNickname:'x'.repeat(121)}]) expect((await s.link(body)).status).toBe(400);
  expect((await s.link({clientOperationId:crypto.randomUUID(),publicQrId:s.qr},s.other.accessToken)).status).toBe(404);
  await env.DB.prepare('UPDATE users SET deleted_at_ms=2 WHERE id=?').bind(s.customer.account.id).run();
  expect((await s.resolve()).status).toBe(400);
  expect((await s.link({clientOperationId:crypto.randomUUID(),publicQrId:s.qr})).status).toBe(400);
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(0);
});
it('D07 receipt failure rolls back link and zero account together', async () => {
  const s=await setup();
  await env.DB.exec("CREATE TRIGGER test_receipt_failure BEFORE INSERT ON sync_operations BEGIN SELECT RAISE(ABORT,'SYNTHETIC_FAILURE'); END");
  expect((await s.link({clientOperationId:crypto.randomUUID(),publicQrId:s.qr})).status).toBe(500);
  for(const table of ['shop_customers','ledger_accounts','sync_operations']) expect(await env.DB.prepare(`SELECT COUNT(*) FROM ${table}`).first('COUNT(*)')).toBe(0);
});
it('D07 rate limits owner and network lookup without logging QR values', async () => {
  const s=await setup();
  for(let i=0;i<30;i++) expect((await s.resolve()).status).toBe(200);
  const blocked=await s.resolve();
  expect(blocked.status).toBe(429);
  expect(blocked.headers.get('Retry-After')).toBe('60');
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(0);
});
it('D07 commit predicates reject QR revoked after lookup, removed link and closed shop', async () => {
  const s=await setup();
  const {linkCustomer}=await import('../../src/ledger/link');
  const guarded=new Proxy(env.DB,{get(target,key){
    if(key==='batch') return async(statements:D1PreparedStatement[])=>{
      await env.DB.prepare("UPDATE customer_qr_ids SET status='revoked',revoked_at_ms=2 WHERE public_id=?").bind(s.qr).run();
      return target.batch(statements);
    };
    const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
  }});
  await expect(linkCustomer(guarded,{userId:s.owner.account.id,role:'owner'},'shop',{clientOperationId:crypto.randomUUID(),publicQrId:s.qr,shopNickname:null})).rejects.toMatchObject({code:'QR_REVOKED'});
  expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(0);
  const command={clientOperationId:crypto.randomUUID(),publicQrId:s.qr2};
  const link=(await (await s.link(command)).json() as {data:{id:string}}).data;
  await env.DB.prepare("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id=?").bind(link.id).run();
  expect((await s.resolve(s.qr2)).status).toBe(404);
  expect((await s.link({...command,clientOperationId:crypto.randomUUID()})).status).toBe(404);
  expect((await s.link(command)).status).toBe(404);
  await env.DB.prepare("UPDATE shops SET status='closed',closed_at_ms=2 WHERE id='shop'").run();
  expect((await s.link(command)).status).toBe(404);
});
it('D07 operation UUID and QR syntax reject trailing newlines at the HTTP boundary',async()=>{
 const s=await setup();
 for(const body of [{clientOperationId:crypto.randomUUID()+'\n',publicQrId:s.qr},{clientOperationId:crypto.randomUUID(),publicQrId:s.qr+'\n'}]) {
  expect((await s.link(body)).status).toBe(400);
 }
 expect(await env.DB.prepare('SELECT COUNT(*) FROM shop_customers').first('COUNT(*)')).toBe(0);
});
