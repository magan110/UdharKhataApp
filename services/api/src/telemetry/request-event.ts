import {redactRequestEvent} from './redaction';
export interface RequestEvent {
  requestId: string;
  route: string;
  status: number;
  errorCode: string | null;
  durationMs: number;
}

export type RequestLogger = (event: RequestEvent) => void;
export const logRequest: RequestLogger = (event) => console.info(JSON.stringify(redactRequestEvent(event)));
