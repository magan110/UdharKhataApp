import type { Authenticator, Principal } from '../../src/auth/authenticator';

export const syntheticOwner: Principal = { userId: 'usr_owner_a', role: 'owner' };
export const syntheticCustomer: Principal = { userId: 'usr_customer_a', role: 'customer' };

export function syntheticAuthenticator(role: Principal['role']): Authenticator {
  return async () => role === 'owner' ? syntheticOwner : syntheticCustomer;
}
