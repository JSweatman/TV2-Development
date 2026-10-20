import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class ResolverApiException implements Exception {
  const ResolverApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract class ResolverApi {
  Future<List<CountryNamespace>> countries();

  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  });

  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  });
}

class HttpResolverApi implements ResolverApi {
  HttpResolverApi({
    required this.baseUri,
    HttpClient? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? HttpClient();

  final Uri baseUri;
  final HttpClient _client;
  final Duration timeout;

  Uri _uri(String path, Map<String, String> query) => baseUri.replace(
        path: '${baseUri.path.replaceAll(RegExp(r'/$'), '')}$path',
        queryParameters: query.isEmpty ? null : query,
      );

  Future<dynamic> _getJson(
    String path,
    Map<String, String> query, {
    Duration? requestTimeout,
  }) async {
    final effectiveTimeout = requestTimeout ?? timeout;
    try {
      final request = await _client.getUrl(_uri(path, query)).timeout(effectiveTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(effectiveTimeout);
      final raw = await utf8.decoder.bind(response).join().timeout(effectiveTimeout);
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
        throw ResolverApiException(
          detail is String ? detail : 'Resolver request failed.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ResolverApiException {
      rethrow;
    } on TimeoutException {
      throw const ResolverApiException('Resolver request timed out.');
    } on SocketException {
      throw const ResolverApiException('Resolver is unavailable.');
    } on FormatException {
      throw const ResolverApiException('Resolver returned an invalid response.');
    }
  }

  Future<Map<String, dynamic>> _getMap(
    String path,
    Map<String, String> query,
  ) async {
    final decoded = await _getJson(path, query);
    if (decoded is! Map<String, dynamic>) {
      throw const ResolverApiException('Resolver returned an invalid response.');
    }
    return decoded;
  }

  @override
  Future<List<CountryNamespace>> countries() async {
    // Render's free-tier instance may need longer than the normal lookup
    // timeout to wake from inactivity on the first country-list request.
    final decoded = await _getJson(
      '/v1/countries',
      const {},
      requestTimeout: const Duration(seconds: 40),
    );
    if (decoded is! List<dynamic>) {
      throw const ResolverApiException('Resolver returned an invalid country list.');
    }
    return decoded
        .map((item) => CountryNamespace.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) async =>
      PrefixResponse.fromJson(await _getMap('/v1/prefix', {
        'input': input,
        'country': country,
        'limit': '$limit',
      }));

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) async =>
      ResolveResponse.fromJson(await _getMap('/v1/resolve', {
        'input': input,
        'country': country,
      }));
}
