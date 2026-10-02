// D08 pilot contract v1: INR integer paise, bounded credit/payment commands including aged offline outbox entries.
export const CREDIT_LIMITS = { maxAmountPaise: 10_000_000, maxNoteCharacters: 500, maxBodyBytes: 4096, maxPageSize: 100, maxFutureSkewMs: 300_000 } as const;
