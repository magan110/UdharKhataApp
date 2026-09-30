export interface Principal {
  readonly userId: string;
  readonly role: 'owner' | 'customer';
}

export type Authenticator = (request: Request) => Promise<Principal | null>;

// D04 will supply verified app-session authentication. Until then, fail closed.
export const unavailableAuthenticator: Authenticator = async () => null;
