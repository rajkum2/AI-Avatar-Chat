import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import 'chat_message.dart';

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>((ref) {
  return ChatHistoryNotifier();
});

class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  ChatHistoryNotifier() : super([]);

  void addUserMessage(String content) {
    state = [...state, ChatMessage.user(content)];
    _trimIfNeeded();
  }

  void addAssistantMessage(String content) {
    state = [...state, ChatMessage.assistant(content)];
    _trimIfNeeded();
  }

  void clearHistory() {
    state = [];
  }

  void _trimIfNeeded() {
    if (state.length > AppConstants.maxHistoryMessages) {
      state = state.sublist(state.length - AppConstants.maxHistoryMessages);
    }
  }
}
