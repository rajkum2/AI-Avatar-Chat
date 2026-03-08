import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/conversation_flow.dart';
import '../features/conversation/conversation_state.dart';
import '../core/theme.dart';

class StatusIndicator extends ConsumerWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationStateProvider);

    return SizedBox(
      height: 40,
      child: Center(
        child: Text(
          _getStatusText(state),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _getStatusText(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return 'Tap mic to start';
      case ConversationState.listening:
        return 'Listening...';
      case ConversationState.thinking:
        return 'Thinking...';
      case ConversationState.speaking:
        return 'Speaking...';
    }
  }
}
