// D08 pilot contract v1: INR integer paise, bounded online credit commands.
export const CREDIT_LIMITS = { maxAmountPaise: 10_000_000, maxNoteCharacters: 500, maxBodyBytes: 4096, maxPageSize: 100, maxClockSkewMs: 86_400_000, maxFutureSkewMs: 300_000 } as const;
