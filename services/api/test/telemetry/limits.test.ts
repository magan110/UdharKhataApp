import {expect,it} from 'vitest';
import {ratePolicy} from '../../src/telemetry/rate_limits';
import {redactRequestEvent} from '../../src/telemetry/redaction';
it('D20 gives shared QR networks headroom without weakening per-owner buckets',()=>{
 expect(ratePolicy('qr-resolve-network').limit).toBeGreaterThanOrEqual(10*ratePolicy('qr-resolve-owner').limit);
 expect(ratePolicy('entry-owner').limit).toBe(60);
 expect(ratePolicy('dispute-customer').limit).toBeLessThanOrEqual(30);
 expect(ratePolicy('export-owner').limit).toBeLessThanOrEqual(10);
});
it('D20 telemetry allowlists fields, templates and safe bounded codes',()=>{
 const safe=redactRequestEvent({requestId:'a1701b6b-a610-4a2b-98b4-741874974d56',route:'/v1/shops/{shopId}/entries',status:429,errorCode:'RATE_LIMITED',durationMs:10,token:'secret',amountPaise:123,name:'private',note:'private'});
 expect(safe).toEqual({requestId:'a1701b6b-a610-4a2b-98b4-741874974d56',route:'/v1/shops/{shopId}/entries',status:429,errorCode:'RATE_LIMITED',durationMs:10});
 expect(JSON.stringify(redactRequestEvent({...safe,route:'/v1/shops/PRIVATE/entries',errorCode:'private note',durationMs:Infinity}))).not.toContain('PRIVATE');
 expect(redactRequestEvent({...safe,requestId:'raw subject',status:-1}).requestId).toBe('invalid');
});
