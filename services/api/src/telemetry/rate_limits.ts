/** Synthetic private-test defaults; tune from aggregate shared-network traffic. */
export function ratePolicy(route:string):{periodMs:number;limit:number} {
 switch(route){
  case 'google':return {periodMs:600000,limit:10};
  case 'read-owner':return {periodMs:60000,limit:120};
  case 'refresh':return {periodMs:60000,limit:120};
  case 'qr-rotate':return {periodMs:600000,limit:3};
  case 'qr-resolve-network':return {periodMs:60000,limit:300};
  case 'qr-resolve-owner':return {periodMs:60000,limit:30};
  case 'entry-owner':return {periodMs:60000,limit:60};
  case 'link-owner':return {periodMs:60000,limit:30};
  case 'dispute-customer':case 'dispute-owner':return {periodMs:60000,limit:20};
  case 'export-owner':return {periodMs:60000,limit:6};
  case 'privacy-request':return {periodMs:60000,limit:10};
  default:return {periodMs:60000,limit:30};
 }
}
