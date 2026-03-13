import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../settings/llm_settings.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';

/// Self-hosted LLM service via vLLM, TGI, or llama.cpp server
/// OpenAI-compatible API endpoint
class SelfHostedService implements ChatServiceInterface {
  final LLMSettings _settings;
  final http.Client _client = http.Client();

  SelfHostedService(this._settings);

  String get baseUrl => _settings.selfHostedUrl ?? '';
  String get model => _settings.selfHostedModel ?? 'meta-llama/Llama-3.2-3B-Instruct';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  @override
  Future<void> warmUp() async {
    try {
      // Check if server is healthy
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        debugPrint('SelfHosted: Server is healthy');
      }
    } catch (e) {
      debugPrint('SelfHosted: Warm-up check failed (non-blocking): $e');
    }
  }

  @override
  Stream<String> streamMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async* {
    final messages = _buildMessages(userMessage, history);
    
    debugPrint('SelfHosted: Streaming with $model');
    final stopwatch = Stopwatch()..start();
    bool firstChunk = true;

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/v1/chat/completions'),
      );
      
      request.headers.addAll(_headers);
      request.body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': _settings.temperature,
        'max_tokens': _settings.maxTokens,
        'stream': true,
      });

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        _handleErrorResponse(response.statusCode, body);
      }

      // Parse SSE stream (OpenAI format)
      String buffer = '';
      await for (final bytes in response.stream) {
        buffer += utf8.decode(bytes);

        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6);
          if (data == '[DONE]') {
            stopwatch.stop();
            debugPrint(
              'SelfHosted: Stream complete in ${stopwatch.elapsedMilliseconds}ms'
            );
            return;
          }

          try {
            final event = jsonDecode(data) as Map<String, dynamic>;
            final choices = event['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                if (firstChunk) {
                  firstChunk = false;
                  debugPrint(
                    'SelfHosted: First chunk in ${stopwatch.elapsedMilliseconds}ms'
                  );
                }
                yield content;
              }
            }
          } catch (_) {
            // Skip malformed SSE data
          }
        }
      }
    } catch (e) {
      debugPrint('SelfHosted: Stream error: $e');
      if (e is ChatException) rethrow;
      throw ChatException('Self-hosted server error: $e');
    }
  }

  @override
  Future<String> sendMessage(String userMessage, List<ChatMessage> history) async {
    final messages = _buildMessages(userMessage, history);
    
    debugPrint('SelfHosted: Sending to $model');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': _settings.temperature,
          'max_tokens': _settings.maxTokens,
        }),
      ).timeout(const Duration(seconds: 60));

      stopwatch.stop();
      debugPrint('SelfHosted: Response in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          return message?['content'] as String? ?? '';
        }
        return '';
      } else {
        _handleErrorResponse(response.statusCode, response.body);
      }
    } on ChatException {
      rethrow;
    } catch (e) {
      debugPrint('SelfHosted: Request error: $e');
      throw ChatException('Self-hosted server error: $e');
    }
  }

  List<Map<String, String>> _buildMessages(String userMessage, List<ChatMessage> history) {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': 
          'You are a friendly, warm AI assistant embodied as an avatar. '
          'Keep ALL responses to exactly 2-3 sentences maximum because '
          'they will be spoken aloud. Be conversational, natural, and '
          'engaging. Never use bullet points, headers, or markdown in '
          'your replies. Speak as if having a real voice conversation.'
      },
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];
    return messages;
  }

  Never _handleErrorResponse(int statusCode, String body) {
    String message = 'Server error';
    try {
      final data = jsonDecode(body) as Map<String, dynamic>?;
      message = data?['error']?['message'] ?? data?['message'] ?? 'Unknown error';
    } catch (_) {}

    debugPrint('SelfHosted: Error $statusCode: $message');

    switch (statusCode) {
      case 401:
        throw ChatException('Authentication failed - check API key');
      case 429:
        throw ChatRateLimitException('Server is busy - please try again');
      case 503:
        throw ChatException('Server is loading model - please wait');
      case 500:
        throw ChatException('Server error: $message');
      default:
        throw ChatException('Request failed ($statusCode): $message');
    }
  }

  /// Get server status and loaded models
  Future<Map<String, dynamic>> getServerInfo() async {
    try {
      // Try vLLM /models endpoint
      final response = await _client.get(
        Uri.parse('$baseUrl/v1/models'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SelfHosted: Failed to get server info: $e');
    }
    return {};
  }

  void dispose() {
    _client.close();
  }
}
