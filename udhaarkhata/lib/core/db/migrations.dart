import 'package:sqflite/sqflite.dart';

const localSchemaVersion = 2;

Future<void> createLocalSchema(Database db, int version) async {
  for (final sql in localSchema) {
    await db.execute(sql);
  }
  if (version >= 2) await upgradeLocalSchema(db, 1, version);
}

Future<void> upgradeLocalSchema(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion != 1 || newVersion != 2) {
    throw StateError(
      'Unsupported local schema upgrade: $oldVersion to $newVersion',
    );
  }
  for (final sql in localSchemaV2) {
    await db.execute(sql);
  }
}

const localSchemaV2 = <String>[
  'ALTER TABLE cached_links ADD COLUMN display_name TEXT',
  'ALTER TABLE cached_links ADD COLUMN nickname TEXT',
  'ALTER TABLE cached_links ADD COLUMN linked_at_ms INTEGER',
  '''CREATE TABLE owner_ledger_snapshots (
    link_id TEXT PRIMARY KEY REFERENCES cached_links(id) ON DELETE RESTRICT,
    balance_paise INTEGER NOT NULL CHECK(typeof(balance_paise)='integer' AND balance_paise BETWEEN 0 AND 9007199254740991),
    ledger_version INTEGER NOT NULL CHECK(typeof(ledger_version)='integer' AND ledger_version BETWEEN 0 AND 9007199254740991),
    server_seq INTEGER NOT NULL CHECK(typeof(server_seq)='integer' AND server_seq BETWEEN 0 AND 9007199254740991),
    snapshot_at_ms INTEGER NOT NULL CHECK(typeof(snapshot_at_ms)='integer' AND snapshot_at_ms BETWEEN 0 AND 9007199254740991)
  )''',
];

// Storage ceiling only; business entry limits are narrowed in D08.
const localSchema = <String>[
  '''CREATE TABLE local_account (
    singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
    user_id TEXT NOT NULL UNIQUE,
    role TEXT CHECK(role IN ('owner','customer')),
    last_verified_at_ms INTEGER CHECK(last_verified_at_ms IS NULL OR
      typeof(last_verified_at_ms)='integer' AND last_verified_at_ms BETWEEN 0 AND 9007199254740991)
  )''',
  '''CREATE TABLE cached_links (
    id TEXT NOT NULL PRIMARY KEY,
    shop_id TEXT NOT NULL, customer_user_id TEXT NOT NULL, owner_user_id TEXT NOT NULL,
    verified_qr_id TEXT, status TEXT NOT NULL CHECK(status IN ('active','access_removed')),
    last_verified_at_ms INTEGER NOT NULL CHECK(typeof(last_verified_at_ms)='integer' AND last_verified_at_ms BETWEEN 0 AND 9007199254740991),
    UNIQUE(shop_id,customer_user_id)
  )''',
  '''CREATE TABLE cached_entries (
    local_id TEXT NOT NULL PRIMARY KEY,
    server_id TEXT UNIQUE,
    server_seq INTEGER UNIQUE CHECK(server_seq IS NULL OR typeof(server_seq)='integer' AND server_seq BETWEEN 1 AND 9007199254740991),
    link_id TEXT NOT NULL REFERENCES cached_links(id) ON DELETE RESTRICT,
    client_operation_id TEXT UNIQUE CHECK(client_operation_id IS NULL OR length(client_operation_id)=36 AND substr(client_operation_id,9,1)='-' AND substr(client_operation_id,14,1)='-' AND substr(client_operation_id,19,1)='-' AND substr(client_operation_id,24,1)='-' AND substr(client_operation_id,15,1)='4' AND substr(client_operation_id,20,1) IN ('8','9','a','b') AND length(replace(client_operation_id,'-',''))=32 AND replace(client_operation_id,'-','') NOT GLOB '*[^0-9a-f]*'),
    kind TEXT NOT NULL CHECK(kind IN ('credit','payment','correction')),
    amount_paise INTEGER CHECK(amount_paise IS NULL OR typeof(amount_paise)='integer' AND amount_paise BETWEEN 1 AND 9007199254740991),
    target_amount_paise INTEGER CHECK(target_amount_paise IS NULL OR typeof(target_amount_paise)='integer' AND target_amount_paise BETWEEN 0 AND 9007199254740991),
    effect_paise INTEGER NOT NULL CHECK(typeof(effect_paise)='integer' AND effect_paise BETWEEN -9007199254740991 AND 9007199254740991),
    note TEXT CHECK(note IS NULL OR length(note)<=500),
    payment_method TEXT CHECK(payment_method IN ('cash','upi')),
    due_date TEXT CHECK(due_date IS NULL OR length(due_date)=10 AND due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(due_date,'+0 days') IS due_date),
    corrects_entry_id TEXT,
    expected_revision INTEGER CHECK(expected_revision IS NULL OR typeof(expected_revision)='integer' AND expected_revision BETWEEN 0 AND 9007199254740991),
    correction_reason TEXT CHECK(correction_reason IS NULL OR length(correction_reason)<=500),
    occurred_at_ms INTEGER NOT NULL CHECK(typeof(occurred_at_ms)='integer' AND occurred_at_ms BETWEEN 0 AND 9007199254740991),
    created_at_ms INTEGER CHECK(created_at_ms IS NULL OR typeof(created_at_ms)='integer' AND created_at_ms BETWEEN 0 AND 9007199254740991),
    sync_status TEXT NOT NULL CHECK(sync_status IN ('pending','synced','needs_attention')),
    CHECK(sync_status!='synced' OR server_id IS NOT NULL AND server_seq IS NOT NULL),
    CHECK(sync_status='synced' OR client_operation_id IS NOT NULL),
    CHECK(
      kind='credit' AND amount_paise IS NOT NULL AND effect_paise=amount_paise
        AND target_amount_paise IS NULL AND payment_method IS NULL AND corrects_entry_id IS NULL AND expected_revision IS NULL AND correction_reason IS NULL
      OR kind='payment' AND amount_paise IS NOT NULL AND effect_paise=-amount_paise
        AND target_amount_paise IS NULL AND payment_method IS NOT NULL AND due_date IS NULL AND corrects_entry_id IS NULL AND expected_revision IS NULL AND correction_reason IS NULL
      OR kind='correction' AND amount_paise IS NULL AND target_amount_paise IS NOT NULL
        AND corrects_entry_id IS NOT NULL AND expected_revision IS NOT NULL AND correction_reason IS NOT NULL
        AND length(trim(correction_reason))>0 AND payment_method IS NULL AND due_date IS NULL
    )
  )''',
  '''CREATE INDEX ix_cache_entries_link ON cached_entries(link_id,server_seq)''',
  '''CREATE TABLE outbox (
    operation_id TEXT NOT NULL PRIMARY KEY REFERENCES cached_entries(client_operation_id) ON DELETE RESTRICT,
    link_id TEXT NOT NULL REFERENCES cached_links(id) ON DELETE RESTRICT,
    payload TEXT NOT NULL CHECK(length(payload) BETWEEN 2 AND 65536),
    request_hash TEXT NOT NULL CHECK(length(request_hash)=64 AND request_hash NOT GLOB '*[^0-9a-f]*'),
    created_at_ms INTEGER NOT NULL CHECK(typeof(created_at_ms)='integer' AND created_at_ms BETWEEN 0 AND 9007199254740991),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK(typeof(attempts)='integer' AND attempts>=0),
    retry_at_ms INTEGER CHECK(retry_at_ms IS NULL OR typeof(retry_at_ms)='integer' AND retry_at_ms BETWEEN 0 AND 9007199254740991),
    state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','needs_attention')),
    error_code TEXT
  )''',
  '''CREATE INDEX ix_outbox_retry ON outbox(state,created_at_ms,operation_id)''',
  '''CREATE TABLE sync_cursors (
    scope TEXT NOT NULL PRIMARY KEY REFERENCES cached_links(id) ON DELETE RESTRICT,
    sequence INTEGER NOT NULL CHECK(typeof(sequence)='integer' AND sequence BETWEEN 0 AND 9007199254740991),
    last_sync_at_ms INTEGER NOT NULL CHECK(typeof(last_sync_at_ms)='integer' AND last_sync_at_ms BETWEEN 0 AND 9007199254740991)
  )''',
  '''CREATE TABLE cached_disputes (
    id TEXT NOT NULL PRIMARY KEY,
    entry_id TEXT NOT NULL REFERENCES cached_entries(server_id) ON DELETE RESTRICT,
    status TEXT NOT NULL CHECK(status IN ('open','resolved')),
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 500),
    owner_note TEXT CHECK(owner_note IS NULL OR length(owner_note)<=500),
    updated_at_ms INTEGER NOT NULL CHECK(typeof(updated_at_ms)='integer' AND updated_at_ms BETWEEN 0 AND 9007199254740991)
  )''',
  // ponytail: sum scans one linked history; materialize only if profiling shows latency.
  '''CREATE VIEW cached_balances AS SELECT l.id AS link_id,
    COALESCE(SUM(CASE WHEN e.sync_status='synced' THEN e.effect_paise ELSE 0 END),0) AS synced_paise,
    COALESCE(SUM(CASE WHEN e.sync_status='pending' THEN e.effect_paise ELSE 0 END),0) AS pending_paise
    FROM cached_links l LEFT JOIN cached_entries e ON e.link_id=l.id GROUP BY l.id''',
  '''CREATE TRIGGER cached_command_immutable BEFORE UPDATE OF local_id,link_id,client_operation_id,kind,amount_paise,target_amount_paise,effect_paise,note,payment_method,due_date,corrects_entry_id,expected_revision,correction_reason,occurred_at_ms ON cached_entries
    BEGIN SELECT RAISE(ABORT,'COMMAND_IMMUTABLE'); END''',
  '''CREATE TRIGGER outbox_command_immutable BEFORE UPDATE OF operation_id,link_id,payload,request_hash,created_at_ms ON outbox
    BEGIN SELECT RAISE(ABORT,'COMMAND_IMMUTABLE'); END''',
  '''CREATE TRIGGER outbox_scope BEFORE INSERT ON outbox BEGIN
    SELECT RAISE(ABORT,'OUTBOX_SCOPE') WHERE NOT EXISTS (SELECT 1 FROM cached_entries WHERE client_operation_id=NEW.operation_id AND link_id=NEW.link_id AND sync_status='pending');
  END''',
  '''CREATE TRIGGER local_account_identity BEFORE UPDATE OF user_id ON local_account
    BEGIN SELECT RAISE(ABORT,'ACCOUNT_IMMUTABLE'); END''',
];
