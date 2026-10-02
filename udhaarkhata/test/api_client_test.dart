import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:udhaarkhata/core/network/api_client.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';

void main() {
  test(
    'decodes a success and passes bearer credentials only as a header',
    () async {
      final client = ApiClient(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic');
          expect(request.url.query, isEmpty);
          return http.Response(
            jsonEncode({
              'data': {'status': 'ok'},
              'requestId': 'req_test',
            }),
            200,
          );
        }),
      );
      expect(
        (await client.get(
          Uri.parse('https://api.test/health'),
          jsonObject,
          accessToken: 'synthetic',
        )).data['status'],
        'ok',
      );
    },
  );
  test('rejects cleartext transport before making a request', () async {
    final client = ApiClient(
      MockClient((_) async => throw StateError('must not call')),
    );
    await expectLater(
      client.get(Uri.parse('http://api.test'), jsonObject),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'TLS_REQUIRED')),
    );
  });
  test('maps network errors into a retryable localized failure', () async {
    final client = ApiClient(
      MockClient((_) async => throw http.ClientException('SENSITIVE_SENTINEL')),
    );
    await expectLater(
      client.get(Uri.parse('https://api.test'), jsonObject),
      throwsA(
        isA<AppFailure>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')
            .having((e) => e.retryable, 'retryable', true),
      ),
    );
  });
  test(
    'decodes a server error without rendering raw response details',
    () async {
      final client = ApiClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'AUTH_REQUIRED',
                'messageKey': 'auth.required',
                'retryable': false,
              },
              'requestId': 'req_test',
            }),
            401,
          ),
        ),
      );
      await expectLater(
        client.get(Uri.parse('https://api.test'), jsonObject),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.requestId,
            'request ID',
            'req_test',
          ),
        ),
      );
    },
  );
  test('malformed success and error responses fail safely', () async {
    for (final status in [200, 500]) {
      final client = ApiClient(
        MockClient((_) async => http.Response('SENSITIVE_SENTINEL', status)),
      );
      await expectLater(
        client.get(Uri.parse('https://api.test'), jsonObject),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.toString(),
            'diagnostic',
            status == 500
                ? 'AppFailure(SERVER_ERROR)'
                : 'AppFailure(INVALID_RESPONSE)',
          ),
        ),
      );
    }
  });
}
