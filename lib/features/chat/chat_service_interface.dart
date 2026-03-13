import 'chat_message.dart';

/// Interface for chat services (both direct API and backend)
abstract class ChatServiceInterface {
  Future<void> warmUp();
  Stream<String> streamMessage(String userMessage, List<ChatMessage> history);
  Future<String> sendMessage(String userMessage, List<ChatMessage> history);
}

/// Exception types for chat operations
class ChatException implements Exception {
  final String message;
  ChatException(this.message);

  @override
  String toString() => message;
}

class ChatRateLimitException extends ChatException {
  ChatRateLimitException(super.message);
}
