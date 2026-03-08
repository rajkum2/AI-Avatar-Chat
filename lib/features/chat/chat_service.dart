import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env.dart';
import 'chat_message.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

class ChatService {
  Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async {
    final apiKey = Env.anthropicApiKey;
    if (apiKey.isEmpty) {
      throw ChatException('API key not configured');
    }

    final messages = [
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': AppConstants.claudeModel,
      'max_tokens': AppConstants.claudeMaxTokens,
      'system': AppConstants.systemPrompt,
      'messages': messages,
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.claudeApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': AppConstants.claudeApiVersion,
            },
            body: body,
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List;
        if (content.isEmpty) {
          throw ChatException('Empty response from AI');
        }
        final text = content[0]['text'] as String;
        if (text.trim().isEmpty) {
          throw ChatException('Empty response from AI');
        }
        return text;
      } else if (response.statusCode == 429) {
        throw ChatRateLimitException('Rate limited — retrying...');
      } else {
        throw ChatException(
          'API error: ${response.statusCode}',
        );
      }
    } on ChatException {
      rethrow;
    } catch (e) {
      throw ChatException('Connection lost — check your internet');
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
