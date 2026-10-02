import {z} from 'zod';
import {HttpError} from './errors';
import {cursorSchema} from './schemas';
const integer=z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
const payloadSchema=z.object({v:z.literal(1),scope:z.string().max(600),after:z.union([integer,z.string().max(128)]),high:integer,snapshotAtMs:integer,expiresAtMs:integer,syncStart:integer.optional()}).strict();
export type ReadCursor=z.infer<typeof payloadSchema>;
const invalid=()=>new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');
export function pageQuery(request:Request){
 const params=new URL(request.url).searchParams;
 for(const key of params.keys())if(!['limit','cursor'].includes(key)||params.getAll(key).length!==1)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
 const text=params.get('limit')??'50';
 if(!/^[1-9][0-9]*$/.test(text)||Number(text)>100)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
 const cursor=params.get('cursor');
 if(cursor!==null&&!cursorSchema.safeParse(cursor).success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
 return {limit:Number(text),cursor};
}
async function key(db:D1Database){
 let hex=await db.prepare('SELECT key_hex FROM cursor_keys WHERE id=1').first<string>('key_hex');
 if(!hex){
  const bytes=crypto.getRandomValues(new Uint8Array(32));
  const candidate=Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
  await db.prepare('INSERT OR IGNORE INTO cursor_keys(id,key_hex) VALUES (1,?)').bind(candidate).run();
  hex=await db.prepare('SELECT key_hex FROM cursor_keys WHERE id=1').first<string>('key_hex');
 }
 if(!hex)throw new Error('CURSOR_KEY_UNAVAILABLE');
 return crypto.subtle.importKey('raw',Uint8Array.from(hex.match(/../g)!,b=>parseInt(b,16)),{name:'AES-GCM'},false,['encrypt','decrypt']);
}
export async function encodeCursor(db:D1Database,payload:ReadCursor){
 const iv=crypto.getRandomValues(new Uint8Array(12));
 const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},await key(db),new TextEncoder().encode(JSON.stringify(payload))));
 const bytes=new Uint8Array(iv.length+encrypted.length);bytes.set(iv);bytes.set(encrypted,iv.length);
 return btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}
export async function decodeCursor(db:D1Database,text:string,scope:string){
 // Database/key failures remain transient server failures, rather than pretending the cursor is corrupt.
 const cryptoKey=await key(db);
 try{
  const bytes=Uint8Array.from(atob(text.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
  const decoded=await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes.slice(0,12)},cryptoKey,bytes.slice(12));
  const payload=payloadSchema.parse(JSON.parse(new TextDecoder().decode(decoded)));
  if(payload.scope!==scope||payload.expiresAtMs<=Date.now()||payload.snapshotAtMs>Date.now())throw invalid();
  return payload;
 }catch{throw invalid();}
}
export async function nextPage(db:D1Database,cursor:ReadCursor,after:string|number,hasMore:boolean){
 return {hasMore,nextCursor:hasMore?await encodeCursor(db,{...cursor,after}):null};
}
export function firstCursor(scope:string,high:number,after:string|number):ReadCursor{
 const now=Date.now();return {v:1,scope,high,after,snapshotAtMs:now,expiresAtMs:now+3600000};
}
