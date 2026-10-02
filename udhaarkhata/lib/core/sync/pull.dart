import '../auth/auth_repository.dart';
import '../db/sync_dao.dart';
import '../db/cursor_dao.dart';
import '../network/app_failure.dart';
import '../network/contracts.dart';
import 'sync_models.dart';

final class SyncPull {
  const SyncPull({
    required this.auth,
    required this.dao,
    required this.cursors,
    required this.accountId,
  });
  final AuthRepository auth;
  final SyncDao dao;
  final CursorDao cursors;
  final OpaqueId accountId;
  void _guard() {
    if (auth.sessionGeneration != dao.generation ||
        dao.database.generation != dao.generation) {
      throw StateError('Sync session replaced');
    }
  }

  Future<SyncPage> page(String shopId, String linkId, {String? cursor}) async {
    _guard();
    final after = await cursors.sequence(linkId);
    final path = Uri(
      path: '/v1/shops/$shopId/customers/$linkId/sync',
      queryParameters: {
        'limit': '50',
        if (cursor != null)
          'cursor': PageCursor.fromJson(cursor).value
        else
          'afterSeq': '$after',
      },
    ).toString();
    final response = await auth.cloudRequest(accountId, path);
    _guard();
    try {
      final page = SyncPage.fromJson(response);
      await dao.applyPage(shopId, linkId, page);
      return page;
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    } on StateError {
      _guard();
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }
}
