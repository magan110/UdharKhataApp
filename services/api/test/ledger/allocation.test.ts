import {expect,it} from 'vitest';
import {allocateLedger} from '../../src/ledger/allocation';
it('D16 payments follow due dates and reallocate after corrections',()=>{
 const entries=[{id:'a',serverSeq:1,kind:'credit' as const,amountPaise:500,dueDate:'2026-01-02'},{id:'b',serverSeq:2,kind:'credit' as const,amountPaise:300,dueDate:'2026-01-01'},{id:'p',serverSeq:3,kind:'payment' as const,amountPaise:400},{id:'c',serverSeq:4,kind:'correction' as const,correctsEntryId:'b',targetAmountPaise:100}];
 expect(allocateLedger(entries,'2026-01-02')).toMatchObject({balancePaise:200,overduePaise:0});
 expect(allocateLedger(entries,'2026-01-03')).toMatchObject({balancePaise:200,overduePaise:200});
 expect(allocateLedger([...entries].reverse(),'2026-01-03')).toEqual(allocateLedger(entries,'2026-01-03'));
});
it('D16 allocation reconciles generated ledgers, bounds overdue and keeps undated last',()=>{
 for(let n=1;n<100;n++){
 const entries=[{id:'u',serverSeq:1,kind:'credit' as const,amountPaise:n,dueDate:null},{id:'d',serverSeq:2,kind:'credit' as const,amountPaise:n*2,dueDate:'2026-01-01'},{id:'p',serverSeq:3,kind:'payment' as const,amountPaise:n}];
 const r=allocateLedger(entries,'2026-01-02');expect(r.balancePaise).toBe(n*2);expect(r.overduePaise).toBe(n);expect(r.overduePaise).toBeLessThanOrEqual(r.balancePaise);
 }
});
