export interface AllocationEntry {id:string;serverSeq:number;kind:'credit'|'payment'|'correction';amountPaise?:number|null;targetAmountPaise?:number|null;correctsEntryId?:string|null;dueDate?:string|null}
export function allocateLedger(entries:readonly AllocationEntry[],asOfDate:string){
 const ordered=[...entries].sort((a,b)=>a.serverSeq-b.serverSeq||a.id.localeCompare(b.id));
 const originals=new Map<string,{entry:AllocationEntry;amount:number}>();
 for(const entry of ordered){
  if(entry.kind==='correction'){
   const original=originals.get(entry.correctsEntryId??'');
   if(!original||entry.targetAmountPaise===null||entry.targetAmountPaise===undefined)throw new Error('INVALID_ALLOCATION_DATA');
   original.amount=entry.targetAmountPaise;
  }else originals.set(entry.id,{entry,amount:entry.amountPaise??0});
 }
 let payments=0,totalCredit=0;
 const credits=[...originals.values()].filter(v=>{if(v.entry.kind==='payment'){payments+=v.amount;return false;}totalCredit+=v.amount;return true;}).sort((a,b)=>(a.entry.dueDate??'9999-99-99').localeCompare(b.entry.dueDate??'9999-99-99')||a.entry.serverSeq-b.entry.serverSeq||a.entry.id.localeCompare(b.entry.id));
 const balancePaise=totalCredit-payments;
 if(!Number.isSafeInteger(totalCredit)||!Number.isSafeInteger(payments)||balancePaise<0)throw new Error('INVALID_ALLOCATION_DATA');
 let overduePaise=0;
 const allocations=credits.map(({entry,amount})=>{const paidPaise=Math.min(payments,amount);payments-=paidPaise;const remainingPaise=amount-paidPaise;if(entry.dueDate&&entry.dueDate<asOfDate)overduePaise+=remainingPaise;return {entryId:entry.id,remainingPaise,paidPaise};});
 return {balancePaise,overduePaise,allocations};
}
