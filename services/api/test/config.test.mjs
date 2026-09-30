import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { URL } from 'node:url';
import test from 'node:test';

test('D01 Worker configuration cannot target a remote database or deploy by default', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8'));
  assert.equal(config.workers_dev, false);
  assert.equal(config.main, 'src/index.ts');
  assert.equal(config.d1_databases, undefined);
  assert.equal(config.routes, undefined);
  assert.equal(config.route, undefined);
});
