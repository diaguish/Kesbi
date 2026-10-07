import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_gateway.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, [this.body]);
  final int statusCode;
  final String? body;

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

  Future<Map<String, dynamic>> getJson(String path) async {
    final jwt = await token();
    final response = await _client
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Accept': 'application/json',
            if (jwt != null) 'Authorization': 'Bearer $jwt',
          },
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final gateway = ref.watch(authGatewayProvider);
  return ApiClient(baseUrl: AppConfig.apiBaseUrl, token: gateway.accessToken);
});
