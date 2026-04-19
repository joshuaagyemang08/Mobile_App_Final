import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class BackendApi {
  BackendApi._();

  static Uri _uri(String path) {
    final base = ApiConstants.backendBaseUrl.endsWith('/')
        ? ApiConstants.backendBaseUrl.substring(0, ApiConstants.backendBaseUrl.length - 1)
        : ApiConstants.backendBaseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }

  static Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: _headers(token: token),
    );
    return _decodeResponse(response);
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode >= 400 && payload['message'] == null) {
      payload['message'] = 'Request failed with status ${response.statusCode}.';
    }
    return payload;
  }
}
