import '../../core/network/cache_revocation.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/error_classifier.dart';
import '../../core/db/database.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../auth/session_controller.dart';
import '../qr/owner_qr_model.dart';
import '../../core/network/ledger_entry.dart';
export '../../core/network/ledger_entry.dart';

enum OnlineReadKind { history, customers, shops, summary }

final onlineReadRepositoryProvider = Provider<OnlineReadRepository?>((ref) {
  final account = ref.watch(sessionProvider).value;
  return account == null
      ? null
      : OnlineReadRepository(
          ref.watch(authRepositoryProvider),
          account.id,
          account.role,
          storage: const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          ),
        );
});

class ShopLedger {
  ShopLedger(Object? value) {
    final row = jsonObject(value);
    id = OpaqueId.fromJson(row['id']).value;
    shopId = OpaqueId.fromJson(row['shopId']).value;
    name = jsonString(row['shopName']);
    balance = MoneyPaise.fromJson(row['balancePaise']).value;
    timestampMs(row['ledgerVersion']);
    if (balance < 0 || name.length > 120) {
      throw const FormatException('Invalid shop');
    }
  }
  late final String id, shopId, name;
  late final int balance;
}

class OnlineReadPage {
  const OnlineReadPage({
    required this.records,
    required this.snapshotAtMs,
    this.offline = false,
    this.page,
    this.balance,
    this.shopName,
    this.customerName,
    this.linkId,
    this.total,
    this.customerCount,
  });
  final bool offline;
  final List<Object> records;
  final int snapshotAtMs;
  final ApiPage? page;
  final LedgerBalanceSnapshot? balance;
  final String? shopName, customerName, linkId;
  final int? total, customerCount;
}

class OnlineReadRepository {
  OnlineReadRepository(
    this.auth,
    this.accountId,
    this.role, {
    this.storage,
    this.cacheDatabase,
  }) {
    revocation = CacheRevocation.forAccount(auth, accountId.value);
    revocation.register(() => clearShopCache('all'));
  }
  late final CacheRevocation revocation;
  int _cacheGeneration = 0;
  final FlutterSecureStorage? storage;
  final SqliteAccountDatabase? cacheDatabase;
  final AuthRepository auth;
  final OpaqueId accountId;
  final AccountRole role;
  Future<void> clearShopCache(String shopId) async {
    _cacheGeneration++;
    // Shop lists and paginated history may reference this relationship; clear all
    // this account's confirmed snapshots rather than retain an obsolete page.
    final secure = storage;
    if (secure == null || role != AccountRole.customer) return;
    final prefix =
        'customer_read_${sha256.convert(utf8.encode(accountId.value))}_';
    for (final key in (await secure.readAll()).keys) {
      if (key.startsWith(prefix) ||
          key.startsWith(
            'disputes_${sha256.convert(utf8.encode(accountId.value))}_',
          )) {
        await secure.delete(key: key);
      }
    }
  }

  Future<void> _guardCache() async {
    final a = auth;
    final database =
        cacheDatabase ?? (a is GoogleAuthRepository ? a.database : null);
    if (database == null) throw StateError('Verified local access required');
    await database.transaction(accountId, (tx) async {
      final account = (await tx.query('local_account')).single;
      if (account['role'] != 'customer' ||
          account['last_verified_at_ms'] == null) {
        throw StateError('Customer cache unavailable');
      }
    });
  }

  Future<OnlineReadPage> load(
    String path,
    OnlineReadKind kind, {
    String? cursor,
    String? shopId,
    String? linkId,
  }) async {
    final generation = _cacheGeneration;
    final revocationGeneration = revocation.generation;
    final enabled =
        role == AccountRole.customer &&
        storage != null &&
        (auth is GoogleAuthRepository || cacheDatabase != null);
    final key =
        'customer_read_${sha256.convert(utf8.encode(accountId.value))}_${sha256.convert(utf8.encode(jsonEncode([path, kind.name, cursor, shopId, linkId])))}';
    Object? response;
    try {
      final page = await _load(
        path,
        kind,
        cursor: cursor,
        shopId: shopId,
        linkId: linkId,
        onResponse: (value) => response = value,
      );
      if (enabled &&
          generation == _cacheGeneration &&
          revocationGeneration == revocation.generation) {
        await _guardCache();
        if (generation == _cacheGeneration &&
            revocationGeneration == revocation.generation) {
          await storage!.write(key: key, value: jsonEncode(response));
          if ((generation != _cacheGeneration ||
              revocationGeneration != revocation.generation)) {
            await storage!.delete(key: key);
          }
        }
      }
      if (generation != _cacheGeneration ||
          revocationGeneration != revocation.generation) {
        throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      }
      return page;
    } on AppFailure catch (failure) {
      if (!enabled) rethrow;
      if (classifySyncFailure(failure) != SyncFailureKind.transient ||
          failure.code == 'INVALID_RESPONSE') {
        if ([
          'FORBIDDEN',
          'NOT_FOUND',
          'AUTH_REQUIRED',
        ].contains(failure.code)) {
          await revocation.revoke();
        } else {
          await storage!.delete(key: key);
        }
        rethrow;
      }
      await _guardCache();
      final text = await storage!.read(key: key);
      if (text == null) rethrow;
      final page = await _load(
        path,
        kind,
        cursor: cursor,
        shopId: shopId,
        linkId: linkId,
        cached: jsonDecode(text),
        offline: true,
      );
      await _guardCache();
      if ((generation != _cacheGeneration ||
          revocationGeneration != revocation.generation)) {
        throw const AppFailure('FORBIDDEN', 'auth.forbidden');
      }
      return page;
    }
  }

  Future<OnlineReadPage> _load(
    String path,
    OnlineReadKind kind, {
    String? cursor,
    String? shopId,
    String? linkId,
    Object? cached,
    bool offline = false,
    void Function(Object?)? onResponse,
  }) async {
    try {
      final query = kind == OnlineReadKind.summary
          ? path
          : Uri(
              path: path,
              queryParameters: {
                'limit': '50',
                if (cursor != null) 'cursor': PageCursor.fromJson(cursor).value,
              },
            ).toString();
      final response = cached ?? await auth.cloudRequest(accountId, query);
      final row = jsonObject(response);
      onResponse?.call(response);
      if (kind == OnlineReadKind.summary) {
        final total = MoneyPaise.fromJson(row['totalBalancePaise']).value;
        if (row['id'] != shopId || total < 0) {
          throw const FormatException('Wrong summary scope');
        }
        return OnlineReadPage(
          records: const [],
          offline: offline,
          snapshotAtMs: timestampMs(row['asOfAtMs']),
          total: total,
          customerCount: timestampMs(row['customerCount']),
        );
      }
      final page = ApiPage.fromJson(row['page']),
          snapshot = timestampMs(row['snapshotAtMs']);
      if (!page.hasMore && page.nextCursor != null) {
        throw const FormatException('Unexpected cursor');
      }
      final rows =
          row[switch (kind) {
            OnlineReadKind.history => 'entries',
            OnlineReadKind.customers => 'customers',
            _ => 'links',
          }];
      if (rows is! List || rows.length > 50 || (page.hasMore && rows.isEmpty)) {
        throw const FormatException('Invalid page');
      }
      switch (kind) {
        case OnlineReadKind.history:
          final scopeLink = OpaqueId.fromJson(row['linkId']).value;
          if (row['shopId'] != shopId ||
              (linkId != null && scopeLink != linkId)) {
            throw const FormatException('Wrong ledger');
          }
          final balance = LedgerBalanceSnapshot.fromJson(row['balance']);
          final entries = [
            for (final item in rows) HistoryEntry(item, shopId!, scopeLink),
          ];
          var previous = 0;
          for (final entry in entries) {
            if (entry.seq <= previous || entry.seq > balance.asOfServerSeq) {
              throw const FormatException('Invalid sequence');
            }
            previous = entry.seq;
          }
          return OnlineReadPage(
            records: entries,
            offline: offline,
            snapshotAtMs: snapshot,
            page: page,
            balance: balance,
            shopName: jsonString(row['shopName']),
            customerName: jsonString(row['customerDisplayName']),
            linkId: scopeLink,
          );
        case OnlineReadKind.customers:
          final customers = [
            for (final item in rows) CustomerLink.fromJson(item),
          ];
          if (customers.any((c) => c.shopId.value != shopId)) {
            throw const FormatException('Wrong customers');
          }
          return OnlineReadPage(
            records: customers,
            offline: offline,
            snapshotAtMs: snapshot,
            page: page,
          );
        case OnlineReadKind.shops:
          return OnlineReadPage(
            records: [for (final item in rows) ShopLedger(item)],
            offline: offline,
            snapshotAtMs: snapshot,
            page: page,
          );
        case OnlineReadKind.summary:
          throw const FormatException('Invalid read');
      }
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
    }
  }
}
