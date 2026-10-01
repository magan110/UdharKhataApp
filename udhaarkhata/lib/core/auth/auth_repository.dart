import 'account.dart';
import 'session_store.dart';
import '../db/database.dart';
import '../network/api_client.dart';
import '../network/app_failure.dart';
import '../network/contracts.dart';

abstract class AuthRepository {
  Future<Account?> restoreSession();
  bool get canSignIn => false;
  Future<Account> signIn(AccountRole role) =>
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
  Future<int> pendingCount() async => 0;
  Future<({int pendingCount, bool remoteRevoked})> signOut() =>
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
}

// D04 replaces this adapter with Google identity and server-verified sessions.
final class UnconfiguredAuthRepository extends AuthRepository {
  @override
  Future<Account?> restoreSession() async => null;
}

final class GoogleAuthRepository extends AuthRepository {
  GoogleAuthRepository({
    required this.api,
    required this.baseUrl,
    required this.store,
    required this.database,
    required this.googleToken,
  });
  final ApiClient api;
  final Uri baseUrl;
  final SessionStore store;
  final SqliteAccountDatabase database;
  final Future<String> Function() googleToken;
  Account? _account;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final future = _queue.then((_) => action());
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  @override
  bool get canSignIn => true;
  Uri _url(String path) => baseUrl.resolve(path);
  String _token(Object? value) {
    final token = jsonString(value);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw const FormatException('Invalid credential');
    }
    return token;
  }

  Map<String, Object?> _credentials(Map<String, Object?> data) => {
    'accessToken': _token(data['accessToken']),
    'refreshToken': _token(data['refreshToken']),
    'accessExpiresAtMs': timestampMs(data['accessExpiresAtMs']),
  };
  Future<Account> _open(Object? value) async {
    final account = Account.fromJson(value);
    await database.openForAccount(account.id);
    await database.verifyAccount(
      account.id,
      account.role,
      DateTime.now().millisecondsSinceEpoch,
    );
    _account = account;
    return account;
  }

  @override
  Future<Account?> restoreSession() => _serial(() async {
    await database.lock();
    _account = null;
    final old = await store.read();
    if (old == null) return null;
    Map<String, Object?> next;
    try {
      final result = await api.post(_url('/v1/auth/refresh'), {
        'refreshToken': _token(old['refreshToken']),
        'deviceId': await store.deviceId(),
      });
      next = _credentials(jsonObject(result));
      await store.save(next);
    } catch (error) {
      await store.clear();
      if (error is AppFailure && error.code == 'AUTH_REQUIRED') return null;
      rethrow;
    }
    final profile = await api.get(
      _url('/v1/me'),
      jsonObject,
      accessToken: _token(next['accessToken']),
    );
    return _open(profile.data['account']);
  });
  @override
  Future<Account> signIn(AccountRole role) => _serial(() async {
    await database.lock();
    _account = null;
    final result = jsonObject(
      await api.post(_url('/v1/auth/google'), {
        'idToken': await googleToken(),
        'requestedRole': role.name,
        'deviceId': await store.deviceId(),
      }),
    );
    final credentials = _credentials(result);
    final account = Account.fromJson(result['account']);
    await store.save(credentials);
    return _open({
      'id': account.id.value,
      'role': account.role.name,
      'displayName': account.displayName,
      'createdAtMs': account.createdAtMs,
      'email': account.email,
    });
  });
  @override
  Future<int> pendingCount() async {
    final account = _account;
    if (account == null) return 0;
    return database.transaction(account.id, (tx) async {
      final rows = await tx.rawQuery('SELECT COUNT(*) AS count FROM outbox');
      return rows.single['count'] as int;
    });
  }

  @override
  Future<({int pendingCount, bool remoteRevoked})> signOut() =>
      _serial(() async {
        final count = await pendingCount();
        var revoked = false;
        try {
          var credentials = await store.read();
          if (credentials != null) {
            final device = await store.deviceId();
            if (timestampMs(credentials['accessExpiresAtMs']) <=
                DateTime.now().millisecondsSinceEpoch) {
              credentials = _credentials(
                jsonObject(
                  await api.post(_url('/v1/auth/refresh'), {
                    'refreshToken': _token(credentials['refreshToken']),
                    'deviceId': device,
                  }),
                ),
              );
            }
            await api.post(_url('/v1/auth/logout'), {
              'deviceId': device,
            }, accessToken: _token(credentials['accessToken']));
            revoked = true;
          }
        } on AppFailure {
          /* Offline sign-out still locks the local account. UI reports unconfirmed revocation. */
        } finally {
          await database.lock();
          _account = null;
          await store.clear();
        }
        return (pendingCount: count, remoteRevoked: revoked);
      });
}
