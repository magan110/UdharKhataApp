import { createRemoteJWKSet, jwtVerify, errors, type JWTVerifyGetKey } from 'jose';
import { HttpError } from '../http/errors';

const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'), {
  timeoutDuration: 5000, cooldownDuration: 30000, cacheMaxAge: 3600000,
});
export interface GoogleIdentity { sub: string; name?: string; email?: string }

export async function verifyGoogleToken(token: string, audience: string, keys: JWTVerifyGetKey = googleKeys): Promise<GoogleIdentity> {
  if (!audience) throw new HttpError(503, 'FEATURE_UNAVAILABLE', 'api.featureUnavailable', true);
  try {
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ['RS256'], issuer: ['accounts.google.com','https://accounts.google.com'], audience,
      requiredClaims: ['sub','exp','iat'], maxTokenAge: '2h',
    });
    if (!payload.sub || payload.sub.length > 255) throw new Error('Invalid subject');
    return { sub: payload.sub,
      name: typeof payload.name === 'string' ? payload.name.slice(0,120) : undefined,
      email: payload.email_verified === true && typeof payload.email === 'string' ? payload.email.slice(0,320) : undefined };
  } catch (error) {
    if (error instanceof errors.JWKSTimeout || (error instanceof TypeError)) {
      throw new HttpError(503,'CAPACITY_UNAVAILABLE','api.networkError',true);
    }
    throw new HttpError(401,'IDENTITY_INVALID','auth.identityInvalid');
  }
}
