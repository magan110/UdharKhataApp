import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: './wrangler.jsonc' } })],
  test: {
    include: ['test/**/*.test.ts'],
    coverage: {
      provider: 'istanbul',
      include: ['src/**/*.ts'],
      reporter: ['text', 'lcov'],
      thresholds: { lines: 80, statements: 80, functions: 80, branches: 80 },
    },
  },
});
