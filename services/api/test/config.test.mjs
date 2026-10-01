import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { URL } from 'node:url';
import test from 'node:test';

test('D01 Worker configuration cannot target a remote database or deploy by default', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8'));
  assert.equal(config.workers_dev, false);
  assert.equal(config.main, 'src/index.ts');
  assert.equal(config.d1_databases.length, 1);
  assert.equal(config.d1_databases[0].remote, false);
  assert.equal(config.d1_databases[0].database_id, '00000000-0000-0000-0000-000000000000');
  assert.equal(config.routes, undefined);
  assert.equal(config.route, undefined);
});
