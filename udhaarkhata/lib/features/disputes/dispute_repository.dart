import '../../core/network/cache_revocation.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/auth/account.dart';
import '../../core/db/database.dart';
import '../../core/network/contracts.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';

enum DisputeStatus { open, resolved }

class Dispute {
  Dispute(Object? value) {
    final row = jsonObject(value);
    id = OpaqueId.fromJson(row['id']).value;
    shopId = OpaqueId.fromJson(row['shopId']).value;
    entryId = OpaqueId.fromJson(row['entryId']).value;
    customerUserId = OpaqueId.fromJson(row['customerUserId']).value;
    reason = jsonString(row['reason']);
    if (!['open', 'resolved'].contains(row['status']) ||
        reason.trim().isEmpty ||
        reason.length > 500) {
      throw const FormatException('Invalid dispute');
    }
    status = row['status'] == 'open'
        ? DisputeStatus.open
        : DisputeStatus.resolved;
    createdAtMs = timestampMs(row['createdAtMs']);
    resolutionNote = row['resolutionNote'] == null
        ? null
        : jsonString(row['resolutionNote']);
    resolvedAtMs = row['resolvedAtMs'] == null
        ? null
        : timestampMs(row['resolvedAtMs']);
    if ((status == DisputeStatus.resolved) !=
            (resolvedAtMs != null && resolutionNote != null) ||
        (resolutionNote?.length ?? 0) > 500) {
      throw const FormatException('Invalid resolution');
    }
  }
  late final String id, shopId, entryId, customerUserId, reason;
  late final DisputeStatus status;
  late final String? resolutionNote;
  late final int createdAtMs;
  late final int? resolvedAtMs;
}

class DisputeSnapshot {
  const DisputeSnapshot(this.items, this.offline);
  final List<Dispute> items;
  final bool offline;
}

abstract interface class DisputeRepository {
  Future<DisputeStatus?> statusForEntry(OpaqueId entryId);
}

final disputeRepositoryProvider = Provider<CloudDisputeRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null
      ? null
      : CloudDisputeRepository(
          ref.watch(authRepositoryProvider),
          account.id,
          role: account.role,
        );
});

class CloudDisputeRepository implements DisputeRepository {
  CloudDisputeRepository(
    this.auth,
    this.accountId, {
    this.role = AccountRole.customer,
    FlutterSecureStorage? storage,
    SqliteAccountDatabase? cacheDatabase,
  }) : storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: false),
           ),
       cacheDatabase =
           cacheDatabase ??
           (auth is GoogleAuthRepository ? auth.database : null),
       _authGeneration = auth.sessionGeneration,
       _databaseGeneration =
           (cacheDatabase ??
                   (auth is GoogleAuthRepository ? auth.database : null))
               ?.generation {
    revocation = CacheRevocation.forAccount(auth, accountId.value);
    revocation.register(() => clearCache());
  }
  late final CacheRevocation revocation;
  final AuthRepository auth;
  final OpaqueId accountId;
  final AccountRole role;
  final FlutterSecureStorage storage;
  final SqliteAccountDatabase? cacheDatabase;
  final int _authGeneration;
  final int? _databaseGeneration;
  int _cacheGeneration = 0;
  List<Dispute> _items = [];
  String get _prefix =>
      'disputes_${sha256.convert(utf8.encode(accountId.value))}_';
  String _key(String path) => '$_prefix${base64Url.encode(utf8.encode(path))}';
  Future<void> clearCache([String? shopId]) async {
    _cacheGeneration++;
    _items = [];
    // Customer list snapshots may reference more than one relationship.
    for (final key in (await storage.readAll()).keys) {
      if (key.startsWith(_prefix) ||
          key.startsWith(
            'customer_read_${sha256.convert(utf8.encode(accountId.value))}_',
          )) {
        await storage.delete(key: key);
      }
    }
  }

  void _guardSession() {
    if (auth.sessionGeneration != _authGeneration ||
        (cacheDatabase != null &&
            cacheDatabase!.generation != _databaseGeneration)) {
      _items = [];
      throw StateError('Dispute session replaced');
    }
  }

  Future<void> _guardCache() async {
    _guardSession();
    final database = cacheDatabase;
    if (database == null) throw StateError('Verified local access required');
    await database.transaction(accountId, (tx) async {
      final account = (await tx.query('local_account')).single;
      if (account['role'] != role.name ||
          account['last_verified_at_ms'] == null) {
        throw StateError('Verified dispute cache required');
      }
    }, expectedGeneration: _databaseGeneration);
    _guardSession();
  }

  List<Dispute> _parse(Object? value, String shopId, bool customer) {
    final row = jsonObject(value);
    final items = row['items'];
    if (items is! List || items.length > 1000) {
      throw const FormatException('Invalid disputes');
    }
    final result = items.map(Dispute.new).toList();
    if (result.any((d) => d.shopId != shopId) ||
        (customer && result.any((d) => d.customerUserId != accountId.value))) {
      throw const FormatException('Wrong dispute scope');
    }
    return result.where((d) => d.shopId == shopId).toList();
  }

  Future<DisputeSnapshot> load(String shopId, bool customer) async {
    if (customer != (role == AccountRole.customer)) {
      throw const AppFailure('FORBIDDEN', 'auth.forbidden');
    }
    _guardSession();
    final generation = _cacheGeneration;
    final revocationGeneration = revocation.generation;
    final path = customer
        ? '/v1/me/disputes?shopId=$shopId'
        : '/v1/shops/$shopId/disputes';
    final key = _key(path);
    try {
      final all = <Object?>[];
      final ids = <String>{};
      String? cursor;
      final cursors = <String>{};
      do {
        final uri = Uri.parse(path);
        final pagePath = uri
            .replace(
              queryParameters: {...uri.queryParameters, 'before': ?cursor},
            )
            .toString();
        final page = jsonObject(await auth.cloudRequest(accountId, pagePath));
        _guardSession();
        final parsed = _parse(page, shopId, customer);
        if (page['hasMore'] is! bool ||
            (page['hasMore'] == true) != (page['nextCursor'] != null) ||
            parsed.any((d) => !ids.add(d.id))) {
          throw const FormatException('Invalid dispute page');
        }
        all.addAll(page['items'] as List);
        if (all.length > 1000 ||
            (all.length == 1000 && page['hasMore'] == true)) {
          throw const AppFailure('DISPUTE_LIST_INCOMPLETE', 'history.failed');
        }
        cursor = page['nextCursor'] == null
            ? null
            : OpaqueId.fromJson(page['nextCursor']).value;
        if (cursor != null && (parsed.isEmpty || !cursors.add(cursor))) {
          throw const FormatException('Invalid dispute cursor');
        }
      } while (cursor != null);
      final value = {'items': all, 'hasMore': false, 'nextCursor': null};
      final items = _parse(value, shopId, customer);
      if (cacheDatabase != null) {
        await _guardCache();
        if ((generation != _cacheGeneration ||
            revocationGeneration != revocation.generation)) {
          throw const AppFailure('FORBIDDEN', 'auth.forbidden');
        }
        await storage.write(key: key, value: jsonEncode(value));
        _guardSession();
        if ((generation != _cacheGeneration ||
            revocationGeneration != revocation.generation)) {
          await storage.delete(key: key);
          throw const AppFailure('FORBIDDEN', 'auth.forbidden');
        }
      }
      if ((generation != _cacheGeneration ||
          revocationGeneration != revocation.generation)) {
        throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      }
      _guardSession();
      _items = items;
      return DisputeSnapshot(items, false);
    } on AppFailure catch (error) {
      _items = [];
      if (['FORBIDDEN', 'NOT_FOUND', 'AUTH_REQUIRED'].contains(error.code)) {
        await revocation.revoke();
        rethrow;
      }
      if (!error.retryable && error.code != 'NETWORK_ERROR') {
        await clearCache(shopId);
        rethrow;
      }
      if (error.code == 'INVALID_RESPONSE') {
        await clearCache(shopId);
        rethrow;
      }
      await _guardCache();
      if ((generation != _cacheGeneration ||
          revocationGeneration != revocation.generation)) {
        throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      }
      final cache = await storage.read(key: key);
      if (cache == null) rethrow;
      late List<Dispute> items;
      try {
        items = _parse(jsonDecode(cache), shopId, customer);
      } on FormatException {
        await clearCache(shopId);
        throw const AppFailure('INVALID_RESPONSE', 'api.invalidResponse');
      }
      await _guardCache();
      if ((generation != _cacheGeneration ||
          revocationGeneration != revocation.generation)) {
        throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      }
      _items = items;
      return DisputeSnapshot(items, true);
    } on FormatException {
      await clearCache(shopId);
      throw const AppFailure('INVALID_RESPONSE', 'api.invalidResponse');
    } on StateError {
      _items = [];
      rethrow;
    }
  }

  Future<void> create(String shopId, String entryId, String reason) async {
    _guardSession();
    _validate(reason);
    if (role != AccountRole.customer) {
      throw const AppFailure('FORBIDDEN', 'auth.forbidden');
    }
    await auth.cloudRequest(
      accountId,
      '/v1/me/ledgers/$shopId/entries/$entryId/disputes',
      body: {'reason': reason.trim()},
    );
    _guardSession();
  }

  Future<void> resolve(String shopId, String id, String note) async {
    _guardSession();
    _validate(note);
    if (role != AccountRole.owner) {
      throw const AppFailure('FORBIDDEN', 'auth.forbidden');
    }
    await auth.cloudRequest(
      accountId,
      '/v1/shops/$shopId/disputes/$id/resolve',
      body: {'resolutionNote': note.trim()},
    );
    _guardSession();
  }

  void _validate(String value) {
    if (value.trim().isEmpty || value.trim().length > 240) {
      throw const FormatException('Use 1–240 characters.');
    }
  }

  @override
  Future<DisputeStatus?> statusForEntry(OpaqueId entryId) async {
    await _guardCache();
    final matches = _items.where((d) => d.entryId == entryId.value);
    return matches.isEmpty ? null : matches.first.status;
  }
}
