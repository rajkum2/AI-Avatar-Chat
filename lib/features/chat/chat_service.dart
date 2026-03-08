import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env.dart';
import 'chat_message.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

class ChatService {
  /// Sends a message to Claude API.
  ///
  /// [userMessage] is the new user text to send.
  /// [history] should be the existing history BEFORE adding the new user message.
  /// The method builds the messages array as: history + new user message.
  Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async {
    final apiKey = Env.anthropicApiKey;
    if (apiKey.isEmpty) {
      throw ChatException(
        'API key not configured — add ANTHROPIC_API_KEY to .env',
      );
    }

    // Build messages array: existing history + new user message
    final messages = <Map<String, String>>[
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    // Validate message alternation — Claude requires user/assistant alternation
    if (messages.length >= 2) {
      for (int i = 1; i < messages.length; i++) {
        if (messages[i]['role'] == messages[i - 1]['role']) {
          // Remove duplicate consecutive same-role messages (keep latest)
          debugPrint(
            'Warning: Consecutive ${messages[i]['role']} messages detected, '
            'removing duplicate at index ${i - 1}',
          );
          messages.removeAt(i - 1);
          i--;
        }
      }
    }

    // First message must be from user
    if (messages.isNotEmpty && messages.first['role'] != 'user') {
      messages.removeAt(0);
    }

    final body = jsonEncode({
      'model': AppConstants.claudeModel,
      'max_tokens': AppConstants.claudeMaxTokens,
      'system': AppConstants.systemPrompt,
      'messages': messages,
    });

    debugPrint('Claude API: Sending ${messages.length} messages');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.claudeApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': AppConstants.claudeApiVersion,
              // Required for browser-based requests
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      stopwatch.stop();
      debugPrint('Claude API: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        _handleErrorResponse(response.statusCode, response.body);
      }
    } on ChatException {
      rethrow;
    } catch (e) {
      debugPrint('Claude API error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw ChatException('Connection timed out — please try again');
      }
      throw ChatException('Connection lost — check your internet');
    }
  }

  String _parseResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = data['content'] as List?;

      if (content == null || content.isEmpty) {
        throw ChatException('Empty response from AI');
      }

      final firstBlock = content[0] as Map<String, dynamic>;
      final text = firstBlock['text'] as String?;

      if (text == null || text.trim().isEmpty) {
        throw ChatException('Empty response from AI');
      }

      // Log usage for debugging
      final usage = data['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        debugPrint(
          'Claude API usage: '
          'input=${usage['input_tokens']}, '
          'output=${usage['output_tokens']}',
        );
      }

      return text.trim();
    } catch (e) {
      if (e is ChatException) rethrow;
      debugPrint('Claude API parse error: $e');
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

    debugPrint('Claude API error $statusCode: $apiMessage');

    switch (statusCode) {
      case 400:
        throw ChatException('Bad request — ${apiMessage ?? 'invalid input'}');
      case 401:
        throw ChatException('Invalid API key — check your .env file');
      case 403:
        throw ChatException('API access denied — check your API key permissions');
      case 404:
        throw ChatException('API endpoint not found — check configuration');
      case 429:
        throw ChatRateLimitException('Claude is busy — trying again in 2 seconds');
      case 500:
        throw ChatException('AI service error — please try again');
      case 529:
        throw ChatException('AI service overloaded — please try again later');
      default:
        if (statusCode >= 500) {
          throw ChatException('Something went wrong — please try again');
        }
        throw ChatException('API error ($statusCode)');
    }
  }
}

class ChatException implements Exception {
  final String message;
  ChatException(this.message);

  @override
  String toString() => message;
}

class ChatRateLimitException extends ChatException {
  ChatRateLimitException(super.message);
}
