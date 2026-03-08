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
  bool _tapping = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
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
    final state = ref.watch(conversationStateProvider);

    // Start/stop pulse for listening state
    if (state == ConversationState.listening) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    const isDisabled = false;

    return Semantics(
      button: true,
      label: _getAccessibilityLabel(state),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = state == ConversationState.listening
              ? _pulseAnimation.value
              : 1.0;

          return Transform.scale(
            scale: scale,
            child: _buildButton(state, isDisabled),
          );
        },
      ),
    );
  }

  Widget _buildButton(ConversationState state, bool isDisabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : _onTap,
        customBorder: const CircleBorder(),
        splashColor: _getSplashColor(state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBackgroundColor(state),
            border: Border.all(
              color: _getBorderColor(state),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _getShadowColor(state),
                blurRadius: state == ConversationState.listening ? 24 : 12,
                spreadRadius: state == ConversationState.listening ? 4 : 1,
              ),
            ],
          ),
          child: Center(child: _buildIcon(state)),
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    if (_tapping) return;
    _tapping = true;

    try {
      final state = ref.read(conversationStateProvider);
      final notifier = ref.read(conversationStateProvider.notifier);

      switch (state) {
        case ConversationState.idle:
          await notifier.startListening();
        case ConversationState.listening:
          await notifier.stopListening();
        case ConversationState.speaking:
          await notifier.interrupt();
        case ConversationState.thinking:
          break;
      }
    } finally {
      _tapping = false;
    }
  }

  Color _getBackgroundColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.surface;
      case ConversationState.listening:
        return AppColors.active;
      case ConversationState.thinking:
        return AppColors.surface;
      case ConversationState.speaking:
        return AppColors.surface;
    }
  }

  Color _getBorderColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.primary.withValues(alpha: 0.6);
      case ConversationState.listening:
        return AppColors.active;
      case ConversationState.thinking:
        return AppColors.surfaceLight;
      case ConversationState.speaking:
        return AppColors.primary.withValues(alpha: 0.4);
    }
  }

  Color _getShadowColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.primary.withValues(alpha: 0.15);
      case ConversationState.listening:
        return AppColors.active.withValues(alpha: 0.4);
      case ConversationState.thinking:
        return Colors.transparent;
      case ConversationState.speaking:
        return AppColors.primary.withValues(alpha: 0.1);
    }
  }

  Color _getSplashColor(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return AppColors.primary.withValues(alpha: 0.2);
      case ConversationState.listening:
        return AppColors.textPrimary.withValues(alpha: 0.15);
      case ConversationState.speaking:
        return AppColors.primary.withValues(alpha: 0.2);
      case ConversationState.thinking:
        return Colors.transparent;
    }
  }

  Widget _buildIcon(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return const Icon(Icons.mic, color: AppColors.textPrimary, size: 32);
      case ConversationState.listening:
        return const Icon(Icons.mic, color: AppColors.textPrimary, size: 32);
      case ConversationState.thinking:
        return const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            color: AppColors.textSecondary,
            strokeWidth: 2.5,
          ),
        );
      case ConversationState.speaking:
        return const Icon(Icons.stop, color: AppColors.accent, size: 32);
    }
  }

  String _getAccessibilityLabel(ConversationState state) {
    switch (state) {
      case ConversationState.idle:
        return 'Start recording';
      case ConversationState.listening:
        return 'Stop recording';
      case ConversationState.thinking:
        return 'Processing, please wait';
      case ConversationState.speaking:
        return 'Interrupt and speak';
    }
  }
}
