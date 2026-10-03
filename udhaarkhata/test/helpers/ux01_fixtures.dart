// Synthetic production-screen fixtures. No API or SQLite I/O is performed.
import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/db/ledger_dao.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/sync/coordinator.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/auth/sign_out_button.dart';
import 'package:udhaarkhata/features/ledger/customer_shell.dart';
import 'package:udhaarkhata/features/ledger/customer_shops.dart';
import 'package:udhaarkhata/features/ledger/history_page.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/payment_form.dart';
import 'package:udhaarkhata/features/ledger/correction_form.dart';
import 'package:udhaarkhata/features/ledger/entry_model.dart';
import 'package:udhaarkhata/features/ledger/entry_detail.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/online_reads.dart';
import 'package:udhaarkhata/features/ledger/sync_service.dart';
import 'package:udhaarkhata/features/ledger/sync_status_view.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';
import 'package:udhaarkhata/features/shop/owner_shell.dart';
import 'package:udhaarkhata/features/shop/customer_list.dart';
import 'package:udhaarkhata/features/qr/customer_qr_page.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';
import 'package:udhaarkhata/features/qr/owner_qr_model.dart';
import 'package:udhaarkhata/features/qr/qr_repository.dart';
import 'package:udhaarkhata/features/qr/qr_model.dart';
import 'package:udhaarkhata/features/qr/scanner_page.dart';
import 'package:udhaarkhata/features/qr/link_confirm_page.dart';
import 'package:udhaarkhata/features/qr/resolve_controller.dart';
import 'package:udhaarkhata/features/disputes/dispute_page.dart';
import 'package:udhaarkhata/features/disputes/dispute_entry_context.dart';
import 'package:udhaarkhata/features/disputes/dispute_repository.dart';
import 'package:udhaarkhata/features/settings/settings_page.dart';
import 'package:udhaarkhata/features/settings/recovery_help.dart';
import 'package:udhaarkhata/features/sharing/statement_share_page.dart';

import '../history_ui_test.dart' show HistoryAuth;
import '../owner_link_test.dart' show LinkAuth, linkJson;
import '../auth_session_test.dart' show MemorySecureStorage;

const captureTime = 1790985600000;
const captureOperation = '00000000-0000-4000-8000-000000000021';

class CaptureAuth extends HistoryAuth {
  CaptureAuth(super.role, this.scenario) {
    more = scenario.contains('paged');
    wrongSnapshot = scenario.contains('reconcile');
    if (scenario.contains('reconcile')) more = true;
    if (scenario.contains('corrected')) {
      entries.add({
        ...entries.first,
        'id': 'correction',
        'kind': 'correction',
        'serverSeq': 3,
        'amountPaise': null,
        'targetAmountPaise': 45000,
        'note': null,
        'dueDate': null,
        'effectPaise': -5000,
        'correctsEntryId': 'credit',
        'revision': 1,
        'correctionReason': 'Checked original receipt',
        'occurredAtMs': captureTime,
        'createdAtMs': captureTime,
      });
      balance = 25000;
    }
  }
  final String scenario;
  bool requestSubmitted = false;
  @override
  Future<Account?> restoreSession() {
    if (scenario.startsWith('welcome') || scenario == 'session-reauth') {
      return Future.value(null);
    }
    if (scenario == 'session-loading') return Completer<Account?>().future;
    if (scenario == 'session-error') {
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return super.restoreSession();
  }

  @override
  Future<Account> signIn(AccountRole role) {
    if (scenario.contains('signing')) return Completer<Account>().future;
    throw AppFailure(
      scenario.contains('cancel') ? 'SIGN_IN_CANCELLED' : 'NETWORK_ERROR',
      scenario.contains('cancel') ? 'auth.cancelled' : 'api.networkError',
    );
  }

  @override
  bool get canSignIn => !scenario.contains('configuration');
  @override
  Future<({int pendingCount, bool remoteRevoked})> signOut() async =>
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
  @override
  Future<int> pendingCount() async => 2;
  @override
  Future<Object?> cloudRequest(
    OpaqueId id,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (scenario.contains('loading') && path != '/v1/me') {
      return Completer<Object?>().future;
    }
    if (scenario.contains('denied') && path != '/v1/me') {
      throw const AppFailure('FORBIDDEN', 'auth.forbidden');
    }
    if (scenario.contains('error') && path != '/v1/me') {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    }
    if (path.contains('privacy') || path.contains('data-requests')) {
      if (body != null) {
        requestSubmitted = true;
        return {
          'id': 'request-synthetic',
          'kind': body['kind'],
          'shopId': body['shopId'],
          'status': 'submitted',
          'createdAtMs': captureTime,
          'resolvedAtMs': null,
        };
      }
      return {
        'requests': scenario.contains('requests') || requestSubmitted
            ? [
                {
                  'id': 'request-synthetic',
                  'kind': requestSubmitted ? 'export' : 'account_deletion',
                  'shopId': requestSubmitted ? 'shop' : null,
                  'status': 'submitted',
                  'createdAtMs': captureTime,
                  'resolvedAtMs': null,
                },
              ]
            : [],
        'hasMore': scenario.contains('latest100'),
      };
    }
    if (path.contains('disputes')) {
      return {
        'items': scenario.contains('empty')
            ? []
            : [
                {
                  'id': 'dispute1',
                  'shopId': 'shop',
                  'entryId': 'credit',
                  'customerUserId': 'usr_synthetic',
                  'reason': 'Please check this credit amount.',
                  'status': scenario.contains('resolved') ? 'resolved' : 'open',
                  'createdAtMs': captureTime,
                  'resolutionNote': scenario.contains('resolved')
                      ? 'Correction recorded separately.'
                      : null,
                  'resolvedAtMs': scenario.contains('resolved')
                      ? captureTime
                      : null,
                },
              ],
        'hasMore': false,
        'nextCursor': null,
      };
    }
    if (path.endsWith('/due') || path.contains('/due?')) {
      return {
        'asOfDate': DateTime.now().toIso8601String().substring(0, 10),
        'balancePaise': scenario.contains('corrected') ? 25000 : 30000,
        'overduePaise': 10000,
        'asOfServerSeq': scenario.contains('corrected') ? 3 : 2,
        'asOfMs': DateTime.now().millisecondsSinceEpoch,
      };
    }
    if (path == '/v1/shops/shop') {
      return {
        'id': 'shop',
        'name': 'Kiran Store',
        'status': 'active',
        'createdAtMs': 1,
        'totalBalancePaise': scenario.contains('empty') ? 0 : 1245000,
        'customerCount': scenario.contains('empty') ? 0 : 3,
        'asOfAtMs': captureTime,
      };
    }
    if (path.startsWith('/v1/shops/shop/customers') &&
        !path.contains('/entries') &&
        !path.contains('/statement') &&
        !path.endsWith('/link')) {
      return {
        'customers': scenario.contains('empty')
            ? []
            : [
                for (final name in ['Asha Patel', 'Ravi Kumar', 'Meena Singh'])
                  {
                    ...linkJson,
                    'id': path.contains('cursor=')
                        ? '${name.split(' ').first}2'
                        : name.split(' ').first,
                    'customerDisplayName': path.contains('cursor=')
                        ? 'Second page customer'
                        : name,
                    'balancePaise': 125000,
                  },
              ],
        'page': {
          'hasMore': scenario.contains('paged') && !path.contains('cursor='),
          'nextCursor': scenario.contains('paged') && !path.contains('cursor=')
              ? 'next_cursor'
              : null,
        },
        'snapshotAtMs': captureTime,
      };
    }
    if (path.contains('/statement')) {
      return super.cloudRequest(
        id,
        path.replaceFirst('/statement', '/entries'),
        body: body,
      );
    }
    if (scenario.contains('empty') && path.contains('/entries')) {
      balance = 0;
      entries.clear();
    }
    if (scenario.contains('empty') && path.startsWith('/v1/me/ledgers?')) {
      return {
        'links': [],
        'page': {'hasMore': false, 'nextCursor': null},
        'snapshotAtMs': captureTime,
      };
    }
    final result = await super.cloudRequest(id, path, body: body);
    if (scenario.contains('corrected') && path.contains('/entries')) {
      final row = Map<String, Object?>.from(result as Map);
      row['balance'] = <String, Object?>{
        ...Map<String, Object?>.from(row['balance'] as Map),
        'asOfServerSeq': 3,
      };
      return row;
    }
    return result;
  }
}

class CaptureQr implements QrRepository {
  CaptureQr(this.scenario);
  final String scenario;
  QrRecord get record => QrRecord(
    CustomerQr.fromJson({
      'version': 1,
      'publicQrId': 'a' * 64,
      'payload': 'udhaar://customer/v1/${'a' * 64}',
    }),
    scenario.contains('cached')
        ? captureTime
        : DateTime.now().millisecondsSinceEpoch,
    noticeKey: scenario.contains('rotation-error') ? 'api.networkError' : null,
  );
  @override
  Future<QrRecord?> cached() async =>
      scenario.contains('cached') ||
          scenario.contains('signin') ||
          scenario.contains('rotation-error')
      ? record
      : null;
  @override
  Future<QrRecord> current() async {
    if (scenario.contains('signin')) {
      throw const AppFailure('AUTH_REQUIRED', 'auth.required');
    }
    if (scenario.contains('cached') ||
        scenario.contains('error') ||
        scenario.contains('uncertain')) {
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return record;
  }

  @override
  Future<QrRecord> rotate() async {
    if (scenario.contains('rotation-error')) {
      throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    }
    return record;
  }
}

class CaptureLedger extends DeviceLedgerRepository {
  CaptureLedger(CaptureAuth auth, this.scenario)
    : super(
        auth,
        OpaqueId.fromJson('usr_synthetic'),
        MemorySecureStorage(),
        SqliteAccountDatabase(factory: databaseFactoryFfiNoIsolate),
      );
  final String scenario;
  int _capturedEffect = 0;
  CustomerLink get customer => CustomerLink.fromJson({
    ...linkJson,
    'customerDisplayName': 'Asha Patel',
    'balancePaise': 2000000,
  });
  @override
  Future<CustomerLink> prepareCustomer(
    OpaqueId shop,
    OpaqueId link, {
    bool refresh = false,
  }) async {
    if (scenario.contains('loading')) return Completer<CustomerLink>().future;
    if (scenario.contains('error') || scenario.contains('denied')) {
      throw const AppFailure('FORBIDDEN', 'auth.forbidden');
    }
    return customer;
  }

  @override
  Future<CustomerLink> recoveryCustomer(OpaqueId shop, OpaqueId link) async =>
      customer;
  @override
  Future<CreditAttempt?> pending(OpaqueId shop, OpaqueId link) async =>
      scenario.contains('restart')
      ? CreditAttempt(
          captureOperation,
          link,
          'Asha Patel',
          1245000,
          'Rice',
          null,
          captureTime,
        )
      : null;
  @override
  Future<PendingPayment?> pendingPayment(OpaqueId shop, OpaqueId link) async =>
      null;
  @override
  Future<List<Map<String, Object?>>> savedCustomers() async => [];
  @override
  Future<List<Map<String, Object?>>> outbox() async => [
    {'state': 'pending', 'created_at_ms': captureTime},
  ];
  @override
  Future<CachedOwnerLedger?> snapshot(OpaqueId shop, OpaqueId link) async {
    if (scenario.startsWith('credit') || scenario.startsWith('payment')) {
      return CachedOwnerLedger(
        {
          'id': 'link',
          'shop_id': 'shop',
          'display_name': 'Asha Patel',
          'nickname': null,
        },
        [],
        2000000,
        _capturedEffect,
        captureTime,
      );
    }
    return CachedOwnerLedger(
      {
        'id': 'link',
        'shop_id': 'shop',
        'display_name': 'Asha Patel',
        'nickname': null,
      },
      [
        {
          'kind': 'credit',
          'amount_paise': 50000,
          'effect_paise': 50000,
          'occurred_at_ms': captureTime,
          'created_at_ms': captureTime,
          'sync_status': 'synced',
          'server_id': 'credit',
          'server_seq': 1,
          'client_operation_id': captureOperation,
          'note': 'Rice',
          'due_date': '2026-10-15',
        },
        {
          'kind': 'credit',
          'amount_paise': 15000,
          'effect_paise': 15000,
          'occurred_at_ms': captureTime,
          'created_at_ms': null,
          'sync_status': scenario.contains('attention')
              ? 'needs_attention'
              : 'pending',
          'note': 'Milk',
          'blocked_by_earlier': scenario.contains('attention') ? 1 : 0,
          'error_code': scenario.contains('attention')
              ? 'BALANCE_CONFLICT'
              : null,
        },
      ],
      50000,
      scenario.contains('negative') ? -65000 : 15000,
      captureTime,
      partialSyncAtMs: scenario.contains('partial')
          ? captureTime + 60000
          : null,
    );
  }

  @override
  Future<CreditAttempt> begin(
    OpaqueId shop,
    OpaqueId link,
    String displayName,
    int amount,
    String? note,
    String? due,
  ) async {
    _capturedEffect = amount;
    return CreditAttempt(
      captureOperation,
      link,
      displayName,
      amount,
      note,
      due,
      captureTime,
    );
  }

  @override
  Future<PaymentAttempt> beginPayment(
    OpaqueId shop,
    OpaqueId link,
    String name,
    int amount,
    String method,
  ) async {
    if (scenario.contains('overpayment')) {
      throw const AppFailure('BALANCE_CONFLICT', 'payment.balanceConflict');
    }
    _capturedEffect = -amount;
    return PaymentAttempt(
      captureOperation,
      link,
      name,
      amount,
      method,
      captureTime,
    );
  }

  @override
  Future<void> saveCorrection(
    OpaqueId shop,
    OpaqueId link,
    String entry,
    int amount,
    int revision,
    String reason,
  ) async {
    if (scenario.contains('conflict')) {
      throw const AppFailure('REVISION_CONFLICT', 'api.conflict');
    }
  }
}

class CaptureShop implements ShopRepository {
  CaptureShop(this.scenario);
  final String scenario;
  @override
  Future<Shop?> currentShop() async => null;
  @override
  Future<Shop> createShop(String name) async {
    if (scenario.contains('creating')) return Completer<Shop>().future;
    throw const AppFailure('NETWORK_ERROR', 'api.networkError');
  }
}

class CaptureSync extends SyncService {
  CaptureSync(super.repository, this.scenario);
  final String scenario;
  @override
  SyncRunState get state => SyncRunState(
    running: scenario.contains('running'),
    pendingCount: 2,
    needsAttentionCount: scenario.contains('attention') ? 1 : 0,
    lastSuccessfulAtMs: captureTime,
    errorCode: scenario.contains('attention')
        ? 'BALANCE_CONFLICT'
        : scenario.contains('network')
        ? 'NETWORK_ERROR'
        : scenario.contains('rate')
        ? 'RATE_LIMITED'
        : scenario.contains('capacity')
        ? 'CAPACITY_UNAVAILABLE'
        : scenario.contains('access')
        ? 'FORBIDDEN'
        : scenario.contains('auth')
        ? 'AUTH_REQUIRED'
        : scenario.contains('service')
        ? 'SERVICE_UNAVAILABLE'
        : null,
  );
  @override
  Stream<SyncRunState> get states => const Stream.empty();
  @override
  Future<int?> verifiedAt() async => captureTime;
  @override
  Future<List<Map<String, Object?>>> attention() async =>
      scenario.contains('attention')
      ? [
          {
            'kind': 'credit',
            'amount_paise': 15000,
            'occurred_at_ms': captureTime,
            'error_code': 'BALANCE_CONFLICT',
          },
        ]
      : [];
  @override
  Future<void> synchronize() async {}
}

class CaptureCloudLedger extends CloudLedgerRepository {
  CaptureCloudLedger(CaptureAuth auth, this.scenario)
    : super(auth, OpaqueId.fromJson('usr_synthetic'), MemorySecureStorage());
  final String scenario;
  PaymentAttempt? durablePayment;
  @override
  Future<CreditAttempt?> pending(OpaqueId shop, OpaqueId link) async =>
      scenario.contains('restart')
      ? CreditAttempt(
          captureOperation,
          link,
          'Asha Patel',
          1245000,
          'Rice',
          null,
          captureTime,
        )
      : null;
  @override
  Future<PendingPayment?> pendingPayment(OpaqueId shop, OpaqueId link) async =>
      (scenario.contains('rejected') || scenario.contains('restart'))
      ? PendingPayment(
          PaymentAttempt(
            captureOperation,
            link,
            'Asha Patel',
            1245000,
            'upi',
            captureTime,
          ),
          scenario.contains('rejected'),
        )
      : durablePayment == null
      ? null
      : PendingPayment(durablePayment!, false);
  @override
  Future<CreditAttempt> begin(
    OpaqueId shop,
    OpaqueId link,
    String name,
    int amount,
    String? note,
    String? due,
  ) async => CreditAttempt(
    captureOperation,
    link,
    name,
    amount,
    note,
    due,
    captureTime,
  );
  @override
  Future<PaymentAttempt> beginPayment(
    OpaqueId shop,
    OpaqueId link,
    String name,
    int amount,
    String method,
  ) async {
    durablePayment = PaymentAttempt(
      captureOperation,
      link,
      name,
      amount,
      method,
      captureTime,
    );
    return durablePayment!;
  }

  Future<CreditReceipt> result() async {
    if (scenario.contains('saving')) return Completer<CreditReceipt>().future;
    if (scenario.contains('retry')) {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    }
    return CreditReceipt(
      OpaqueId.fromJson('ack-entry'),
      scenario.startsWith('credit') ? 3245000 : 755000,
      3,
      false,
    );
  }

  @override
  Future<CreditReceipt> submit(OpaqueId shop, CreditAttempt attempt) =>
      result();
  @override
  Future<CreditReceipt> submitPayment(OpaqueId shop, PaymentAttempt attempt) =>
      result();
}

class CaptureDisputes extends CloudDisputeRepository {
  CaptureDisputes(CaptureAuth auth, this.scenario)
    : super(
        auth,
        OpaqueId.fromJson('usr_synthetic'),
        role: auth.role,
        storage: MemorySecureStorage(),
      );
  final String scenario;
  @override
  Future<DisputeSnapshot> load(String shop, bool customer) async =>
      DisputeSnapshot(
        scenario.contains('empty')
            ? []
            : [
                Dispute({
                  'id': 'dispute1',
                  'shopId': shop,
                  'entryId': 'credit',
                  'customerUserId': 'usr_synthetic',
                  'reason': 'Please check this credit amount.',
                  'status': scenario.contains('resolved') ? 'resolved' : 'open',
                  'createdAtMs': captureTime,
                  'resolutionNote': scenario.contains('resolved')
                      ? 'Correction recorded separately.'
                      : null,
                  'resolvedAtMs': scenario.contains('resolved')
                      ? captureTime
                      : null,
                }),
              ],
        scenario.contains('cached'),
      );
  @override
  Future<void> resolve(String shop, String id, String note) async {}
}

class CaptureReader extends OnlineReadRepository {
  CaptureReader(CaptureAuth auth, this.scenario)
    : super(
        auth,
        OpaqueId.fromJson('usr_synthetic'),
        auth.role,
        storage: MemorySecureStorage(),
      );
  final String scenario;
  @override
  Future<OnlineReadPage> load(
    String path,
    OnlineReadKind kind, {
    String? cursor,
    String? shopId,
    String? linkId,
  }) async {
    final p = await super.load(
      path,
      kind,
      cursor: cursor,
      shopId: shopId,
      linkId: linkId,
    );
    return OnlineReadPage(
      records: p.records,
      snapshotAtMs: p.snapshotAtMs,
      offline: scenario.contains('offline') || scenario.contains('cached'),
      page: p.page,
      balance: p.balance,
      shopName: p.shopName,
      customerName: p.customerName,
      linkId: p.linkId,
      total: p.total,
      customerCount: p.customerCount,
    );
  }
}

Widget ux01FixtureSurface(String scenario, Locale locale) {
  final customer =
      scenario.startsWith('customer') ||
      scenario.startsWith('disputes-customer');
  final auth = CaptureAuth(
    customer ? AccountRole.customer : AccountRole.owner,
    scenario,
  );
  final ledger = CaptureLedger(auth, scenario);
  final LedgerRepository presentationLedger =
      ['ack', 'retry', 'saving', 'rejected', 'restart'].any(scenario.contains)
      ? CaptureCloudLedger(auth, scenario)
      : ledger;
  final links = CloudOwnerLinkRepository(
    LinkAuth()
      ..response = {
        ...linkJson,
        'customerDisplayName': 'Asha Patel',
        'balancePaise': 2000000,
      },
    OpaqueId.fromJson('usr_synthetic'),
    MemorySecureStorage(),
  );
  final controller = ResolveController(links, OpaqueId.fromJson('shop'))
    ..customer = ResolvedCustomer('a' * 64, 'Asha Patel', null)
    ..stage = scenario.contains('recovery')
        ? ScanStage.recovery
        : scenario.contains('saving')
        ? ScanStage.saving
        : ScanStage.confirm;
  if (scenario.startsWith('link') && scenario.contains('recovery')) {
    controller.attempt = LinkAttempt(
      captureOperation,
      'a' * 64,
      'Asha Patel',
      null,
    );
  }
  if (scenario.startsWith('link') && scenario.contains('error')) {
    controller.error = const AppFailure('NETWORK_ERROR', 'api.networkError');
  }
  Widget page;
  if (scenario.startsWith('welcome') || scenario.startsWith('session')) {
    page = CaptureRouterSurface(unavailable: scenario == 'session-unavailable');
  } else if (scenario.startsWith('shop-setup')) {
    page = const Scaffold(body: ShopSetup());
  } else if (scenario.startsWith('owner-home')) {
    page = const OwnerShell();
  } else if (scenario.startsWith('owner-customers')) {
    page = const OwnerShell(tab: 'customers');
  } else if (scenario.startsWith('owner-more')) {
    page = const OwnerShell(tab: 'more');
  } else if (scenario.startsWith('owner-workspace')) {
    page = OwnerCustomerPage(
      shopId: OpaqueId.fromJson('shop'),
      linkId: OpaqueId.fromJson('link'),
    );
  } else if (scenario.startsWith('owner-history')) {
    page = HistoryPage(
      shopId: 'shop',
      linkId: 'link',
      confirmedOnly: scenario.contains('confirmed'),
    );
  } else if (scenario.startsWith('entry-detail')) {
    final e = <String, Object?>{
      'kind': 'credit',
      'server_id': 'credit',
      'server_seq': 1,
      'amount_paise': 50000,
      'effect_paise': 50000,
      'occurred_at_ms': captureTime,
      'created_at_ms': captureTime,
      'sync_status': 'synced',
      'note': 'Rice',
      'due_date': '2026-10-15',
    };
    page = Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: EntryDetail(
          shopId: 'shop',
          linkId: 'link',
          entry: e,
          entries: [
            e,
            if (scenario.contains('corrected'))
              {
                'kind': 'correction',
                'corrects_entry_id': 'credit',
                'target_amount_paise': 45000,
                'effect_paise': -5000,
                'created_at_ms': captureTime,
                'sync_status': 'synced',
                'server_seq': 2,
                'correction_reason': 'Checked original receipt',
              },
          ],
        ),
      ),
    );
  } else if (scenario.startsWith('credit')) {
    page = CreditPage(
      shopId: OpaqueId.fromJson('shop'),
      linkId: OpaqueId.fromJson('link'),
    );
  } else if (scenario.startsWith('payment')) {
    page = PaymentPage(
      shopId: OpaqueId.fromJson('shop'),
      linkId: OpaqueId.fromJson('link'),
    );
  } else if (scenario.startsWith('correction')) {
    page = const CorrectionPage(
      shopId: 'shop',
      linkId: 'link',
      entryId: 'credit',
      effectiveAmountPaise: 50000,
      revision: 0,
    );
  } else if (scenario.startsWith('scanner')) {
    page = Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings(locale.languageCode).translate('Scan customer QR'),
        ),
      ),
      body: ScannerCameraError(
        permissionDenied: scenario.contains('denied'),
        restarting: false,
        onRetry: () {},
        onSettings: () {},
      ),
    );
  } else if (scenario.startsWith('link')) {
    page = Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings(locale.languageCode).translate('Scan customer QR'),
        ),
      ),
      body: LinkConfirmation(controller: controller),
    );
  } else if (scenario.startsWith('customer-qr')) {
    page = const Scaffold(body: CustomerQrPage());
  } else if (scenario.startsWith('customer-shops')) {
    page = const Scaffold(body: CustomerShopsPage());
  } else if (scenario.startsWith('customer-more')) {
    page = const CustomerShell(tab: 'more');
  } else if (scenario.startsWith('customer-history')) {
    page = const HistoryPage(shopId: 'shop');
  } else if (scenario.startsWith('disputes')) {
    page = DisputePage(
      shopId: 'shop',
      customer: scenario.contains('customer'),
      entryId: scenario.contains('customer') || scenario.contains('context')
          ? 'credit'
          : null,
      entryContext: scenario.contains('context-matched')
          ? const DisputeEntryContext(
              accountId: 'usr_synthetic',
              shopId: 'shop',
              entryId: 'credit',
              kind: 'credit',
              amountPaise: 50000,
              occurredAtMs: captureTime,
            )
          : null,
    );
  } else if (scenario.startsWith('statement')) {
    page = const StatementSharePage(shopId: 'shop', linkId: 'link');
  } else if (scenario.startsWith('settings')) {
    page = const SettingsPage();
  } else if (scenario.startsWith('help')) {
    page = const RecoveryHelpPage();
  } else if (scenario.startsWith('sync')) {
    page = const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SyncStatusView(),
      ),
    );
  } else if (scenario.startsWith('signout')) {
    page = const Scaffold(body: Center(child: SignOutButton()));
  } else {
    throw ArgumentError('Unknown production surface $scenario');
  }
  return ProviderScope(
    key: ValueKey('$scenario-${locale.languageCode}'),
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      if (scenario.startsWith('shop-setup'))
        shopRepositoryProvider.overrideWithValue(CaptureShop(scenario)),
      onlineReadRepositoryProvider.overrideWithValue(
        CaptureReader(auth, scenario),
      ),
      disputeRepositoryProvider.overrideWithValue(
        CaptureDisputes(auth, scenario),
      ),
      currentShopProvider.overrideWith(
        (ref) async => scenario.startsWith('shop-setup')
            ? null
            : Shop(OpaqueId.fromJson('shop'), 'Kiran Store'),
      ),
      ledgerRepositoryProvider.overrideWithValue(presentationLedger),
      paymentRepositoryProvider.overrideWithValue(
        presentationLedger as PaymentRepository,
      ),
      ownerLinkRepositoryProvider.overrideWithValue(links),
      qrRepositoryProvider.overrideWithValue(CaptureQr(scenario)),
      syncServiceProvider.overrideWithValue(CaptureSync(ledger, scenario)),
      syncRunStateProvider.overrideWith(
        (ref) => Stream.value(CaptureSync(ledger, scenario).state),
      ),
      savedCustomersProvider.overrideWith(
        (ref) async => scenario.contains('saved')
            ? [
                {
                  'id': 'link',
                  'shop_id': 'shop',
                  'display_name': 'Asha Patel',
                  'nickname': null,
                },
              ]
            : [],
      ),
    ],
    child: page,
  );
}

class CaptureRouterSurface extends ConsumerWidget {
  const CaptureRouterSurface({super.key, this.unavailable = false});
  final bool unavailable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    if (unavailable && ref.watch(sessionProvider).value != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => router.go('/missing-synthetic-route'),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      locale: Localizations.localeOf(context),
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppStrings.supportedLocales,
      routerConfig: router,
    );
  }
}
