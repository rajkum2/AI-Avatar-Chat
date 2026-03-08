class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, String> toApiMap() => {
        'role': role,
        'content': content,
      };

  factory ChatMessage.user(String content) => ChatMessage(
        role: 'user',
        content: content,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.assistant(String content) => ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
      );
}
