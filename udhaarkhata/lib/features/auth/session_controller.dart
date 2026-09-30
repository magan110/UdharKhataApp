import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import '../../core/auth/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => UnconfiguredAuthRepository(),
);
final sessionProvider = AsyncNotifierProvider<SessionController, Account?>(
  SessionController.new,
  retry: (_, _) => null,
);

final class SessionController extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() =>
      ref.watch(authRepositoryProvider).restoreSession();
}
