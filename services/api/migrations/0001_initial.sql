-- D03 initial schema; immutable after application. Money ceiling is JS safe integer.
CREATE TABLE users (
  id TEXT NOT NULL PRIMARY KEY,
  google_sub TEXT NOT NULL UNIQUE CHECK (google_sub IS NULL OR length(google_sub) <= 255),
  account_role TEXT NOT NULL CHECK (account_role IN ('owner','customer')),
  display_name TEXT NOT NULL CHECK (display_name IS NULL OR length(display_name) <= 120),
  email TEXT CHECK (email IS NULL OR length(email) <= 320),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  deleted_at_ms INTEGER CHECK (deleted_at_ms IS NULL OR (typeof(deleted_at_ms) = 'integer' AND deleted_at_ms BETWEEN 0 AND 9007199254740991))
);

CREATE TABLE customer_qr_ids (
  public_id TEXT NOT NULL PRIMARY KEY,
  customer_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('active','revoked')),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  revoked_at_ms INTEGER CHECK (revoked_at_ms IS NULL OR (typeof(revoked_at_ms) = 'integer' AND revoked_at_ms BETWEEN 0 AND 9007199254740991)),
  CHECK ((status = 'active' AND revoked_at_ms IS NULL) OR
         (status = 'revoked' AND revoked_at_ms IS NOT NULL))
);
CREATE UNIQUE INDEX uq_one_active_qr_per_customer
  ON customer_qr_ids(customer_user_id) WHERE status = 'active';

CREATE TABLE shops (
  id TEXT NOT NULL PRIMARY KEY,
  owner_user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0) CHECK (name IS NULL OR length(name) <= 120),
  status TEXT NOT NULL CHECK (status IN ('active','closed')),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  closed_at_ms INTEGER CHECK (closed_at_ms IS NULL OR (typeof(closed_at_ms) = 'integer' AND closed_at_ms BETWEEN 0 AND 9007199254740991))
);

CREATE TABLE shop_customers (
  id TEXT NOT NULL PRIMARY KEY,
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  customer_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  shop_nickname TEXT CHECK (shop_nickname IS NULL OR length(shop_nickname) <= 120),
  status TEXT NOT NULL CHECK (status IN ('active','access_removed')),
  linked_at_ms INTEGER NOT NULL CHECK ((typeof(linked_at_ms) = 'integer' AND linked_at_ms BETWEEN 0 AND 9007199254740991)),
  access_removed_at_ms INTEGER CHECK (access_removed_at_ms IS NULL OR (typeof(access_removed_at_ms) = 'integer' AND access_removed_at_ms BETWEEN 0 AND 9007199254740991)),
  UNIQUE (shop_id, customer_user_id),
  UNIQUE (id, shop_id, customer_user_id)
);

CREATE TABLE ledger_accounts (
  shop_customer_id TEXT NOT NULL PRIMARY KEY REFERENCES shop_customers(id) ON DELETE RESTRICT,
  balance_paise INTEGER NOT NULL CHECK ((typeof(balance_paise) = 'integer' AND balance_paise BETWEEN -9007199254740991 AND 9007199254740991)) DEFAULT 0 CHECK (balance_paise >= 0),
  version INTEGER NOT NULL DEFAULT 0 CHECK (typeof(version) = 'integer' AND version BETWEEN 0 AND 9007199254740991),
  updated_at_ms INTEGER NOT NULL CHECK ((typeof(updated_at_ms) = 'integer' AND updated_at_ms BETWEEN 0 AND 9007199254740991))
);

CREATE TABLE ledger_entries (
  server_seq INTEGER PRIMARY KEY AUTOINCREMENT CHECK(typeof(server_seq)='integer' AND server_seq BETWEEN 1 AND 9007199254740991),
  id TEXT NOT NULL UNIQUE,
  shop_customer_id TEXT NOT NULL REFERENCES shop_customers(id) ON DELETE RESTRICT,
  shop_id TEXT NOT NULL,
  customer_user_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('credit','payment','correction')),
  amount_paise INTEGER CHECK (amount_paise IS NULL OR (typeof(amount_paise) = 'integer' AND amount_paise BETWEEN -9007199254740991 AND 9007199254740991)),
  target_amount_paise INTEGER CHECK (target_amount_paise IS NULL OR (typeof(target_amount_paise) = 'integer' AND target_amount_paise BETWEEN -9007199254740991 AND 9007199254740991)),
  effect_paise INTEGER NOT NULL CHECK ((typeof(effect_paise) = 'integer' AND effect_paise BETWEEN -9007199254740991 AND 9007199254740991)),
  note TEXT CHECK (note IS NULL OR length(note) <= 500),
  payment_method TEXT CHECK (payment_method IN ('cash','upi')),
  due_date TEXT CHECK(due_date IS NULL OR length(due_date)=10 AND due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(due_date,'+0 days') IS due_date),
  corrects_entry_id TEXT REFERENCES ledger_entries(id) ON DELETE RESTRICT,
  expected_revision INTEGER,
  correction_reason TEXT CHECK (correction_reason IS NULL OR length(correction_reason) <= 500),
  created_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  client_operation_id TEXT NOT NULL CHECK(length(client_operation_id)=36 AND substr(client_operation_id,9,1)='-' AND substr(client_operation_id,14,1)='-' AND substr(client_operation_id,19,1)='-' AND substr(client_operation_id,24,1)='-' AND substr(client_operation_id,15,1)='4' AND substr(client_operation_id,20,1) IN ('8','9','a','b') AND length(replace(client_operation_id,'-',''))=32 AND replace(client_operation_id,'-','') NOT GLOB '*[^0-9a-f]*'),
  device_id TEXT CHECK (device_id IS NULL OR length(device_id) <= 128),
  occurred_at_ms INTEGER NOT NULL CHECK ((typeof(occurred_at_ms) = 'integer' AND occurred_at_ms BETWEEN 0 AND 9007199254740991)),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  FOREIGN KEY (shop_customer_id, shop_id, customer_user_id)
    REFERENCES shop_customers(id, shop_id, customer_user_id),
  UNIQUE (shop_id, client_operation_id),
  CHECK (
    (kind = 'credit' AND amount_paise IS NOT NULL AND amount_paise > 0 AND target_amount_paise IS NULL
      AND effect_paise = amount_paise AND payment_method IS NULL
      AND corrects_entry_id IS NULL AND expected_revision IS NULL
      AND correction_reason IS NULL)
    OR
    (kind = 'payment' AND amount_paise IS NOT NULL AND amount_paise > 0 AND target_amount_paise IS NULL
      AND effect_paise = -amount_paise AND payment_method IS NOT NULL
      AND due_date IS NULL AND corrects_entry_id IS NULL
      AND expected_revision IS NULL AND correction_reason IS NULL)
    OR
    (kind = 'correction' AND amount_paise IS NULL AND target_amount_paise IS NOT NULL AND target_amount_paise >= 0
      AND payment_method IS NULL AND due_date IS NULL
      AND corrects_entry_id IS NOT NULL AND expected_revision IS NOT NULL AND typeof(expected_revision) = 'integer' AND expected_revision BETWEEN 0 AND 9007199254740991
      AND correction_reason IS NOT NULL AND length(trim(correction_reason)) > 0)
  )
);

CREATE TABLE entry_effective (
  entry_id TEXT NOT NULL PRIMARY KEY REFERENCES ledger_entries(id) ON DELETE RESTRICT,
  shop_customer_id TEXT NOT NULL REFERENCES shop_customers(id) ON DELETE RESTRICT,
  effective_paise INTEGER NOT NULL CHECK ((typeof(effective_paise) = 'integer' AND effective_paise BETWEEN -9007199254740991 AND 9007199254740991)),
  revision INTEGER NOT NULL DEFAULT 0 CHECK (typeof(revision) = 'integer' AND revision BETWEEN 0 AND 9007199254740991)
);

CREATE TABLE sync_operations (
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  client_operation_id TEXT NOT NULL CHECK(length(client_operation_id)=36 AND substr(client_operation_id,9,1)='-' AND substr(client_operation_id,14,1)='-' AND substr(client_operation_id,19,1)='-' AND substr(client_operation_id,24,1)='-' AND substr(client_operation_id,15,1)='4' AND substr(client_operation_id,20,1) IN ('8','9','a','b') AND length(replace(client_operation_id,'-',''))=32 AND replace(client_operation_id,'-','') NOT GLOB '*[^0-9a-f]*'),
  operation_kind TEXT NOT NULL CHECK (operation_kind IN ('link','entry')),
  request_hash TEXT NOT NULL,
  entry_id TEXT UNIQUE REFERENCES ledger_entries(id) ON DELETE RESTRICT,
  shop_customer_id TEXT REFERENCES shop_customers(id) ON DELETE RESTRICT,
  response_version INTEGER,
  response_balance_paise INTEGER CHECK (response_balance_paise IS NULL OR (typeof(response_balance_paise) = 'integer' AND response_balance_paise BETWEEN -9007199254740991 AND 9007199254740991)),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  PRIMARY KEY (shop_id, client_operation_id),
  CHECK ((operation_kind = 'entry' AND entry_id IS NOT NULL AND shop_customer_id IS NULL
           AND response_version IS NOT NULL AND response_balance_paise IS NOT NULL)
      OR (operation_kind = 'link' AND entry_id IS NULL AND shop_customer_id IS NOT NULL))
);

CREATE TABLE disputes (
  id TEXT NOT NULL PRIMARY KEY,
  entry_id TEXT NOT NULL REFERENCES ledger_entries(id) ON DELETE RESTRICT,
  shop_customer_id TEXT NOT NULL REFERENCES shop_customers(id) ON DELETE RESTRICT,
  customer_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL CHECK (length(trim(reason)) > 0) CHECK (reason IS NULL OR length(reason) <= 500),
  status TEXT NOT NULL CHECK (status IN ('open','resolved')),
  owner_note TEXT CHECK (owner_note IS NULL OR length(owner_note) <= 500),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  resolved_at_ms INTEGER CHECK (resolved_at_ms IS NULL OR (typeof(resolved_at_ms) = 'integer' AND resolved_at_ms BETWEEN 0 AND 9007199254740991)),
  resolved_by_user_id TEXT REFERENCES users(id) ON DELETE RESTRICT,
  CHECK ((status = 'open' AND resolved_at_ms IS NULL AND resolved_by_user_id IS NULL)
      OR (status = 'resolved' AND resolved_at_ms IS NOT NULL AND resolved_by_user_id IS NOT NULL))
);
CREATE UNIQUE INDEX uq_one_open_dispute_per_entry
  ON disputes(entry_id, customer_user_id) WHERE status = 'open';

CREATE TABLE refresh_sessions (
  id TEXT NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  device_id TEXT NOT NULL CHECK (device_id IS NULL OR length(device_id) <= 128),
  token_hash TEXT NOT NULL UNIQUE CHECK(length(token_hash)=64 AND token_hash NOT GLOB '*[^0-9a-f]*'),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  expires_at_ms INTEGER NOT NULL CHECK ((typeof(expires_at_ms) = 'integer' AND expires_at_ms BETWEEN 0 AND 9007199254740991)),
  revoked_at_ms INTEGER CHECK (revoked_at_ms IS NULL OR (typeof(revoked_at_ms) = 'integer' AND revoked_at_ms BETWEEN 0 AND 9007199254740991)),
  CHECK (expires_at_ms > created_at_ms)
);

CREATE TABLE data_requests (
  id TEXT NOT NULL PRIMARY KEY,
  requester_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  request_kind TEXT NOT NULL CHECK (request_kind IN ('export','account_deletion','shop_deletion','access_removal')),
  scope_shop_id TEXT REFERENCES shops(id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('submitted','in_review','completed','denied')),
  created_at_ms INTEGER NOT NULL CHECK ((typeof(created_at_ms) = 'integer' AND created_at_ms BETWEEN 0 AND 9007199254740991)),
  resolved_at_ms INTEGER CHECK (resolved_at_ms IS NULL OR (typeof(resolved_at_ms) = 'integer' AND resolved_at_ms BETWEEN 0 AND 9007199254740991)),
  resolution_note TEXT CHECK (resolution_note IS NULL OR length(resolution_note) <= 500)
);

CREATE INDEX ix_qr_customer ON customer_qr_ids(customer_user_id, status);
CREATE INDEX ix_links_customer ON shop_customers(customer_user_id, status, shop_id);
CREATE INDEX ix_links_shop ON shop_customers(shop_id, status, id);
CREATE INDEX ix_entries_ledger_seq ON ledger_entries(shop_customer_id, server_seq);
CREATE INDEX ix_entries_shop_seq ON ledger_entries(shop_id, server_seq);
CREATE INDEX ix_entries_correction_target ON ledger_entries(corrects_entry_id);
CREATE INDEX ix_disputes_ledger_status ON disputes(shop_customer_id, status, created_at_ms);
CREATE INDEX ix_sessions_user ON refresh_sessions(user_id, revoked_at_ms, expires_at_ms);
CREATE INDEX ix_requests_user ON data_requests(requester_user_id, created_at_ms);

CREATE TABLE access_sessions (
  token_hash TEXT NOT NULL PRIMARY KEY CHECK (length(token_hash) = 64),
  refresh_session_id TEXT NOT NULL REFERENCES refresh_sessions(id) ON DELETE RESTRICT,
  created_at_ms INTEGER NOT NULL CHECK (typeof(created_at_ms) = 'integer' AND created_at_ms >= 0),
  expires_at_ms INTEGER NOT NULL CHECK (typeof(expires_at_ms) = 'integer' AND expires_at_ms > created_at_ms)
);
CREATE INDEX ix_access_session ON access_sessions(refresh_session_id, expires_at_ms);

CREATE TRIGGER shop_owner_insert BEFORE INSERT ON shops BEGIN
  SELECT RAISE(ABORT, 'OWNER_REQUIRED') WHERE NOT EXISTS (SELECT 1 FROM users WHERE id=NEW.owner_user_id AND account_role='owner' AND deleted_at_ms IS NULL);
END;
CREATE TRIGGER shop_owner_update BEFORE UPDATE OF owner_user_id ON shops BEGIN
  SELECT RAISE(ABORT, 'OWNER_IMMUTABLE');
END;
CREATE TRIGGER user_role_update BEFORE UPDATE OF account_role,google_sub ON users BEGIN
  SELECT RAISE(ABORT, 'IDENTITY_IMMUTABLE');
END;
CREATE TRIGGER qr_customer_insert BEFORE INSERT ON customer_qr_ids BEGIN
  SELECT RAISE(ABORT, 'CUSTOMER_REQUIRED') WHERE NOT EXISTS (SELECT 1 FROM users WHERE id=NEW.customer_user_id AND account_role='customer' AND deleted_at_ms IS NULL);
END;
CREATE TRIGGER qr_customer_update BEFORE UPDATE OF customer_user_id,public_id ON customer_qr_ids BEGIN
  SELECT RAISE(ABORT, 'QR_IDENTITY_IMMUTABLE');
END;
CREATE TRIGGER link_customer_insert BEFORE INSERT ON shop_customers BEGIN
  SELECT RAISE(ABORT, 'CUSTOMER_REQUIRED') WHERE NOT EXISTS (SELECT 1 FROM users WHERE id=NEW.customer_user_id AND account_role='customer' AND deleted_at_ms IS NULL);
  SELECT RAISE(ABORT, 'SHOP_INACTIVE') WHERE NOT EXISTS (SELECT 1 FROM shops WHERE id=NEW.shop_id AND status='active');
END;
CREATE TRIGGER link_identity_update BEFORE UPDATE OF id,shop_id,customer_user_id ON shop_customers BEGIN
  SELECT RAISE(ABORT, 'LINK_IDENTITY_IMMUTABLE');
END;
CREATE TRIGGER link_account AFTER INSERT ON shop_customers BEGIN
  INSERT INTO ledger_accounts(shop_customer_id,balance_paise,version,updated_at_ms) VALUES (NEW.id,0,0,NEW.linked_at_ms);
END;

CREATE TRIGGER ledger_insert_guard BEFORE INSERT ON ledger_entries BEGIN
  SELECT RAISE(ABORT, 'ENTRY_IMMUTABLE') WHERE EXISTS (SELECT 1 FROM ledger_entries WHERE id=NEW.id OR server_seq=NEW.server_seq OR (shop_id=NEW.shop_id AND client_operation_id=NEW.client_operation_id));
  SELECT RAISE(ABORT, 'OPERATION_EXISTS') WHERE EXISTS (SELECT 1 FROM sync_operations WHERE shop_id=NEW.shop_id AND client_operation_id=NEW.client_operation_id);
  SELECT RAISE(ABORT, 'NOT_AUTHORIZED') WHERE NOT EXISTS (
    SELECT 1 FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id JOIN users c ON c.id=l.customer_user_id
    WHERE l.id=NEW.shop_customer_id AND l.shop_id=NEW.shop_id AND l.customer_user_id=NEW.customer_user_id
      AND l.status='active' AND s.status='active' AND s.owner_user_id=NEW.created_by_user_id AND o.deleted_at_ms IS NULL AND c.deleted_at_ms IS NULL
  );
  SELECT RAISE(ABORT, 'CORRECTION_INVALID') WHERE NEW.kind='correction' AND NOT EXISTS (
    SELECT 1 FROM ledger_entries e JOIN entry_effective f ON f.entry_id=e.id
    WHERE e.id=NEW.corrects_entry_id AND e.shop_customer_id=NEW.shop_customer_id AND e.kind IN ('credit','payment')
      AND f.revision=NEW.expected_revision AND NEW.effect_paise=(CASE e.kind WHEN 'credit' THEN NEW.target_amount_paise ELSE -NEW.target_amount_paise END)-f.effective_paise
  );
  SELECT RAISE(ABORT, 'BALANCE_CONFLICT') WHERE NOT EXISTS (
    SELECT 1 FROM ledger_accounts WHERE shop_customer_id=NEW.shop_customer_id AND version < 9007199254740991
      AND (NEW.effect_paise >= 0 AND balance_paise <= 9007199254740991-NEW.effect_paise OR NEW.effect_paise < 0 AND balance_paise >= -NEW.effect_paise)
  );
END;
CREATE TRIGGER ledger_project AFTER INSERT ON ledger_entries BEGIN
  UPDATE ledger_accounts SET balance_paise=balance_paise+NEW.effect_paise,version=version+1,updated_at_ms=NEW.created_at_ms WHERE shop_customer_id=NEW.shop_customer_id;
  INSERT INTO entry_effective(entry_id,shop_customer_id,effective_paise,revision)
    SELECT NEW.id,NEW.shop_customer_id,NEW.effect_paise,0 WHERE NEW.kind IN ('credit','payment');
  UPDATE entry_effective SET effective_paise=effective_paise+NEW.effect_paise,revision=revision+1
    WHERE entry_id=NEW.corrects_entry_id AND NEW.kind='correction';
END;
CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger_entries BEGIN SELECT RAISE(ABORT, 'ENTRY_IMMUTABLE'); END;
CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger_entries BEGIN SELECT RAISE(ABORT, 'ENTRY_IMMUTABLE'); END;
CREATE TRIGGER effective_guard_insert BEFORE INSERT ON entry_effective BEGIN
  SELECT RAISE(ABORT, 'EFFECTIVE_INVALID') WHERE NOT EXISTS (SELECT 1 FROM ledger_entries WHERE id=NEW.entry_id AND shop_customer_id=NEW.shop_customer_id AND kind IN ('credit','payment') AND effect_paise=NEW.effective_paise AND NEW.revision=0);
END;
CREATE TRIGGER effective_guard_update BEFORE UPDATE ON entry_effective BEGIN
  SELECT RAISE(ABORT, 'EFFECTIVE_INVALID') WHERE NEW.entry_id != OLD.entry_id OR NEW.shop_customer_id != OLD.shop_customer_id OR NOT EXISTS (
    SELECT 1 FROM ledger_entries e JOIN ledger_entries c ON c.corrects_entry_id=e.id
    WHERE e.id=NEW.entry_id AND c.server_seq=(SELECT MAX(server_seq) FROM ledger_entries WHERE shop_customer_id=NEW.shop_customer_id)
      AND c.expected_revision=OLD.revision AND NEW.revision=OLD.revision+1 AND NEW.effective_paise=OLD.effective_paise+c.effect_paise
  );
END;
CREATE TRIGGER receipt_guard BEFORE INSERT ON sync_operations BEGIN
  SELECT RAISE(ABORT, 'RECEIPT_IMMUTABLE') WHERE EXISTS (SELECT 1 FROM sync_operations WHERE shop_id=NEW.shop_id AND client_operation_id=NEW.client_operation_id);
  SELECT RAISE(ABORT, 'RECEIPT_INVALID') WHERE length(NEW.request_hash)!=64 OR NEW.request_hash GLOB '*[^0-9a-f]*';
  SELECT RAISE(ABORT, 'RECEIPT_INVALID') WHERE NEW.operation_kind='entry' AND NOT EXISTS (
    SELECT 1 FROM ledger_entries e JOIN ledger_accounts a ON a.shop_customer_id=e.shop_customer_id
    WHERE e.id=NEW.entry_id AND e.shop_id=NEW.shop_id AND e.client_operation_id=NEW.client_operation_id
      AND a.version=NEW.response_version AND a.balance_paise=NEW.response_balance_paise
  );
  SELECT RAISE(ABORT, 'RECEIPT_INVALID') WHERE NEW.operation_kind='link' AND NOT EXISTS (SELECT 1 FROM shop_customers WHERE id=NEW.shop_customer_id AND shop_id=NEW.shop_id);
END;
CREATE TRIGGER receipt_no_update BEFORE UPDATE ON sync_operations BEGIN SELECT RAISE(ABORT, 'RECEIPT_IMMUTABLE'); END;
CREATE TRIGGER receipt_no_delete BEFORE DELETE ON sync_operations BEGIN SELECT RAISE(ABORT, 'RECEIPT_IMMUTABLE'); END;
CREATE TRIGGER dispute_guard_insert BEFORE INSERT ON disputes BEGIN
  SELECT RAISE(ABORT, 'DISPUTE_SCOPE') WHERE NOT EXISTS (SELECT 1 FROM ledger_entries WHERE id=NEW.entry_id AND shop_customer_id=NEW.shop_customer_id AND customer_user_id=NEW.customer_user_id);
END;
CREATE TRIGGER dispute_guard_update BEFORE UPDATE ON disputes BEGIN
  SELECT RAISE(ABORT, 'DISPUTE_SCOPE') WHERE NEW.entry_id!=OLD.entry_id OR NEW.shop_customer_id!=OLD.shop_customer_id OR NEW.customer_user_id!=OLD.customer_user_id;
  SELECT RAISE(ABORT, 'NOT_AUTHORIZED') WHERE NEW.status='resolved' AND NOT EXISTS (SELECT 1 FROM shop_customers l JOIN shops s ON s.id=l.shop_id WHERE l.id=NEW.shop_customer_id AND s.owner_user_id=NEW.resolved_by_user_id);
END;
