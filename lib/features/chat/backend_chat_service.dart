import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';

/// Chat service that uses the backend API instead of direct API calls
/// More secure - API keys are never exposed to the frontend
class BackendChatService implements ChatServiceInterface {
  // ignore: unused_field
  final Ref _ref;
  late final ApiClient _apiClient;
  bool _initialized = false;

  BackendChatService(this._ref) {
    _apiClient = ApiClient();
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    // Create a session with the backend
    await _apiClient.createSession();
    _initialized = true;
    debugPrint('BackendChatService: Initialized');
  }

  /// Warm up the backend connection
  @override
  Future<void> warmUp() async {
    try {
      final response = await _apiClient.get('/api/health');
      if (response.statusCode == 200) {
        debugPrint('BackendChatService: Connection warmed up');
      }
    } catch (e) {
      debugPrint('BackendChatService: Warm-up failed: $e');
    }
  }

  /// Send a message and get streaming response
  @override
  Stream<String> streamMessage(String message, List<ChatMessage> history) async* {
    if (!_initialized) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();
    debugPrint('BackendChatService: Sending message');

    try {
      final stream = _apiClient.postStream(
        '/api/chat',
        body: {
          'message': message,
          'stream': true,
        },
      );

      String buffer = '';
      await for (final chunk in stream) {
        buffer += chunk;
        
        // Process SSE format
        final lines = buffer.split('\n');
        buffer = lines.last; // Keep incomplete line in buffer
        
        for (final line in lines.take(lines.length - 1)) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              stopwatch.stop();
              debugPrint(
                'BackendChatService: Stream complete in '
                '${stopwatch.elapsedMilliseconds}ms'
              );
              return;
            }
            
            try {
              final parsed = jsonDecode(data);
              final textChunk = parsed['chunk'] as String?;
              if (textChunk != null) {
                yield textChunk;
              }
              
              final error = parsed['error'] as String?;
              if (error != null) {
                throw ChatException(error);
              }
            } catch (e) {
              if (e is ChatException) rethrow;
              // Ignore parse errors for malformed chunks
            }
          }
        }
      }
    } on ApiRateLimitException {
      throw ChatRateLimitException('Rate limit exceeded, please try again');
    } on ApiAuthException catch (e) {
      throw ChatException('Session expired: ${e.message}');
    } on ApiServerException catch (e) {
      throw ChatException('Server error: ${e.message}');
    } catch (e) {
      debugPrint('BackendChatService: Stream error: $e');
      throw ChatException('Failed to get response: $e');
    }
  }

  /// Non-streaming message (fallback)
  @override
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final response = await _apiClient.post(
        '/api/chat',
        body: {
          'message': message,
          'stream': false,
        },
      );

      return response.body?['response'] ?? '';
    } on ApiRateLimitException {
      throw ChatRateLimitException('Rate limit exceeded');
    } catch (e) {
      throw ChatException('Request failed: $e');
    }
  }

  /// Get conversation history from server
  Future<List<ChatMessage>> getHistory() async {
    if (!_initialized) return [];

    try {
      final response = await _apiClient.get('/api/history');
      final history = response.body?['history'] as List<dynamic>? ?? [];
      
      return history.map((m) => ChatMessage(
        role: m['role'] as String,
        content: m['content'] as String,
        timestamp: DateTime.now(), // Server doesn't send timestamps
      )).toList();
    } catch (e) {
      debugPrint('BackendChatService: Failed to get history: $e');
      return [];
    }
  }

  /// Clear server-side history
  Future<void> clearHistory() async {
    if (!_initialized) return;

    try {
      await _apiClient.delete('/api/history');
    } catch (e) {
      debugPrint('BackendChatService: Failed to clear history: $e');
    }
  }

  void dispose() {
    _apiClient.dispose();
  }
}
