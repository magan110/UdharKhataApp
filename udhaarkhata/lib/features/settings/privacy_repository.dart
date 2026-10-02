import '../../core/network/cache_revocation.dart';
import '../ledger/online_reads.dart';
import '../disputes/dispute_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/network/contracts.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';

class DataRequest {
  const DataRequest(
    this.id,
    this.kind,
    this.shopId,
    this.status,
    this.createdAtMs,
    this.resolvedAtMs,
  );
  final String id, kind, status;
  final String? shopId;
  final int createdAtMs;
  final int? resolvedAtMs;
  factory DataRequest.fromJson(Object? value) {
    final map = jsonObject(value),
        kind = jsonString(map['kind']),
        status = jsonString(map['status']);
    if (![
          'export',
          'account_deletion',
          'shop_deletion',
          'access_removal',
        ].contains(kind) ||
        !['submitted', 'in_review', 'completed', 'denied'].contains(status)) {
      throw const FormatException('Invalid request status');
    }
    return DataRequest(
      OpaqueId.fromJson(map['id']).value,
      kind,
      map['shopId'] == null ? null : OpaqueId.fromJson(map['shopId']).value,
      status,
      timestampMs(map['createdAtMs']),
      map['resolvedAtMs'] == null ? null : timestampMs(map['resolvedAtMs']),
    );
  }
}

class PrivacyRepository {
  PrivacyRepository(this.auth, this.accountId);
  bool latestListIncomplete = false;
  final AuthRepository auth;
  final OpaqueId accountId;
  Future<List<DataRequest>> list() async {
    try {
      final map = jsonObject(
        await auth.cloudRequest(accountId, '/v1/me/data-requests'),
      );
      final rows = map['requests'];
      latestListIncomplete = map['hasMore'] == true;
      if (rows is! List || rows.length > 100) {
        throw const FormatException('Invalid requests');
      }
      return rows.map(DataRequest.fromJson).toList(growable: false);
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'api.invalidResponse');
    }
  }

  Future<DataRequest> submit(String kind, {String? shopId}) async {
    try {
      return DataRequest.fromJson(
        await auth.cloudRequest(
          accountId,
          '/v1/me/data-requests',
          body: {'kind': kind, 'shopId': ?shopId},
        ),
      );
    } on FormatException {
      throw const AppFailure('INVALID_RESPONSE', 'api.invalidResponse');
    }
  }

  Future<void> removeAccess(String shopId) async {
    await auth.cloudRequest(
      accountId,
      '/v1/me/ledgers/$shopId/access-removal',
      body: {},
    );
    await CacheRevocation.forAccount(auth, accountId.value).revoke();
  }
}

final privacyRepositoryProvider = Provider<PrivacyRepository?>((ref) {
  final account = ref.watch(sessionProvider).asData?.value;
  ref.watch(onlineReadRepositoryProvider);
  ref.watch(disputeRepositoryProvider);
  return account == null
      ? null
      : PrivacyRepository(ref.watch(authRepositoryProvider), account.id);
});
