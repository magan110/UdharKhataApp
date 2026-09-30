import { z } from 'zod';
import { HttpError } from './errors';

export const idSchema = z.string().regex(/^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/);
export const moneyPaiseSchema = z.number().int().min(-Number.MAX_SAFE_INTEGER).max(Number.MAX_SAFE_INTEGER);
export const timestampMsSchema = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
export const cursorSchema = z.string().min(1).max(2048).regex(/^[A-Za-z0-9_-]+$/);
export const accountSchema = z.object({
  id: idSchema,
  role: z.enum(['owner', 'customer']),
  displayName: z.string().min(1),
  email: z.string().min(1).optional(),
  createdAtMs: timestampMsSchema,
}).strict();
export type Account = z.infer<typeof accountSchema>;

export const pageSchema = z.object({
  nextCursor: cursorSchema.nullable(), hasMore: z.boolean(),
}).refine((page) => !page.hasMore || page.nextCursor !== null);
export const successEnvelopeSchema = z.object({
  data: z.unknown(), requestId: idSchema, page: pageSchema.optional(),
}).refine((response) => Object.prototype.hasOwnProperty.call(response, 'data'));
export const errorEnvelopeSchema = z.object({
  error: z.object({
    code: z.string().min(1), messageKey: z.string().min(1), retryable: z.boolean(),
    details: z.record(z.string(), z.unknown()).optional(),
  }), requestId: idSchema,
});

export const googleExchangeSchema = z.object({
  idToken: z.string().min(1).max(16384),
  requestedRole: z.enum(['owner', 'customer']),
}).strict();

export const MAX_JSON_BODY_BYTES = 65536;

export async function readJson(request: Request, schema: z.ZodType): Promise<unknown> {
  const contentType = request.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase();
  const encoding = request.headers.get('Content-Encoding');
  if (contentType !== 'application/json' || (encoding && encoding !== 'identity')) {
    throw new HttpError(415, 'UNSUPPORTED_MEDIA_TYPE', 'api.jsonRequired');
  }
  const declaredLength = request.headers.get('Content-Length');
  if (declaredLength !== null && (!/^\d+$/.test(declaredLength) || Number(declaredLength) > MAX_JSON_BODY_BYTES)) {
    throw new HttpError(413, 'PAYLOAD_TOO_LARGE', 'api.payloadTooLarge');
  }
  if (!request.body) throw new HttpError(400, 'INVALID_JSON', 'api.invalidJson');

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_JSON_BODY_BYTES) {
        await reader.cancel();
        throw new HttpError(413, 'PAYLOAD_TOO_LARGE', 'api.payloadTooLarge');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const body = new Uint8Array(bytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(body));
  } catch {
    throw new HttpError(400, 'INVALID_JSON', 'api.invalidJson');
  }
  const result = schema.safeParse(parsed);
  if (!result.success) throw new HttpError(400, 'VALIDATION_ERROR', 'api.validationError');
  return result.data;
}
