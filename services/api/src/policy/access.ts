import type { Principal } from '../auth/authenticator';
import { HttpError } from '../http/errors';

export function requirePrincipal(principal: Principal | null): Principal {
  if (!principal) throw new HttpError(401, 'AUTH_REQUIRED', 'auth.required');
  return principal;
}

export function requireRole(principal: Principal | null, role: Principal['role']): Principal {
  const authenticated = requirePrincipal(principal);
  if (authenticated.role !== role) throw new HttpError(403, 'FORBIDDEN', 'auth.forbidden');
  return authenticated;
}
