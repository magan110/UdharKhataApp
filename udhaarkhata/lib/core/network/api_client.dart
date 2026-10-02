import 'dart:convert';
import 'dart:async';
import 'dart:io' show HttpDate;

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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(response);
      }
      final value = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiSuccess.fromJson(value, (data) => data).data;
      }
      throw _failure(response);
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failure(response);
      }
      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiSuccess.fromJson(body, decode);
      }
      throw _failure(response);
    } on FormatException {
      throw const AppFailure(
        'INVALID_RESPONSE',
        'api.invalidResponse',
        retryable: true,
      );
    }
  }

  AppFailure _failure(http.Response response) {
    DateTime? retryAfter;
    final header = response.headers['retry-after'];
    if (header != null) {
      final seconds = int.tryParse(header);
      if (seconds != null && seconds >= 0 && seconds <= 315360000) {
        retryAfter = DateTime.now().toUtc().add(Duration(seconds: seconds));
      } else {
        try {
          retryAfter = HttpDate.parse(header);
        } on FormatException {
          /* Invalid hint. */
        }
      }
    }
    try {
      return AppFailure.fromJson(
        jsonDecode(response.body),
        httpStatus: response.statusCode,
        retryAfter: retryAfter,
      );
    } on FormatException {
      final status = response.statusCode;
      final code = status == 401
          ? 'AUTH_REQUIRED'
          : status == 429
          ? 'RATE_LIMITED'
          : status >= 500
          ? 'SERVER_ERROR'
          : 'HTTP_ERROR';
      return AppFailure(
        code,
        'api.networkError',
        retryable: status == 429 || status >= 500,
        httpStatus: status,
        retryAfter: retryAfter,
      );
    }
  }
}
