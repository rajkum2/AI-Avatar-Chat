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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(state),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == ConversationState.thinking)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: AppColors.textSecondary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              if (state == ConversationState.listening)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.mic,
                    size: 14,
                    color: AppColors.active,
                  ),
                ),
              Text(
                _getStatusText(state),
                style: TextStyle(
                  fontSize: 14,
                  color: state == ConversationState.listening
                      ? AppColors.active
                      : AppColors.textSecondary,
                ),
              ),
            ],
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
