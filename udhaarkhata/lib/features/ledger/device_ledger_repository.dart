import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/account.dart';
import '../../core/db/database.dart';
import '../../core/db/ledger_dao.dart';
import '../../core/db/outbox_dao.dart';
import '../../core/db/repositories.dart';
import '../../core/network/app_failure.dart';
import '../../core/network/contracts.dart';
import '../../core/sync/operation.dart';
import '../../core/sync/save_local.dart';
import '../qr/owner_qr_model.dart';
import 'entry_model.dart';
import 'correction_form.dart';
import 'ledger_repository.dart';
import 'money.dart';
import 'online_reads.dart';

final FutureProvider<List<Map<String, Object?>>> savedCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) {
      final repository = ref.watch(ledgerRepositoryProvider);
      return repository is DeviceLedgerRepository
          ? repository.savedCustomers()
          : Future.value([]);
    }, retry: (_, _) => null);

// D11 saves new commands locally. D12 adds serial push/pull; legacy uncertain
// online commands still use their original D08/D09 recovery path.
class DeviceLedgerRepository extends CloudLedgerRepository
    implements CorrectionRepository {
  DeviceLedgerRepository(
    super.auth,
    super.accountId,
    super.storage,
    this.database, {
    this.onLocalSaved,
    this.onCacheReady,
    this.refreshCached,
  });
  final void Function()? onLocalSaved, onCacheReady;
  final Future<void> Function(OpaqueId, OpaqueId)? refreshCached;
  final SqliteAccountDatabase database;
  OwnerLedgerDao get _dao => OwnerLedgerDao(database, accountId);
  Future<void> _localQueue = Future.value();
  Future<T> _localSerial<T>(Future<T> Function() action) {
    final result = _localQueue.then((_) => action());
    _localQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<CachedOwnerLedger?> snapshot(OpaqueId shop, OpaqueId link) =>
      _dao.snapshot(shop.value, link.value);
  Future<List<Map<String, Object?>>> savedCustomers() => _dao.links();
  Future<List<Map<String, Object?>>> outbox() =>
      OutboxDao(database, accountId).entries();

  CustomerLink _customer(CachedOwnerLedger snapshot) => CustomerLink(
    id: OpaqueId.fromJson(snapshot.link['id']),
    shopId: OpaqueId.fromJson(snapshot.link['shop_id']),
    customerId: OpaqueId.fromJson(snapshot.link['customer_user_id']),
    displayName: jsonString(snapshot.link['display_name']),
    nickname: snapshot.link['nickname'] as String?,
    linkedAtMs: timestampMs(snapshot.link['linked_at_ms']),
    balance: MoneyPaise.fromJson(snapshot.provisionalPaise),
    version: snapshot.entries.where((e) => e['sync_status'] == 'synced').length,
  );

  Future<CustomerLink> recoveryCustomer(OpaqueId shop, OpaqueId link) async {
    try {
      final customer = CustomerLink.fromJson(
        await auth.cloudRequest(
          accountId,
          '/v1/shops/${shop.value}/customers/${link.value}',
        ),
      );
      if (customer.shopId.value != shop.value ||
          customer.id.value != link.value) {
        throw const FormatException('Wrong recovery customer');
      }
      return customer;
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
    }
  }

  Future<CustomerLink> prepareCustomer(
    OpaqueId shop,
    OpaqueId link, {
    bool refresh = false,
  }) async {
    final saved = await snapshot(shop, link);
    if (saved != null && !refresh) return _customer(saved);
    if (saved != null && refreshCached != null) {
      await refreshCached!(shop, link);
      final latest = await snapshot(shop, link);
      if (latest == null) throw const AppFailure('NOT_FOUND', 'api.notFound');
      return _customer(latest);
    }
    try {
      final customer = CustomerLink.fromJson(
        await auth.cloudRequest(
          accountId,
          '/v1/shops/${shop.value}/customers/${link.value}',
        ),
      );
      if (customer.shopId.value != shop.value ||
          customer.id.value != link.value) {
        throw const FormatException('Wrong customer');
      }
      final reader = OnlineReadRepository(auth, accountId, AccountRole.owner);
      OnlineReadPage? first;
      String? cursor;
      final cursors = <String>{};
      final entries = <HistoryEntry>[];
      do {
        final page = await reader.load(
          '/v1/shops/${shop.value}/customers/${link.value}/entries',
          OnlineReadKind.history,
          cursor: cursor,
          shopId: shop.value,
          linkId: link.value,
        );
        if (page.balance!.ledgerVersion > maxOfflineCacheEntries) {
          throw const AppFailure('CACHE_TOO_LARGE', 'ledger.cacheTooLarge');
        }
        first ??= page;
        if (page.snapshotAtMs != first.snapshotAtMs ||
            page.linkId != first.linkId ||
            page.balance!.balancePaise != first.balance!.balancePaise ||
            page.balance!.ledgerVersion != first.balance!.ledgerVersion ||
            page.balance!.asOfServerSeq != first.balance!.asOfServerSeq) {
          throw const FormatException('Mixed snapshot');
        }
        entries.addAll(page.records.cast<HistoryEntry>());
        // Bound automatic bootstrap work. Larger histories remain online-only
        // until a reviewed incremental cache strategy is available.
        if (entries.length > maxOfflineCacheEntries) {
          throw const FormatException('Cache limit exceeded');
        }
        cursor = page.page?.nextCursor?.value;
        if (cursor != null && !cursors.add(cursor)) {
          throw const FormatException('Repeated cursor');
        }
      } while (cursor != null);
      var sum = 0, seq = 0;
      final ids = <String>{};
      for (final entry in entries) {
        if (entry.seq <= seq || !ids.add(entry.id)) {
          throw const FormatException('Invalid history order');
        }
        sum += entry.effect;
        seq = entry.seq;
      }
      final balance = first.balance!;
      if (sum != balance.balancePaise ||
          entries.length != balance.ledgerVersion ||
          seq != balance.asOfServerSeq) {
        throw const FormatException('History does not reconcile');
      }
      await _dao.cache(
        {
          'id': link.value,
          'shop_id': shop.value,
          'customer_user_id': customer.customerId.value,
          'owner_user_id': accountId.value,
          'status': 'active',
          'last_verified_at_ms': first.snapshotAtMs,
          'display_name': customer.displayName,
          'nickname': customer.nickname,
          'linked_at_ms': customer.linkedAtMs,
        },
        [
          for (final entry in entries)
            {
              'local_id': 'server_${entry.id}',
              'server_id': entry.id,
              'server_seq': entry.seq,
              'link_id': link.value,
              'kind': entry.kind,
              'amount_paise': entry.kind == 'correction' ? null : entry.amount,
              'target_amount_paise': entry.kind == 'correction'
                  ? entry.amount
                  : null,
              'effect_paise': entry.effect,
              'note': entry.note,
              'payment_method': entry.method,
              'due_date': entry.dueDate,
              'corrects_entry_id': entry.targetId,
              'expected_revision': entry.kind == 'correction'
                  ? entry.revision - 1
                  : null,
              'correction_reason': entry.reason,
              'occurred_at_ms': entry.occurredAtMs,
              'created_at_ms': entry.createdAtMs,
              'sync_status': 'synced',
            },
        ],
        balance.balancePaise,
        balance.ledgerVersion,
        balance.asOfServerSeq,
        first.snapshotAtMs,
      );
      onCacheReady?.call();
      return _customer((await snapshot(shop, link))!);
    } on AppFailure catch (error) {
      if (['FORBIDDEN', 'NOT_FOUND'].contains(error.code)) {
        await _dao.deny(shop.value, link.value);
      }
      rethrow;
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'history.invalidResponse');
    }
  }

  Future<void> _guardLegacy(OpaqueId shop, OpaqueId link) async {
    if (await pending(shop, link) != null) {
      throw const AppFailure('CREDIT_PENDING', 'credit.pending');
    }
    if (await pendingPayment(shop, link) != null) {
      throw const AppFailure('PAYMENT_PENDING', 'payment.pending');
    }
    if (await snapshot(shop, link) == null) {
      throw const AppFailure('LOCAL_LEDGER_REQUIRED', 'ledger.cacheRequired');
    }
  }

  Future<void> _save(OpaqueId shop, Map<String, Object?> body) async {
    try {
      await SaveLocal(LocalLedgerStore(database, accountId))(shop.value, body);
      onLocalSaved?.call();
    } on StateError catch (error) {
      if (error.message == 'Provisional balance out of range') {
        throw const AppFailure(
          'LOCAL_BALANCE_CONFLICT',
          'ledger.localOverpayment',
        );
      }
      if (error.message == 'Verified complete ledger required' ||
          error.message == 'Verified active link required') {
        throw const AppFailure('LOCAL_LEDGER_REQUIRED', 'ledger.cacheRequired');
      }
      rethrow;
    } on FormatException {
      throw const AppFailure('VALIDATION_ERROR', 'credit.invalid');
    }
  }

  @override
  Future<CreditAttempt> begin(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String? note,
    String? dueDate,
  ) => _localSerial(() async {
    await _guardLegacy(shopId, linkId);
    final normalized = note?.trim();
    if (amountPaise < 1 ||
        amountPaise > maxCreditPaise ||
        (normalized?.length ?? 0) > maxCreditNoteCharacters ||
        !validDueDate(dueDate)) {
      throw const AppFailure('VALIDATION_ERROR', 'credit.invalid');
    }
    final attempt = CreditAttempt(
      newOperationId(),
      linkId,
      displayName,
      amountPaise,
      normalized == null || normalized.isEmpty ? null : normalized,
      dueDate,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _save(shopId, attempt.body);
    return attempt;
  });
  @override
  Future<PaymentAttempt> beginPayment(
    OpaqueId shopId,
    OpaqueId linkId,
    String displayName,
    int amountPaise,
    String paymentMethod,
  ) => _localSerial(() async {
    await _guardLegacy(shopId, linkId);
    if (amountPaise < 1 ||
        amountPaise > maxCreditPaise ||
        !['cash', 'upi'].contains(paymentMethod)) {
      throw const AppFailure('VALIDATION_ERROR', 'payment.invalid');
    }
    final attempt = PaymentAttempt(
      newOperationId(),
      linkId,
      displayName,
      amountPaise,
      paymentMethod,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _save(shopId, attempt.body);
    return attempt;
  });
  @override
  Future<void> saveCorrection(
    OpaqueId shopId,
    OpaqueId linkId,
    String entryId,
    int targetAmountPaise,
    int expectedRevision,
    String reason,
  ) => _localSerial(() async {
    await _guardLegacy(shopId, linkId);
    await _save(shopId, {
      'clientOperationId': newOperationId(),
      'linkId': linkId.value,
      'kind': 'correction',
      'correctsEntryId': entryId,
      'targetAmountPaise': targetAmountPaise,
      'expectedRevision': expectedRevision,
      'correctionReason': reason.trim(),
      'occurredAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  });
}
