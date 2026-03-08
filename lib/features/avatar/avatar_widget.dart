import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme.dart';
import 'avatar_controller.dart';
import 'avatar_state.dart';

class AvatarWidget extends ConsumerStatefulWidget {
  const AvatarWidget({super.key});

  @override
  ConsumerState<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends ConsumerState<AvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _thinkingController;
  AvatarState? _previousState;

  @override
  void initState() {
    super.initState();
    _thinkingController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _thinkingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarState = ref.watch(avatarStateProvider);

    // Stop thinking controller when leaving thinking state
    if (_previousState == AvatarState.thinking &&
        avatarState != AvatarState.thinking) {
      _thinkingController.stop();
      _thinkingController.reset();
    }
    _previousState = avatarState;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = constraints.maxHeight * 0.8;
        final size = maxSize.clamp(200.0, 400.0);

        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              key: ValueKey(avatarState),
              width: size,
              height: size,
              child: _buildAvatar(avatarState),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(AvatarState state) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // State-colored glow behind avatar
        _buildGlow(state),
        // Lottie animation
        _buildAnimation(state),
      ],
    );
  }

  Widget _buildGlow(AvatarState state) {
    final Color glowColor;
    final double glowSize;

    switch (state) {
      case AvatarState.idle:
        glowColor = AppColors.primary;
        glowSize = 0.7;
      case AvatarState.listening:
        glowColor = AppColors.accent;
        glowSize = 0.8;
      case AvatarState.speaking:
        glowColor = AppColors.primary;
        glowSize = 0.75;
      case AvatarState.thinking:
        glowColor = AppColors.textSecondary;
        glowSize = 0.65;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: 60,
            spreadRadius: 20 * glowSize,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimation(AvatarState state) {
    final String assetPath;

    switch (state) {
      case AvatarState.idle:
        assetPath = 'assets/animations/avatar_idle.json';
      case AvatarState.listening:
        assetPath = 'assets/animations/avatar_listen.json';
      case AvatarState.speaking:
        assetPath = 'assets/animations/avatar_speak.json';
      case AvatarState.thinking:
        assetPath = 'assets/animations/avatar_idle.json';
    }

    if (state == AvatarState.thinking) {
      return Lottie.asset(
        assetPath,
        controller: _thinkingController,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          _thinkingController
            ..duration = composition.duration * 2 // Half speed
            ..repeat();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(state);
        },
      );
    }

    return Lottie.asset(
      assetPath,
      animate: true,
      repeat: true,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(state);
      },
    );
  }

  Widget _buildPlaceholder(AvatarState state) {
    final IconData icon;
    final Color color;
    final String label;

    switch (state) {
      case AvatarState.idle:
        icon = Icons.face;
        color = AppColors.primary;
        label = '';
      case AvatarState.listening:
        icon = Icons.hearing;
        color = AppColors.accent;
        label = 'Listening';
      case AvatarState.speaking:
        icon = Icons.record_voice_over;
        color = AppColors.primary;
        label = 'Speaking';
      case AvatarState.thinking:
        icon = Icons.psychology;
        color = AppColors.textSecondary;
        label = 'Thinking';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: state == AvatarState.thinking
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        color: color.withValues(alpha: 0.3),
                        strokeWidth: 2,
                      ),
                    ),
                    Icon(icon, size: 64, color: color),
                  ],
                )
              : Icon(icon, size: 80, color: color),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
