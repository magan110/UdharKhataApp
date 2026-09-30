import 'account.dart';

abstract interface class AuthRepository {
  Future<Account?> restoreSession();
}

// D04 replaces this adapter with Google identity and server-verified sessions.
final class UnconfiguredAuthRepository implements AuthRepository {
  @override
  Future<Account?> restoreSession() async => null;
}
