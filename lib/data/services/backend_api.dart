import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class BackendApi {
  BackendApi._();
  static const Duration _requestTimeout = Duration(seconds: 15);

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
    ).timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: _headers(token: token),
    ).timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        payload = {
          'success': false,
          'message': 'Server returned an invalid response. Please try again.',
        };
      }
    }

    if (response.statusCode >= 400 && payload['message'] == null) {
      payload['message'] = 'Request failed with status ${response.statusCode}.';
    }
    return payload;
  }
}
