import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_gateway.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, [this.body]);
  final int statusCode;
  final String? body;

  /// Message `detail` renvoyé par l'API Django, s'il existe.
  String? get detail {
    try {
      final json = jsonDecode(body ?? '');
      return json is Map && json['detail'] is String ? json['detail'] as String : null;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($statusCode)';
}

/// Client de l'API Django. Joint le JWT Supabase à chaque requête.
class ApiClient {
  ApiClient({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> getJson(String path) =>
      _send('GET', path).then((r) => _decode(r)!);

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) =>
      _send('POST', path, body).then((r) => _decode(r)!);

  Future<void> delete(String path) => _send('DELETE', path);

  Future<http.Response> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final jwt = await token();
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(_timeout),
    ).timeout(_timeout);
    if (response.statusCode >= 300) throw ApiException(response.statusCode, response.body);
    return response;
  }

  static Map<String, dynamic>? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Message affichable pour une erreur réseau ou API.
  static String messageFor(Object error) => switch (error) {
        SocketException() || http.ClientException() =>
          'Pas de connexion internet. Vérifiez votre réseau et réessayez.',
        TimeoutException() => 'Le réseau est trop lent. Réessayez.',
        ApiException(statusCode: 503) =>
          'Service momentanément indisponible. Réessayez plus tard.',
        ApiException(:final detail?) when detail.isNotEmpty => detail,
        _ => 'Une erreur est survenue. Réessayez.',
      };
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final gateway = ref.watch(authGatewayProvider);
  return ApiClient(baseUrl: AppConfig.apiBaseUrl, token: gateway.accessToken);
});
