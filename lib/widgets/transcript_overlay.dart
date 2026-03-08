import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/conversation_flow.dart';
import '../features/conversation/conversation_state.dart';
import '../core/theme.dart';

class TranscriptOverlay extends ConsumerWidget {
  const TranscriptOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(transcriptProvider);
    final conversationState = ref.watch(conversationStateProvider);

    if (transcript.isEmpty) return const SizedBox.shrink();

    final bool isAiText = conversationState == ConversationState.speaking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          transcript,
          style: TextStyle(
            fontSize: 16,
            color: isAiText ? AppColors.accent : AppColors.textPrimary,
            height: 1.4,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}
