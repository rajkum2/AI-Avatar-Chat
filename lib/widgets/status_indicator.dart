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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 32,
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
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: AppColors.textSecondary,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                if (state == ConversationState.listening)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.mic,
                      size: 13,
                      color: AppColors.active,
                    ),
                  ),
                if (state == ConversationState.speaking)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.volume_up,
                      size: 13,
                      color: AppColors.accent,
                    ),
                  ),
                Text(
                  _getStatusText(state),
                  style: TextStyle(
                    fontSize: 13,
                    color: _getStatusColor(state),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
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

  Color _getStatusColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.textSecondary;
      case ConversationState.listening:
        return AppColors.active;
      case ConversationState.thinking:
        return AppColors.textSecondary;
      case ConversationState.speaking:
        return AppColors.accent;
    }
  }
}
