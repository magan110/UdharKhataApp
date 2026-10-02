import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/features/settings/privacy_repository.dart';

void main() {
  test('privacy status parsing never calls a submitted request deleted', () {
    final request = DataRequest.fromJson({
      'id': 'request',
      'kind': 'account_deletion',
      'shopId': null,
      'status': 'submitted',
      'createdAtMs': 1,
      'resolvedAtMs': null,
    });
    expect(request.status, 'submitted');
    expect(
      () => DataRequest.fromJson({
        'id': 'x',
        'kind': 'account_deletion',
        'shopId': null,
        'status': 'deleted',
        'createdAtMs': 1,
      }),
      throwsFormatException,
    );
  });
}
