import 'account.dart';
import 'session_store.dart';
import 'local_access_grant.dart';
import '../db/database.dart';
import '../network/api_client.dart';
import '../network/app_failure.dart';
import '../network/contracts.dart';
import '../network/error_classifier.dart';

abstract class AuthRepository {
  Future<Account?> restoreSession();
  bool get canSignIn => false;
  bool get offlineAccess => false;
  int get sessionGeneration => 0;
  Future<Account> signIn(AccountRole role) =>
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
  Future<int> pendingCount() async => 0;
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) => throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
  Future<({int pendingCount, bool remoteRevoked})> signOut() =>
      throw const AppFailure('FEATURE_UNAVAILABLE', 'api.featureUnavailable');
}

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
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final ApiClient api;
  final Uri baseUrl;
  final SessionStore store;
  final SqliteAccountDatabase database;
  final Future<String> Function() googleToken;
  final DateTime Function() clock;
  Account? _account;
  bool _offlineAccess = false;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final future = _queue.then((_) => action());
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  @override
  bool get canSignIn => true;
  @override
  bool get offlineAccess => _offlineAccess;
  @override
  int get sessionGeneration => database.generation;
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
  Future<void> _expireCredentials() async {
    await database.lock();
    _account = null;
    _offlineAccess = false;
    await store.clear();
    await store.clearLocalGrant();
  }

  Future<Map<String, Object?>> _refresh(Map<String, Object?> old) async {
    final result = await api.post(_url('/v1/auth/refresh'), {
      'refreshToken': _token(old['refreshToken']),
      'deviceId': await store.deviceId(),
    });
    final next = _credentials(jsonObject(result));
    await store.save(next);
    return next;
  }

  Future<Account> _open(Object? value) async {
    final account = Account.fromJson(value);
    await database.openForAccount(account.id);
    final now = clock().millisecondsSinceEpoch;
    await database.verifyAccount(account.id, account.role, now);
    final grant = LocalAccessGrant(
      account,
      now,
      now + const Duration(days: 30).inMilliseconds,
    );
    try {
      await store.saveLocalGrant(grant);
    } catch (_) {
      await database.lock();
      rethrow;
    }
    database.requireLocalAccess(
      DateTime.fromMillisecondsSinceEpoch(grant.expiresAtMs),
      clock,
    );
    _account = account;
    _offlineAccess = false;
    return account;
  }

  Future<Account> _offline(AppFailure failure) async {
    if (classifySyncFailure(failure) != SyncFailureKind.transient) {
      throw failure;
    }
    final grant = await store.readLocalGrant();
    if (grant == null || !grant.validAt(clock())) throw failure;
    try {
      await database.openExistingForAccount(
        grant.account.id,
        grant.account.role,
      );
    } on StateError {
      throw failure;
    }
    database.requireLocalAccess(
      DateTime.fromMillisecondsSinceEpoch(grant.expiresAtMs),
      clock,
    );
    _account = grant.account;
    _offlineAccess = true;
    return grant.account;
  }

  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) {
    final generation = database.generation;
    return _serial(() async {
      void guard() {
        if (_account?.id.value != accountId.value ||
            generation != database.generation) {
          throw const AppFailure('AUTH_REQUIRED', 'auth.required');
        }
      }

      guard();
      var credentials = await store.read();
      if (credentials == null) {
        await _expireCredentials();
        throw const AppFailure('AUTH_REQUIRED', 'auth.required');
      }
      if (timestampMs(credentials['accessExpiresAtMs']) <=
          clock().millisecondsSinceEpoch) {
        try {
          await api.get(_url('/health'), jsonObject);
        } on AppFailure {
          final grant = await store.readLocalGrant();
          if (grant == null || !grant.validAt(clock())) {
            await _expireCredentials();
          }
          rethrow;
        }
        guard();
        try {
          credentials = await _refresh(credentials);
        } catch (_) {
          await _expireCredentials();
          throw const AppFailure('AUTH_REQUIRED', 'auth.required');
        }
      }
      guard();
      try {
        final Object? result;
        if (body != null) {
          result = await api.post(
            _url(path),
            body,
            accessToken: _token(credentials['accessToken']),
          );
        } else {
          result = (await api.get(
            _url(path),
            (data) => data,
            accessToken: _token(credentials['accessToken']),
          )).data;
        }
        guard();
        _offlineAccess = false;
        return result;
      } on AppFailure catch (failure) {
        if (failure.code == 'AUTH_REQUIRED' &&
            generation == database.generation) {
          await _expireCredentials();
        }
        rethrow;
      }
    });
  }

  @override
  Future<Account?> restoreSession() {
    database.invalidateGeneration();
    return _serial(() async {
      await database.lock();
      _account = null;
      _offlineAccess = false;
      var credentials = await store.read();
      if (credentials == null) return null;
      if (timestampMs(credentials['accessExpiresAtMs']) <=
          clock().millisecondsSinceEpoch) {
        try {
          await api.get(_url('/health'), jsonObject);
        } on AppFailure catch (failure) {
          return _offline(failure);
        }
        try {
          credentials = await _refresh(credentials);
        } catch (error) {
          await _expireCredentials();
          if (error is AppFailure && error.code == 'AUTH_REQUIRED') return null;
          rethrow;
        }
      }
      try {
        final profile = await api.get(
          _url('/v1/me'),
          jsonObject,
          accessToken: _token(credentials['accessToken']),
        );
        return await _open(profile.data['account']);
      } on AppFailure catch (failure) {
        if (failure.code == 'AUTH_REQUIRED') {
          await _expireCredentials();
          return null;
        }
        return _offline(failure);
      }
    });
  }

  @override
  Future<Account> signIn(AccountRole role) {
    database.invalidateGeneration();
    return _serial(() async {
      await database.lock();
      _account = null;
      _offlineAccess = false;
      await store.clearLocalGrant();
      await store.clear();
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
  }

  @override
  Future<int> pendingCount() async {
    final account = _account;
    if (account == null) return 0;
    return database.transaction(
      account.id,
      (tx) async =>
          (await tx.rawQuery('SELECT COUNT(*) AS count FROM outbox'))
                  .single['count']
              as int,
    );
  }

  @override
  Future<({int pendingCount, bool remoteRevoked})> signOut() {
    database.invalidateGeneration();
    return _serial(() async {
      var count = 0;
      try {
        count = await pendingCount();
      } on StateError {
        /* Expired local access. */
      }
      await database.lock();
      _account = null;
      _offlineAccess = false;
      var revoked = false;
      try {
        var credentials = await store.read();
        if (credentials != null) {
          final device = await store.deviceId();
          if (timestampMs(credentials['accessExpiresAtMs']) <=
              clock().millisecondsSinceEpoch) {
            await api.get(_url('/health'), jsonObject);
            credentials = await _refresh(credentials);
          }
          await api.post(_url('/v1/auth/logout'), {
            'deviceId': device,
          }, accessToken: _token(credentials['accessToken']));
          revoked = true;
        }
      } on AppFailure {
        /* Offline local sign-out still succeeds. */
      } finally {
        await store.clear();
        await store.clearLocalGrant();
      }
      return (pendingCount: count, remoteRevoked: revoked);
    });
  }
}
