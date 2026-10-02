import type {RequestEvent} from './request-event';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const segments=new Set(['health','v1','auth','google','refresh','logout','me','shops','customer-qr','resolve','qr','rotate','customers','balance','entries','ledgers','sync','disputes','data-requests','access-removal','due','export','statement']);
function safeTemplate(value:unknown):string {
 if(value==='unmatched')return value;
 if(typeof value!=='string'||value.length>180||!value.startsWith('/'))return 'unmatched';
 return value.slice(1).split('/').every(segment=>segments.has(segment)||/^\{[a-zA-Z][a-zA-Z0-9]*\}$/.test(segment))?value:'unmatched';
}
/** Return a fresh allowlisted event even if a caller accidentally supplies extra data. */
export function redactRequestEvent(value:Record<string,unknown>|RequestEvent):RequestEvent {
 const code=typeof value.errorCode==='string'&&/^[A-Z][A-Z0-9_]{0,63}$/.test(value.errorCode)?value.errorCode:null;
 return {requestId:typeof value.requestId==='string'&&uuid.test(value.requestId)?value.requestId:'invalid',route:safeTemplate(value.route),
 status:Number.isInteger(value.status)&&Number(value.status)>=100&&Number(value.status)<=599?Number(value.status):500,errorCode:code,
 durationMs:typeof value.durationMs==='number'&&Number.isFinite(value.durationMs)?Math.min(3600000,Math.max(0,Math.round(value.durationMs))):0};
}
