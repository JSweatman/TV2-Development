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
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? HttpClient();

  final Uri baseUri;
  final HttpClient _client;
  final Duration timeout;

  Uri _uri(String path, Map<String, String> query) => baseUri.replace(
        path: '${baseUri.path.replaceAll(RegExp(r'/$'), '')}$path',
        queryParameters: query,
      );

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    try {
      final request = await _client.getUrl(_uri(path, query)).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      final raw = await utf8.decoder.bind(response).join().timeout(timeout);
      final decoded = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail'];
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

  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) async =>
      PrefixResponse.fromJson(await _get('/v1/prefix', {
        'input': input,
        'country': country,
        'limit': '$limit',
      }));

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) async =>
      ResolveResponse.fromJson(await _get('/v1/resolve', {
        'input': input,
        'country': country,
      }));
}
