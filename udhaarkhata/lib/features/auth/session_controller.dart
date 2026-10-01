import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/google_auth.dart';
import '../../core/auth/session_store.dart';
import '../../core/db/database.dart';
import '../../core/network/api_client.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  const url = String.fromEnvironment('API_BASE_URL');
  if (url.isEmpty || googleServerClientId.isEmpty) {
    return UnconfiguredAuthRepository();
  }
  final client = http.Client();
  final database = SqliteAccountDatabase();
  ref.onDispose(() {
    client.close();
    database.lock();
  });
  return GoogleAuthRepository(
    api: ApiClient(client),
    baseUrl: Uri.parse(url),
    store: SessionStore(
      const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false)),
    ),
    database: database,
    googleToken: googleIdToken,
  );
});
final sessionProvider = AsyncNotifierProvider<SessionController, Account?>(
  SessionController.new,
  retry: (_, _) => null,
);

final class SessionController extends AsyncNotifier<Account?> {
  bool _refreshScheduled = false;
  bool _signingOut = false;
  int _revision = 0;

  // Several screens can observe the same expired session. Never rebuild while
  // delivering their provider updates or after signout/account replacement.
  void refreshAfterAuthFailure() {
    final account = state.asData?.value;
    if (account == null || _signingOut || _refreshScheduled) return;
    final revision = _revision;
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!ref.mounted ||
          _signingOut ||
          revision != _revision ||
          state.asData?.value?.id.value != account.id.value) {
        return;
      }
      ref.invalidateSelf();
    });
  }

  @override
  Future<Account?> build() =>
      ref.watch(authRepositoryProvider).restoreSession();

  Future<void> signIn(AccountRole role) async {
    _revision++;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(role),
    );
  }

  Future<({int pendingCount, bool remoteRevoked})> signOut() async {
    _revision++;
    _signingOut = true;
    try {
      final result = await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
      return result;
    } finally {
      _signingOut = false;
    }
  }
}
