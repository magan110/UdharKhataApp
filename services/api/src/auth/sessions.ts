import {ratePolicy} from '../telemetry/rate_limits';
import type { GoogleIdentity } from './google';
import type { Principal } from './authenticator';
import type { Account } from '../http/schemas';
import { HttpError } from '../http/errors';
import { ownQr } from '../qr/service';

const ACCESS_MS=15*60*1000;
const REFRESH_MS=30*24*60*60*1000;
const authRequired=()=>new HttpError(401,'AUTH_REQUIRED','auth.required');
export async function hashToken(value:string):Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),b=>b.toString(16).padStart(2,'0')).join('');
}
function credential():string { return Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join(''); }
interface UserRow { id:string; account_role:'owner'|'customer'; display_name:string; email:string|null; created_at_ms:number; deleted_at_ms:number|null }
interface SessionRow { id:string; user_id:string; device_id:string; expires_at_ms:number; revoked_at_ms:number|null }
function account(row:UserRow):Account { return {id:row.id,role:row.account_role,displayName:row.display_name,createdAtMs:row.created_at_ms,...(row.email?{email:row.email}:{})}; }

export class SessionService {
  constructor(private readonly db:D1Database,private readonly clock:()=>number=Date.now) {}
  async exchange(identity:GoogleIdentity,role:'owner'|'customer',deviceId:string) {
    const now=this.clock();
    await this.db.prepare('INSERT INTO users(id,google_sub,account_role,display_name,email,created_at_ms) VALUES (?,?,?,?,?,?) ON CONFLICT(google_sub) DO NOTHING')
      .bind(crypto.randomUUID(),identity.sub,role,identity.name||'Google account',identity.email??null,now).run();
    const row=await this.db.prepare('SELECT * FROM users WHERE google_sub=?').bind(identity.sub).first<UserRow>();
    if(!row || row.deleted_at_ms!==null) throw authRequired();
    if(row.account_role!==role) throw new HttpError(409,'ROLE_CONFLICT','auth.roleConflict');
    if(row.account_role==='customer') await ownQr(this.db,row.id,now);
    const refreshToken=credential(),accessToken=credential(),id=crypto.randomUUID();
    await this.db.batch([
      this.db.prepare('INSERT INTO refresh_sessions(id,user_id,device_id,token_hash,created_at_ms,expires_at_ms) VALUES (?,?,?,?,?,?)').bind(id,row.id,deviceId,await hashToken(refreshToken),now,now+REFRESH_MS),
      this.db.prepare('INSERT INTO access_sessions(token_hash,refresh_session_id,created_at_ms,expires_at_ms) VALUES (?,?,?,?)').bind(await hashToken(accessToken),id,now,now+ACCESS_MS),
    ]);
    return {account:account(row),accessToken,refreshToken,accessExpiresAtMs:now+ACCESS_MS};
  }
  async authenticate(token:string):Promise<Principal|null> {
    if(!/^[0-9a-f]{64}$/.test(token)) return null;
    const now=this.clock();
    const row=await this.db.prepare('SELECT u.id,u.account_role FROM access_sessions a JOIN refresh_sessions s ON s.id=a.refresh_session_id JOIN users u ON u.id=s.user_id WHERE a.token_hash=? AND a.expires_at_ms>? AND s.expires_at_ms>? AND s.revoked_at_ms IS NULL AND u.deleted_at_ms IS NULL').bind(await hashToken(token),now,now).first<{id:string;account_role:'owner'|'customer'}>();
    return row?{userId:row.id,role:row.account_role}:null;
  }
  async profile(token:string) {
    const principal=await this.authenticate(token); if(!principal) throw authRequired();
    const row=await this.db.prepare('SELECT * FROM users WHERE id=? AND deleted_at_ms IS NULL').bind(principal.userId).first<UserRow>();
    if(!row) throw authRequired();
    return {account:account(row),capabilities:{apiVersion:1,localSchemaVersion:1}};
  }
  async refresh(token:string,deviceId:string) {
    if(!/^[0-9a-f]{64}$/.test(token)) throw authRequired();
    const old=await hashToken(token),now=this.clock();
    const session=await this.db.prepare('SELECT * FROM refresh_sessions WHERE token_hash=?').bind(old).first<SessionRow>();
    if(!session) {
      await this.db.prepare('UPDATE refresh_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE id IN (SELECT session_id FROM spent_refresh_tokens WHERE token_hash=?)').bind(now,old).run();
      throw authRequired();
    }
    if(session.device_id!==deviceId || session.revoked_at_ms!==null || session.expires_at_ms<=now) throw authRequired();
    const refreshToken=credential(),accessToken=credential(),next=await hashToken(refreshToken);
    const results=await this.db.batch([
      this.db.prepare('UPDATE refresh_sessions SET token_hash=? WHERE id=? AND token_hash=? AND revoked_at_ms IS NULL AND expires_at_ms>? AND EXISTS(SELECT 1 FROM users WHERE id=refresh_sessions.user_id AND deleted_at_ms IS NULL) RETURNING id').bind(next,session.id,old,now),
      this.db.prepare('INSERT INTO spent_refresh_tokens(token_hash,session_id) SELECT ?,id FROM refresh_sessions WHERE id=? AND token_hash=?').bind(old,session.id,next),
      this.db.prepare('INSERT INTO access_sessions(token_hash,refresh_session_id,created_at_ms,expires_at_ms) SELECT ?,id,?,? FROM refresh_sessions WHERE id=? AND token_hash=?').bind(await hashToken(accessToken),now,Math.min(now+ACCESS_MS,session.expires_at_ms),session.id,next),
    ]);
    if(results[0].results.length!==1) {
      await this.db.prepare('UPDATE refresh_sessions SET revoked_at_ms=COALESCE(revoked_at_ms,?) WHERE id=?').bind(now,session.id).run();
      throw authRequired();
    }
    return {refreshToken,accessToken,accessExpiresAtMs:Math.min(now+ACCESS_MS,session.expires_at_ms)};
  }
  async logout(token:string,deviceId:string) {
    if(!await this.authenticate(token)) throw authRequired();
    const result=await this.db.prepare('UPDATE refresh_sessions SET revoked_at_ms=? WHERE device_id=? AND id IN(SELECT refresh_session_id FROM access_sessions WHERE token_hash=?) RETURNING id').bind(this.clock(),deviceId,await hashToken(token)).all();
    if(result.results.length!==1) throw authRequired();
  }
  async rateLimit(network:string,route:string) {
    const now=this.clock(),{periodMs:period,limit}=ratePolicy(route);
    const key=await hashToken(`${route}:${network}`);
    // Keep one rolling-window row per network/route; expire inactive rows on auth traffic.
    await this.db.prepare('DELETE FROM auth_rate_limits WHERE window_start_ms<?').bind(now-600000).run();
    const row=await this.db.prepare('INSERT INTO auth_rate_limits(key_hash,window_start_ms,attempts) VALUES (?,?,1) ON CONFLICT(key_hash) DO UPDATE SET attempts=CASE WHEN window_start_ms<=? THEN 1 ELSE attempts+1 END,window_start_ms=CASE WHEN window_start_ms<=? THEN excluded.window_start_ms ELSE window_start_ms END RETURNING attempts').bind(key,now,now-period,now-period).first<{attempts:number}>();
    if(!row || row.attempts>limit) throw new HttpError(429,'RATE_LIMITED','api.rateLimited',true,{'Retry-After':String(period/1000)});
  }
}
