import { beforeEach, describe, expect, it } from 'vitest';
import { applyD1Migrations } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { SessionService } from '../src/auth/sessions';
import { generateKeyPair, SignJWT, exportJWK, createLocalJWKSet } from 'jose';
import { createApp } from '../src/http/router';
import { verifyGoogleToken } from '../src/auth/google';

beforeEach(async () => {
  await env.DB.batch([env.DB.prepare('PRAGMA defer_foreign_keys=ON'), ...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(t=>env.DB.prepare(`DROP TABLE IF EXISTS ${t}`))]);
  await applyD1Migrations(env.DB, env.MIGRATIONS);
});

describe('D04 identity and session boundary', () => {
  it('verifies a signed identity and rejects wrong audience, issuer, expiry and signature', async () => {
    const keys=await generateKeyPair('RS256',{extractable:true});
    const jwk=await exportJWK(keys.publicKey); jwk.kid='test';
    const trusted=createLocalJWKSet({keys:[jwk]});
    const token=await new SignJWT({name:'Synthetic'}).setProtectedHeader({alg:'RS256',kid:'test'}).setSubject('stable-sub').setIssuer('https://accounts.google.com').setAudience('test-client').setIssuedAt().setExpirationTime('1h').sign(keys.privateKey);
    expect((await verifyGoogleToken(token,'test-client',trusted)).sub).toBe('stable-sub');
    await expect(verifyGoogleToken(token,'wrong',trusted)).rejects.toMatchObject({code:'IDENTITY_INVALID'});
    for (const claims of [{iss:'evil'}, {exp:1}]) {
      const bad=await new SignJWT({iat:Math.floor(Date.now()/1000),sub:'stable-sub',iss:'https://accounts.google.com',aud:'test-client',exp:Math.floor(Date.now()/1000)+3600,...claims}).setProtectedHeader({alg:'RS256',kid:'test'}).sign(keys.privateKey);
      await expect(verifyGoogleToken(bad,'test-client',trusted)).rejects.toMatchObject({code:'IDENTITY_INVALID'});
    }
    const other=await generateKeyPair('RS256');
    const forged=await new SignJWT({iat:Math.floor(Date.now()/1000),sub:'stable-sub',iss:'https://accounts.google.com',aud:'test-client',exp:Math.floor(Date.now()/1000)+3600}).setProtectedHeader({alg:'RS256',kid:'test'}).sign(other.privateKey);
    await expect(verifyGoogleToken(forged,'test-client',trusted)).rejects.toMatchObject({code:'IDENTITY_INVALID'});
  });
  it('maps sub, fixes role and stores only hashes', async () => {
    const service=new SessionService(env.DB);
    const first=await service.exchange({sub:'one',name:'A'},'owner','device');
    const again=await service.exchange({sub:'one',name:'B'},'owner','device');
    expect(again.account.id).toBe(first.account.id);
    await expect(service.exchange({sub:'one',name:'B'},'customer','device')).rejects.toMatchObject({code:'ROLE_CONFLICT'});
    const rows=await env.DB.prepare('SELECT token_hash FROM refresh_sessions').all();
    expect(JSON.stringify(rows)).not.toContain(first.refreshToken);
    expect(await service.authenticate(first.accessToken)).toMatchObject({userId:first.account.id,role:'owner'});
  });
  it('rotates once, revokes the entire session on replay, and binds device', async () => {
    const service=new SessionService(env.DB);
    const first=await service.exchange({sub:'one'},'customer','device');
    await expect(service.refresh(first.refreshToken,'other')).rejects.toMatchObject({code:'AUTH_REQUIRED'});
    const next=await service.refresh(first.refreshToken,'device');
    expect(next.refreshToken).not.toBe(first.refreshToken);
    expect(await service.authenticate(next.accessToken)).toBeTruthy();
    await expect(service.refresh(first.refreshToken,'device')).rejects.toMatchObject({code:'AUTH_REQUIRED'});
    expect(await service.authenticate(next.accessToken)).toBeNull();
  });
  it('enforces expiry and logout without revoking another session', async () => {
    let now=1000;
    const service=new SessionService(env.DB,()=>now);
    const first=await service.exchange({sub:'one'},'owner','device');
    const other=await service.exchange({sub:'one'},'owner','other');
    await service.logout(first.accessToken,'device');
    expect(await service.authenticate(first.accessToken)).toBeNull();
    expect(await service.authenticate(other.accessToken)).toBeTruthy();
    now+=15*60*1000;
    expect(await service.authenticate(other.accessToken)).toBeNull();
    now+=30*24*60*60*1000;
    await expect(service.refresh(other.refreshToken,'other')).rejects.toMatchObject({code:'AUTH_REQUIRED'});
  });
  it('allows at most one concurrent refresh and fails closed on uncertain replay', async () => {
    const service=new SessionService(env.DB);
    const first=await service.exchange({sub:'race'},'owner','device');
    const results=await Promise.allSettled([service.refresh(first.refreshToken,'device'),service.refresh(first.refreshToken,'device')]);
    expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
    for(const result of results) if(result.status==='fulfilled') expect(await service.authenticate(result.value.accessToken)).toBeNull();
  });
});

it('D04 HTTP routes exchange, refresh, profile and revoke with safe envelopes', async()=>{
 const sessions=new SessionService(env.DB);
 const app=createApp({sessions,verifyGoogle:async()=>({sub:'http_user',name:'Synthetic'}),logger:()=>{}});
 const post=(path:string,body:unknown,token?:string)=>app.fetch(new Request('https://api.test'+path,{method:'POST',headers:{'Content-Type':'application/json','CF-Connecting-IP':'192.0.2.1',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)}));
 expect((await post('/v1/auth/google',{idToken:'test',requestedRole:'owner'})).status).toBe(400);
 const issued=await post('/v1/auth/google',{idToken:'test',requestedRole:'owner',deviceId:'device'});
 expect(issued.status).toBe(200);
 const data=(await issued.json() as {data:{accessToken:string;refreshToken:string}}).data;
 const profile=await app.fetch(new Request('https://api.test/v1/me',{headers:{Authorization:'Bearer '+data.accessToken}}));
 expect(await profile.json()).toMatchObject({data:{account:{role:'owner'},capabilities:{apiVersion:1}}});
 const rotated=await post('/v1/auth/refresh',{refreshToken:data.refreshToken,deviceId:'device'});
 expect(rotated.status).toBe(200);
 const next=(await rotated.json() as {data:{accessToken:string}}).data;
 expect((await post('/v1/auth/logout',{deviceId:'device'},next.accessToken)).status).toBe(204);
 expect((await app.fetch(new Request('https://api.test/v1/me',{headers:{Authorization:'Bearer '+next.accessToken}}))).status).toBe(401);
});
it('auth rate limits are atomic, expire, and return retry guidance',async()=>{
 let now=1000;const service=new SessionService(env.DB,()=>now);
 for(let i=0;i<10;i++)await service.rateLimit('192.0.2.2','google');
 await expect(service.rateLimit('192.0.2.2','google')).rejects.toMatchObject({status:429,headers:{'Retry-After':'600'}});
 await service.rateLimit('192.0.2.3','google');
 now+=600000;await service.rateLimit('192.0.2.2','google');
});
it('rejects malformed access hashes and unsafe timestamps in the new migration',async()=>{
 const service=new SessionService(env.DB);
 await service.exchange({sub:'guard'},'owner','device');
 const session=await env.DB.prepare('SELECT id FROM refresh_sessions').first<{id:string}>();
 await expect(env.DB.prepare('INSERT INTO access_sessions VALUES (?,?,?,?)').bind('z'.repeat(64),session!.id,1,2).run()).rejects.toThrow('ACCESS_SESSION_INVALID');
 await expect(env.DB.prepare('INSERT INTO access_sessions VALUES (?,?,?,?)').bind('f'.repeat(64),session!.id,1,9007199254740992).run()).rejects.toThrow('ACCESS_SESSION_INVALID');
 expect(await service.authenticate('malformed')).toBeNull();
});
