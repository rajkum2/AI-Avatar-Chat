import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'env.dart';

/// HTTP client for backend API communication
/// Handles authentication, retries, and error handling
class ApiClient {
  final http.Client _client = http.Client();
  String? _authToken;
  String _baseUrl;

  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? Env.backendUrl;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _authToken != null;

  void setBaseUrl(String url) {
    _baseUrl = url;
    debugPrint('ApiClient: Base URL set to $url');
  }

  void setAuthToken(String token) {
    _authToken = token;
    debugPrint('ApiClient: Auth token set');
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Create a new session and store the token
  Future<void> createSession() async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/auth/session'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'] as String?;
        debugPrint('ApiClient: Session created');
      } else {
        throw ApiException('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiClient: Session creation failed: $e');
      // Continue without auth (anonymous mode)
    }
  }

  /// GET request
  Future<ApiResponse> get(String path) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  /// POST request
  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  /// DELETE request
  Future<ApiResponse> delete(String path) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out');
    } catch (e) {
      throw ApiException('Request failed: $e');
    }
  }

  /// POST request with streaming response (Server-Sent Events)
  Stream<String> postStream(String path, {Map<String, dynamic>? body}) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl$path'));
    request.headers.addAll(_headers);
    request.headers['Accept'] = 'text/event-stream';
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw ApiException('Stream request failed: ${response.statusCode}');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      yield chunk;
    }
  }

  ApiResponse _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse(
        statusCode: response.statusCode,
        body: body,
        headers: response.headers,
      );
    }

    // Handle error responses
    final errorMessage = body?['error'] ?? 'Request failed';
    
    if (response.statusCode == 401) {
      _authToken = null; // Clear invalid token
      throw ApiAuthException(errorMessage);
    }
    if (response.statusCode == 429) {
      throw ApiRateLimitException(errorMessage);
    }
    if (response.statusCode >= 500) {
      throw ApiServerException(errorMessage);
    }
    
    throw ApiException(errorMessage);
  }

  void dispose() {
    _client.close();
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;

  ApiResponse({
    required this.statusCode,
    this.body,
    required this.headers,
  });
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => message;
}

class ApiAuthException extends ApiException {
  ApiAuthException(super.message);
}

class ApiRateLimitException extends ApiException {
  ApiRateLimitException(super.message);
}

class ApiServerException extends ApiException {
  ApiServerException(super.message);
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException([this.message = 'Request timed out']);
  
  @override
  String toString() => message;
}
