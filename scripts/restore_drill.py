"""Synthetic encrypted backup/isolated restore rehearsal. Never reads remote/real data."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import sqlite3
import tempfile
import time
import uuid
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.exceptions import InvalidTag

ROOT = Path(__file__).resolve().parents[1]

def rows(db, table):
    return db.execute(f'SELECT * FROM {table} ORDER BY 1').fetchall()

def drill():
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='uk-synthetic-restore-') as directory:
        private = Path(directory)
        os.chmod(private, 0o700)
        db = sqlite3.connect(private / 'source.db')
        db.execute('PRAGMA foreign_keys=ON')
        migrations = sorted((ROOT / 'services/api/migrations').glob('*.sql'))
        for migration in migrations:
            db.executescript(migration.read_text())
        db.executescript("""
          INSERT INTO users VALUES ('owner','synthetic-owner','owner','Synthetic shop',NULL,1,NULL);
          INSERT INTO users VALUES ('customer','synthetic-customer','customer','Synthetic customer',NULL,1,NULL);
          INSERT INTO shops VALUES ('shop','owner','Synthetic shop','active',1,NULL);
          INSERT INTO shop_customers VALUES ('link','shop','customer',NULL,'active',1,NULL);
        """)
        commands = [('credit',50000,50000,None,None,None),
                    ('payment',10000,-10000,None,None,None),
                    ('correction',None,-5000,45000,'entry-0',0)]
        identities = []
        for index, (kind, amount, effect, target, corrects, revision) in enumerate(commands):
            operation = str(uuid.uuid4())
            identity = f'entry-{index}'
            payload = json.dumps([kind, amount, target, corrects, revision], separators=(',', ':'))
            digest = hashlib.sha256(payload.encode()).hexdigest()
            db.execute('''INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,
              target_amount_paise,effect_paise,payment_method,due_date,corrects_entry_id,expected_revision,
              correction_reason,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms)
              VALUES (?, 'link','shop','customer',?,?,?,?,?,?,?,?,?,'owner',?,?,?)''',
              (identity,kind,amount,target,effect,'cash' if kind=='payment' else None,
               '2026-10-01' if kind=='credit' else None,corrects,revision,
               'Synthetic correction' if kind=='correction' else None,operation,index+2,index+2))
            balance, version = db.execute("SELECT balance_paise,version FROM ledger_accounts WHERE shop_customer_id='link'").fetchone()
            db.execute("INSERT INTO sync_operations(shop_id,client_operation_id,operation_kind,request_hash,entry_id,response_version,response_balance_paise,created_at_ms) VALUES ('shop',?,'entry',?,?,?,?,?)",
                       (operation,digest,identity,version,balance,index+2))
            identities.append((operation,digest,identity))
        db.commit()
        tables = ['users','shops','shop_customers','ledger_accounts','ledger_entries','entry_effective','sync_operations']
        baseline = {table: rows(db,table) for table in tables}
        snapshot = sqlite3.connect(private / 'backup.db')
        db.backup(snapshot)
        snapshot.close()
        key, nonce = AESGCM.generate_key(bit_length=256), os.urandom(12)
        ciphertext = AESGCM(key).encrypt(nonce,(private/'backup.db').read_bytes(),b'udhaarkhata-synthetic-v1')
        # Only ciphertext is a backup artifact. Ephemeral key stays separate and is never logged.
        (private/'backup.aesgcm').write_bytes(nonce+ciphertext)
        (private/'backup.db').unlink()
        try:
            AESGCM(key).decrypt(nonce,ciphertext[:-1]+bytes([ciphertext[-1]^1]),b'udhaarkhata-synthetic-v1')
            raise AssertionError('Tamper accepted')
        except InvalidTag:
            pass
        (private/'restore.db').write_bytes(AESGCM(key).decrypt(nonce,ciphertext,b'udhaarkhata-synthetic-v1'))
        restored = sqlite3.connect(private/'restore.db')
        restored.execute('PRAGMA foreign_keys=ON')
        assert restored.execute('PRAGMA integrity_check').fetchone() == ('ok',)
        assert restored.execute('PRAGMA foreign_key_check').fetchall() == []
        for table in tables:
            assert rows(restored,table) == baseline[table], table
        assert restored.execute("SELECT SUM(effect_paise) FROM ledger_entries WHERE shop_customer_id='link'").fetchone()[0] == 35000
        assert restored.execute("SELECT balance_paise FROM ledger_accounts WHERE shop_customer_id='link'").fetchone()[0] == 35000
        for operation, digest, identity in identities:
            # Replay recognizes the same immutable receipt; no new financial effect.
            assert restored.execute("SELECT request_hash,entry_id FROM sync_operations WHERE shop_id='shop' AND client_operation_id=?",(operation,)).fetchone() == (digest,identity)
        assert restored.execute('SELECT COUNT(*) FROM ledger_entries').fetchone()[0] == 3
        db.close()
        restored.close()
        return {'syntheticOnly':True,'migrations':[p.name for p in migrations],
                'checks':['AES-256-GCM roundtrip','tamper rejection','integrity','foreign keys','identities','operation receipts','entry sums','projection reconciliation','receipt replay'],
                'entryCount':3,'elapsedSeconds':round(time.monotonic()-started,3),'productionBackupConfigured':False}

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path)
    arguments=parser.parse_args()
    result=drill()
    rendered=json.dumps(result,indent=2)+'\n'
    if arguments.output:
        arguments.output.write_text(rendered)
    print(rendered,end='')
