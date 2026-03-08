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

    if (transcript.isEmpty && conversationState != ConversationState.thinking) {
      return const SizedBox.shrink();
    }

    final String displayText;
    final Color textColor;
    final FontStyle fontStyle;

    switch (conversationState) {
      case ConversationState.idle:
        // Show last transcript briefly (AI response lingers)
        displayText = transcript;
        textColor = AppColors.accent;
        fontStyle = FontStyle.normal;
      case ConversationState.listening:
        // Live user speech — white
        displayText = transcript;
        textColor = AppColors.textPrimary;
        fontStyle = FontStyle.normal;
      case ConversationState.thinking:
        // Show what user said while waiting
        displayText = transcript.isNotEmpty ? '"$transcript"' : '';
        textColor = AppColors.textSecondary;
        fontStyle = FontStyle.italic;
      case ConversationState.speaking:
        // AI response text — blue
        displayText = transcript;
        textColor = AppColors.accent;
        fontStyle = FontStyle.normal;
    }

    if (displayText.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: SingleChildScrollView(
          key: ValueKey('$conversationState-$displayText'),
          reverse: true,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              fontStyle: fontStyle,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
