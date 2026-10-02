import { applyD1Migrations, type D1Migration } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { beforeEach, describe, expect, it } from 'vitest';
import { commitEntry } from '../../src/db/transaction';
import { findReceipt } from '../../src/db/queries';

declare global {
  // Cloudflare binding types use global namespace augmentation.
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Cloudflare {
    interface Env { DB: D1Database; MIGRATIONS: D1Migration[] }
  }
}

const db = env.DB;
const run = (sql: string, ...args: (string | number | null)[]) => db.prepare(sql).bind(...args).run();
let serial = 0;
function entry(overrides: Record<string, string | number | null> = {}) {
  const n = ++serial;
  const row = {
    id: `entry_${n}`, shop_customer_id: 'link', shop_id: 'shop', customer_user_id: 'customer',
    kind: 'credit', amount_paise: 50000, target_amount_paise: null, effect_paise: 50000,
    payment_method: null, corrects_entry_id: null, expected_revision: null, correction_reason: null,
    created_by_user_id: 'owner', client_operation_id: `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`,
    occurred_at_ms: 1, created_at_ms: 1, ...overrides,
  };
  return db.prepare(`INSERT INTO ledger_entries (${Object.keys(row).join(',')}) VALUES (${Object.keys(row).map(() => '?').join(',')})`).bind(...Object.values(row));
}
async function balance() {
  return db.prepare('SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id=?').bind('link').first();
}

beforeEach(async () => {
  // This pinned pool keeps D1 storage between tests; rebuild only synthetic tables.
  await db.batch([
    db.prepare('PRAGMA defer_foreign_keys=ON'),
    ...['cursor_keys','spent_refresh_tokens','auth_rate_limits','access_sessions','disputes','sync_operations','entry_effective','ledger_entries','ledger_accounts','data_requests','refresh_sessions','shop_customers','customer_qr_ids','shops','users','d1_migrations'].map(table => db.prepare(`DROP TABLE IF EXISTS ${table}`)),
  ]);
  await applyD1Migrations(db, env.MIGRATIONS);
  await run("INSERT INTO users(id,google_sub,account_role,display_name,created_at_ms) VALUES ('owner','sub_o','owner','Owner',1),('customer','sub_c','customer','Customer',1),('other','sub_x','customer','Other',1)");
  await run("INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) VALUES ('shop','owner','Shop','active',1)");
  await run("INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('link','shop','customer','active',1)");
});

describe('D03 D1 invariants', () => {
  it('replays concurrent duplicate commands with one effect and rejects changed hash', async () => {
    const op='00000000-0000-4000-8000-000000000997';
    const input={shopId:'shop',operationId:op,requestHash:'a'.repeat(64),entryId:'same',createdAtMs:1};
    const results=await Promise.all([commitEntry(db,entry({id:'same',client_operation_id:op}),input),commitEntry(db,entry({id:'same',client_operation_id:op}),input)]);
    expect(results[0]).toEqual(results[1]);
    expect(await balance()).toEqual({balance_paise:50000,version:1});
    await expect(commitEntry(db,entry(),{...input,requestHash:'b'.repeat(64)})).rejects.toThrow('IDEMPOTENCY_CONFLICT');
  });
  it('fails a mismatched receipt scope without leaving an entry', async () => {
    await expect(commitEntry(db,entry(),{shopId:'shop',operationId:'00000000-0000-4000-8000-000000000996',requestHash:'a'.repeat(64),entryId:'absent',createdAtMs:1})).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:0,version:0});
  });
  it('rehearses additive upgrade and failed migration without losing posted history', async () => {
    await entry().run();
    const upgrade={name:'test_only_upgrade.sql',queries:['ALTER TABLE users ADD COLUMN migration_probe INTEGER NOT NULL DEFAULT 0']};
    await applyD1Migrations(db,[...env.MIGRATIONS,upgrade]);
    await applyD1Migrations(db,[...env.MIGRATIONS,upgrade]);
    await expect(applyD1Migrations(db,[{name:'test_only_bad.sql',queries:['CREATE TABLE rollback_probe(id INTEGER)','INSERT INTO absent_table VALUES (1)']}])).rejects.toThrow();
    expect(await db.prepare("SELECT name FROM sqlite_master WHERE name='rollback_probe'").first()).toBeNull();
    expect(await balance()).toEqual({balance_paise:50000,version:1});
  });
  it('rejects invalid calendar dates, operation IDs and stale revision types', async () => {
    await expect(entry({due_date:'2026-02-31'}).run()).rejects.toThrow();
    await expect(entry({client_operation_id:'invalid'}).run()).rejects.toThrow();
    await entry({id:'original'}).run();
    await expect(entry({kind:'correction',amount_paise:null,target_amount_paise:40000,effect_paise:-10000,corrects_entry_id:'original',expected_revision:0.5,correction_reason:'Fix'}).run()).rejects.toThrow();
  });
  it('commits a receipt atomically and replays the original result after later writes', async () => {
    const op='00000000-0000-4000-8000-000000000999';
    const statement=entry({id:'receipted',client_operation_id:op});
    const hash='a'.repeat(64);
    const result=await commitEntry(db,statement,{shopId:'shop',operationId:op,requestHash:hash,entryId:'receipted',createdAtMs:1});
    await entry({amount_paise:1,effect_paise:1}).run();
    expect(await findReceipt(db,'shop',op)).toEqual(result);
    expect(result).toMatchObject({entry_id:'receipted',response_balance_paise:50000,response_version:1});
    expect(await findReceipt(db,'unknown',op)).toBeNull();
    await expect(commitEntry(db,entry(),{shopId:'shop',operationId:op,requestHash:'b'.repeat(64),entryId:'other',createdAtMs:1})).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:50001,version:2});
    await expect(run("UPDATE sync_operations SET request_hash=?",'b'.repeat(64))).rejects.toThrow();
    await expect(run('DELETE FROM sync_operations')).rejects.toThrow();
  });
  it('a malformed receipt rolls back the entry and projections', async () => {
    const op='00000000-0000-4000-8000-000000000998';
    await expect(commitEntry(db,entry({id:'rolled',client_operation_id:op}),{shopId:'shop',operationId:op,requestHash:'bad',entryId:'rolled',createdAtMs:1})).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:0,version:0});
    expect(await findReceipt(db,'shop',op)).toBeNull();
  });
  it('applies once, preserves data on repeat, and passes foreign key check', async () => {
    await entry().run();
    await applyD1Migrations(db, env.MIGRATIONS);
    expect(await balance()).toEqual({ balance_paise: 50000, version: 1 });
    expect((await db.prepare('PRAGMA foreign_key_check').all()).results).toEqual([]);
    expect((await db.prepare('SELECT name FROM d1_migrations').all()).results).toHaveLength(env.MIGRATIONS.length);
  });
  it('rejects dangling references, duplicate shops/links and wrong roles', async () => {
    await expect(run("INSERT INTO shops VALUES ('bad','missing','Shop','active',1,NULL)")).rejects.toThrow();
    await expect(run("INSERT INTO shops VALUES ('bad','owner','Shop','active',1,NULL)")).rejects.toThrow();
    await expect(run("INSERT INTO shops VALUES ('bad','customer','Shop','active',1,NULL)")).rejects.toThrow();
    await expect(run("INSERT INTO shop_customers(id,shop_id,customer_user_id,status,linked_at_ms) VALUES ('dup','shop','customer','active',1)")).rejects.toThrow();
    await expect(run("INSERT INTO customer_qr_ids VALUES ('qr','owner','active',1,NULL)")).rejects.toThrow();
  });
  it('allows only one active QR and preserves links on rotation', async () => {
    await run("INSERT INTO customer_qr_ids VALUES ('qr','customer','active',1,NULL)");
    await expect(run("INSERT INTO customer_qr_ids VALUES ('qr2','customer','active',1,NULL)")).rejects.toThrow();
    await db.batch([db.prepare("UPDATE customer_qr_ids SET status='revoked',revoked_at_ms=2 WHERE public_id='qr'"), db.prepare("INSERT INTO customer_qr_ids VALUES ('qr2','customer','active',2,NULL)")]);
    expect(await balance()).toEqual({ balance_paise: 0, version: 0 });
  });
  it('posts exact effects, prevents an overpayment race, and reconciles', async () => {
    await entry().run();
    const results = await Promise.allSettled([1,2].map(() => entry({kind:'payment',amount_paise:30000,effect_paise:-30000,payment_method:'cash'}).run()));
    expect(results.filter(r => r.status === 'fulfilled')).toHaveLength(1);
    expect(await balance()).toEqual({ balance_paise: 20000, version: 2 });
    expect(await db.prepare("SELECT SUM(effect_paise) AS total FROM ledger_entries WHERE shop_customer_id='link'").first('total')).toBe(20000);
  });
  it('rejects null magnitudes, real/unsafe money, bad effects and unowned/inactive links', async () => {
    const invalid: Record<string,string|number|null>[] = [{amount_paise:null}, {amount_paise:1.5,effect_paise:1.5}, {amount_paise:9007199254740992,effect_paise:9007199254740992}, {effect_paise:1}, {created_by_user_id:'other'}, {customer_user_id:'other'}];
    for (const changes of invalid) {
      await expect(entry(changes).run()).rejects.toThrow();
    }
    await run("UPDATE shop_customers SET status='access_removed',access_removed_at_ms=2 WHERE id='link'");
    await expect(entry().run()).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:0,version:0});
  });
  it('rejects balance overflow at commit', async () => {
    await entry({amount_paise:Number.MAX_SAFE_INTEGER,effect_paise:Number.MAX_SAFE_INTEGER}).run();
    await expect(entry({amount_paise:1,effect_paise:1}).run()).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:Number.MAX_SAFE_INTEGER,version:1});
  });
  it('keeps posted history immutable, including INSERT OR REPLACE', async () => {
    await entry({id:'original'}).run();
    await expect(run("UPDATE ledger_entries SET note='changed' WHERE id='original'")).rejects.toThrow();
    await expect(run("DELETE FROM ledger_entries WHERE id='original'")).rejects.toThrow();
    const sql = entry({id:'original'});
    await expect(sql.run()).rejects.toThrow();
    await expect(run("INSERT OR REPLACE INTO ledger_entries SELECT * FROM ledger_entries WHERE id='original'")).rejects.toThrow();
  });
  it('applies successive correction deltas and rejects stale revisions and wrong targets', async () => {
    await entry({id:'original'}).run();
    const correction = {kind:'correction',amount_paise:null,target_amount_paise:45000,effect_paise:-5000,corrects_entry_id:'original',expected_revision:0,correction_reason:'Fix'};
    const results = await Promise.allSettled([entry({...correction,id:'fix1'}).run(),entry(correction).run()]);
    expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);
    await entry({...correction,target_amount_paise:40000,expected_revision:1}).run();
    await expect(entry({...correction,expected_revision:2,effect_paise:-10000}).run()).rejects.toThrow();
    await expect(entry({...correction,corrects_entry_id:'fix1'}).run()).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:40000,version:3});
    expect(await db.prepare("SELECT effective_paise,revision FROM entry_effective WHERE entry_id='original'").first()).toEqual({effective_paise:40000,revision:2});
  });
  it('cancels a payment and blocks a correction that would overdraw', async () => {
    await entry({id:'credit'}).run();
    await entry({id:'payment',kind:'payment',amount_paise:20000,effect_paise:-20000,payment_method:'upi'}).run();
    const correction={kind:'correction',amount_paise:null,target_amount_paise:0,expected_revision:0,correction_reason:'Cancel'};
    await expect(entry({...correction,corrects_entry_id:'credit',effect_paise:-50000}).run()).rejects.toThrow();
    await entry({...correction,corrects_entry_id:'payment',effect_paise:20000}).run();
    expect(await balance()).toEqual({balance_paise:50000,version:3});
  });
  it('rolls back entry and projections when a later batch statement fails', async () => {
    await expect(db.batch([entry(),db.prepare("INSERT INTO users VALUES ('owner','duplicate','owner','Owner',NULL,1,NULL)")])).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:0,version:0});
    expect((await db.prepare('SELECT * FROM ledger_entries').all()).results).toHaveLength(0);
    expect((await db.prepare('SELECT * FROM entry_effective').all()).results).toHaveLength(0);
  });
  it('checks dispute scope and never alters the balance', async () => {
    await entry({id:'original'}).run();
    await expect(run("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms) VALUES ('bad','original','link','other','Problem','open',1)")).rejects.toThrow();
    await run("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms) VALUES ('d','original','link','customer','Problem','open',1)");
    await expect(run("INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms) VALUES ('dup','original','link','customer','Problem','open',1)")).rejects.toThrow();
    expect(await balance()).toEqual({balance_paise:50000,version:1});
  });
});
