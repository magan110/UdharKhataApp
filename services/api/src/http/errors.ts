export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly messageKey: string,
    readonly retryable = false,
    readonly headers: Record<string, string> = {},
    readonly details?: {balance:{balancePaise:number;ledgerVersion:number;asOfServerSeq:number;asOfAtMs:number}},
  ) {
    super(code);
  }
}

export function jsonResponse(data: unknown, requestId: string, status = 200): Response {
  return Response.json({ data, requestId }, { status, headers: responseHeaders(requestId) });
}

export function errorResponse(error: HttpError, requestId: string): Response {
  return Response.json({
    error: { code: error.code, messageKey: error.messageKey, retryable: error.retryable, ...(error.details?{details:error.details}:{}) },
    requestId,
  }, { status: error.status, headers: { ...responseHeaders(requestId), ...error.headers } });
}

function responseHeaders(requestId: string): Record<string, string> {
  return {
    'X-Request-Id': requestId,
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8',
  };
}
