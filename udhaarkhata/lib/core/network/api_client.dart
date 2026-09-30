import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_failure.dart';
import 'contracts.dart';

final class ApiClient {
  ApiClient(this._client);
  final http.Client _client;

  Future<ApiSuccess<T>> get<T>(
    Uri uri,
    T Function(Object?) decode, {
    String? accessToken,
  }) async {
    if (uri.scheme != 'https') {
      throw const AppFailure('TLS_REQUIRED', 'api.tlsRequired');
    }
    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );
    } on http.ClientException {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    }
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiSuccess.fromJson(body, decode);
      }
      throw AppFailure.fromJson(body);
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }
}
