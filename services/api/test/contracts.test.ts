import { describe, expect, it } from 'vitest';
import fixtures from '../../../contracts/d02-fixtures.json';
import { accountSchema, cursorSchema, errorEnvelopeSchema, idSchema, moneyPaiseSchema, pageSchema, successEnvelopeSchema, timestampMsSchema } from '../src/http/schemas';
import { requirePrincipal, requireRole } from '../src/policy/access';
import { syntheticCustomer, syntheticOwner } from './helpers/auth';

describe('cross-language contracts', () => {
  it('accepts the shared ID, paise, timestamp, cursor, and account fixture', () => {
    expect(idSchema.parse(fixtures.valid.id)).toBe(fixtures.valid.id);
    expect(moneyPaiseSchema.parse(fixtures.valid.moneyPaise)).toBe(50000);
    expect(timestampMsSchema.parse(fixtures.valid.timestampMs)).toBe(fixtures.valid.timestampMs);
    expect(cursorSchema.parse(fixtures.valid.cursor)).toBe(fixtures.valid.cursor);
    expect(accountSchema.parse(fixtures.account)).toEqual(fixtures.account);
  });
  it('rejects the same malformed primitive fixtures as Dart', () => {
    for (const value of fixtures.invalidMoney) expect(moneyPaiseSchema.safeParse(value).success).toBe(false);
    for (const value of fixtures.invalidIds) expect(idSchema.safeParse(value).success).toBe(false);
    for (const value of fixtures.invalidTimestamps) expect(timestampMsSchema.safeParse(value).success).toBe(false);
    for (const value of fixtures.invalidCursors) expect(cursorSchema.safeParse(value).success).toBe(false);
  });
  it('accepts safe signed effects but rejects overflow and oversized identifiers', () => {
    expect(moneyPaiseSchema.parse(-50000)).toBe(-50000);
    expect(moneyPaiseSchema.parse(Number.MAX_SAFE_INTEGER)).toBe(Number.MAX_SAFE_INTEGER);
    expect(idSchema.safeParse('x'.repeat(129)).success).toBe(false);
    expect(cursorSchema.safeParse('x'.repeat(2049)).success).toBe(false);
    expect(accountSchema.safeParse({ ...fixtures.account, role: 'admin' }).success).toBe(false);
  });
  it('checks success, paging, and error fixtures as well as invalid paging', () => {
    expect(successEnvelopeSchema.parse(fixtures.success)).toEqual(fixtures.success);
    expect(successEnvelopeSchema.parse(fixtures.page)).toEqual(fixtures.page);
    expect(errorEnvelopeSchema.parse(fixtures.error)).toEqual(fixtures.error);
    expect(pageSchema.safeParse({ nextCursor: null, hasMore: true }).success).toBe(false);
    expect(pageSchema.parse({ nextCursor: fixtures.valid.cursor, hasMore: true }).hasMore).toBe(true);
    expect(successEnvelopeSchema.safeParse({ requestId: 'req_test' }).success).toBe(false);
  });
});

describe('fail-closed role boundary', () => {
  it('rejects missing principals and mismatched roles', () => {
    expect(() => requirePrincipal(null)).toThrow('AUTH_REQUIRED');
    expect(() => requireRole(null, 'owner')).toThrow('AUTH_REQUIRED');
    expect(() => requireRole(syntheticCustomer, 'owner')).toThrow('FORBIDDEN');
    expect(() => requireRole(syntheticOwner, 'customer')).toThrow('FORBIDDEN');
  });
  it('returns verified matching principals', () => {
    expect(requireRole(syntheticOwner, 'owner')).toBe(syntheticOwner);
    expect(requireRole(syntheticCustomer, 'customer')).toBe(syntheticCustomer);
  });
});
