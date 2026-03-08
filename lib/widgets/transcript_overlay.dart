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

    if (transcript.isEmpty &&
        conversationState != ConversationState.thinking) {
      return const SizedBox.shrink();
    }

    final String displayText;
    final Color textColor;
    final FontStyle fontStyle;

    switch (conversationState) {
      case ConversationState.idle:
        displayText = transcript;
        textColor = AppColors.accent;
        fontStyle = FontStyle.normal;
      case ConversationState.listening:
        displayText = transcript;
        textColor = AppColors.textPrimary;
        fontStyle = FontStyle.normal;
      case ConversationState.thinking:
        displayText = transcript.isNotEmpty ? '"$transcript"' : '';
        textColor = AppColors.textSecondary;
        fontStyle = FontStyle.italic;
      case ConversationState.speaking:
        displayText = transcript;
        textColor = AppColors.accent;
        fontStyle = FontStyle.normal;
    }

    if (displayText.isEmpty) return const SizedBox.shrink();

    // Only animate switcher on state changes, not on every partial transcript
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: SingleChildScrollView(
          key: ValueKey(conversationState),
          reverse: true,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              fontStyle: fontStyle,
              height: 1.5,
            ),
            child: Text(
              displayText,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
