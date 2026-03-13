import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env.dart';
import 'backend_chat_service.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';
export 'chat_service_interface.dart';

/// Unified chat service provider that automatically selects
/// between direct API and backend based on USE_BACKEND flag
final chatServiceProvider = Provider<ChatServiceInterface>((ref) {
  if (Env.useBackend) {
    debugPrint('ChatService: Using backend API');
    return BackendChatService(ref);
  } else {
    debugPrint('ChatService: Using direct API');
    return ChatService();
  }
});

/// Direct API implementation (fallback when not using backend)
class ChatService implements ChatServiceInterface {
  /// Pre-warms the HTTPS connection to Kimi API.
  /// Establishes TLS handshake early so the first real request is faster.
  @override
  Future<void> warmUp() async {
    try {
      if (!Env.hasKimiKey) return;
      final stopwatch = Stopwatch()..start();
      await http.head(Uri.parse('https://api.moonshot.cn')).timeout(
            const Duration(seconds: 5),
          );
      stopwatch.stop();
      debugPrint(
        'Kimi API: Connection warmed in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('Kimi API: Warm-up failed (non-blocking): $e');
    }
  }

  /// Builds the messages array for the API call (OpenAI format).
  /// System prompt goes as the first message with role "system".
  List<Map<String, String>> _buildMessages(
    String userMessage,
    List<ChatMessage> history,
  ) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': AppConstants.systemPrompt},
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    // Validate message alternation (skip system message at index 0)
    for (int i = 2; i < messages.length; i++) {
      if (messages[i]['role'] == messages[i - 1]['role']) {
        debugPrint(
          'Warning: Consecutive ${messages[i]['role']} messages detected, '
          'removing duplicate at index ${i - 1}',
        );
        messages.removeAt(i - 1);
        i--;
      }
    }

    return messages;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Env.kimiApiKey}',
      };

  /// Streams text chunks from Kimi API using SSE (OpenAI-compatible format).
  @override
  Stream<String> streamMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async* {
    final apiKey = Env.kimiApiKey;
    if (apiKey.isEmpty) {
      throw ChatException(
        'API key not configured — add KIMI_API_KEY to .env',
      );
    }

    final messages = _buildMessages(userMessage, history);

    final body = jsonEncode({
      'model': AppConstants.kimiModel,
      'max_tokens': AppConstants.kimiMaxTokens,
      'messages': messages,
      'stream': true,
    });

    debugPrint('Kimi API: Streaming ${messages.length} messages');
    final stopwatch = Stopwatch()..start();
    bool firstChunk = true;

    final client = http.Client();
    try {
      final request =
          http.Request('POST', Uri.parse(AppConstants.kimiApiUrl));
      request.headers.addAll(_headers);
      request.body = body;

      final response = await client
          .send(request)
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode != 200) {
        final errorBody = await response.stream
            .transform(utf8.decoder)
            .join();
        _handleErrorResponse(response.statusCode, errorBody);
      }

      // Parse SSE stream (OpenAI format)
      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6);
          if (data == '[DONE]') break;

          try {
            final event = jsonDecode(data) as Map<String, dynamic>;
            final choices = event['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                if (firstChunk) {
                  firstChunk = false;
                  debugPrint(
                    'Kimi API: First chunk in '
                    '${stopwatch.elapsedMilliseconds}ms',
                  );
                }
                yield content;
              }
            }

            // Log usage if present (final chunk often has it)
            final usage = event['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              debugPrint(
                'Kimi API usage: output=${usage['completion_tokens']}',
              );
            }
          } catch (_) {
            // Skip malformed SSE data lines
          }
        }
      }

      stopwatch.stop();
      debugPrint(
        'Kimi API: Stream complete in ${stopwatch.elapsedMilliseconds}ms',
      );
    } on ChatException {
      rethrow;
    } catch (e) {
      debugPrint('Kimi API stream error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw ChatException('Connection timed out — please try again');
      }
      throw ChatException('Connection lost — check your internet');
    } finally {
      client.close();
    }
  }

  /// Sends a message to Kimi API (non-streaming fallback).
  @override
  Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async {
    final apiKey = Env.kimiApiKey;
    if (apiKey.isEmpty) {
      throw ChatException(
        'API key not configured — add KIMI_API_KEY to .env',
      );
    }

    final messages = _buildMessages(userMessage, history);

    final body = jsonEncode({
      'model': AppConstants.kimiModel,
      'max_tokens': AppConstants.kimiMaxTokens,
      'messages': messages,
    });

    debugPrint('Kimi API: Sending ${messages.length} messages');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.kimiApiUrl),
            headers: _headers,
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      stopwatch.stop();
      debugPrint(
          'Kimi API: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response.statusCode, response.body);
      }
    } on ChatException {
      rethrow;
    } catch (e) {
      debugPrint('Kimi API error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw ChatException('Connection timed out — please try again');
      }
      throw ChatException('Connection lost — check your internet');
    }
  }

  String _parseResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List?;

      if (choices == null || choices.isEmpty) {
        throw ChatException('Empty response from AI');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final text = message?['content'] as String?;

      if (text == null || text.trim().isEmpty) {
        throw ChatException('Empty response from AI');
      }

      // Log usage
      final usage = data['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        debugPrint(
          'Kimi API usage: '
          'input=${usage['prompt_tokens']}, '
          'output=${usage['completion_tokens']}',
        );
      }

      return text.trim();
    } catch (e) {
      if (e is ChatException) rethrow;
      debugPrint('Kimi API parse error: $e');
      throw ChatException('Failed to parse AI response');
    }
  }

  Never _handleErrorResponse(int statusCode, String responseBody) {
    String? apiMessage;
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      apiMessage = error?['message'] as String?;
    } catch (_) {}

    debugPrint('Kimi API error $statusCode: $apiMessage');

    switch (statusCode) {
      case 400:
        throw ChatException(
            'Bad request — ${apiMessage ?? 'invalid input'}');
      case 401:
        throw ChatException('Invalid API key — check your .env file');
      case 403:
        throw ChatException(
            'API access denied — check your API key permissions');
      case 404:
        throw ChatException(
            'API endpoint not found — check configuration');
      case 429:
        throw ChatRateLimitException(
            'AI is busy — trying again in 2 seconds');
      case 500:
        throw ChatException('AI service error — please try again');
      default:
        if (statusCode >= 500) {
          throw ChatException('Something went wrong — please try again');
        }
        throw ChatException('API error ($statusCode)');
    }
  }
}
