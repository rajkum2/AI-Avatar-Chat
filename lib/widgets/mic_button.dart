import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/conversation_flow.dart';
import '../features/conversation/conversation_state.dart';
import '../core/theme.dart';

class MicButton extends ConsumerStatefulWidget {
  const MicButton({super.key});

  @override
  ConsumerState<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends ConsumerState<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationState = ref.watch(conversationStateProvider);

    // Control pulse animation based on state
    if (conversationState == ConversationState.listening) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    final bool isDisabled = conversationState == ConversationState.thinking;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = conversationState == ConversationState.listening
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: isDisabled ? null : _onTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getBackgroundColor(conversationState),
                border: Border.all(
                  color: _getBorderColor(conversationState),
                  width: 2,
                ),
                boxShadow: conversationState == ConversationState.listening
                    ? [
                        BoxShadow(
                          color: AppColors.active.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
              ),
              child: _buildIcon(conversationState),
            ),
          ),
        );
      },
    );
  }

  void _onTap() {
    final conversationState = ref.read(conversationStateProvider);
    final notifier = ref.read(conversationStateProvider.notifier);

    switch (conversationState) {
      case ConversationState.idle:
        notifier.startListening();
      case ConversationState.listening:
        notifier.stopListening();
      case ConversationState.speaking:
        notifier.interrupt();
      case ConversationState.thinking:
        break;
    }
  }

  Color _getBackgroundColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return Colors.transparent;
      case ConversationState.listening:
        return AppColors.active;
      case ConversationState.thinking:
      case ConversationState.speaking:
        return AppColors.surface;
    }
  }

  Color _getBorderColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.textPrimary;
      case ConversationState.listening:
        return AppColors.active;
      case ConversationState.thinking:
      case ConversationState.speaking:
        return AppColors.textSecondary;
    }
  }

  Widget _buildIcon(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return const Icon(
          Icons.mic,
          color: AppColors.textPrimary,
          size: 36,
        );
      case ConversationState.listening:
        return const Icon(
          Icons.mic,
          color: AppColors.textPrimary,
          size: 36,
        );
      case ConversationState.thinking:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.textSecondary,
            strokeWidth: 2.5,
          ),
        );
      case ConversationState.speaking:
        return const Icon(
          Icons.stop,
          color: AppColors.textSecondary,
          size: 36,
        );
    }
  }
}
