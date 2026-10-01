import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'app_failure.dart';
import 'contracts.dart';

final class ApiClient {
  ApiClient(this._client);
  final http.Client _client;

  Future<Object?> post(
    Uri uri,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    if (uri.scheme != 'https') {
      throw const AppFailure('TLS_REQUIRED', 'api.tlsRequired');
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 204) return null;
      final value = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiSuccess.fromJson(value, (data) => data).data;
      }
      throw AppFailure.fromJson(value);
    } on http.ClientException {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    } on TimeoutException {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }

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
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on http.ClientException {
      throw const AppFailure(
        'NETWORK_ERROR',
        'api.networkError',
        retryable: true,
      );
    } on TimeoutException {
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
