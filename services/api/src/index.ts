import { createApp } from './http/router';
import { SessionService } from './auth/sessions';
import { verifyGoogleToken } from './auth/google';

interface Environment { DB:D1Database; GOOGLE_CLIENT_ID?:string }
export default {
  fetch(request:Request,env?:Environment):Promise<Response> {
    return createApp(env?.DB?{sessions:new SessionService(env.DB),verifyGoogle:token=>verifyGoogleToken(token,env.GOOGLE_CLIENT_ID??'')} : {}).fetch(request);
  },
} satisfies ExportedHandler<Environment>;
