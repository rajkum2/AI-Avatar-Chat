import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme.dart';
import 'avatar_controller.dart';
import 'avatar_state.dart';
import 'human_avatar_widget.dart';

/// Main avatar widget that switches between human and animated styles
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
    final config = ref.watch(avatarConfigProvider);

    // Stop thinking controller when leaving thinking state
    if (_previousState == AvatarState.thinking &&
        avatarState != AvatarState.thinking) {
      _thinkingController.stop();
      _thinkingController.reset();
    }
    _previousState = avatarState;

    // Use human avatar for human characters, Lottie for robot
    if (config.character.isHuman) {
      return const HumanAvatarWidget();
    }

    return _buildLottieAvatar(avatarState);
  }

  Widget _buildLottieAvatar(AvatarState avatarState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = constraints.maxHeight * 0.8;
        final size = maxSize.clamp(200.0, 400.0);

        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: _buildAvatarForState(avatarState, size),
          ),
        );
      },
    );
  }

  Widget _buildAvatarForState(AvatarState state, double size) {
    switch (state) {
      case AvatarState.idle:
        return _buildGlow(
          child: _buildAnimation(
            'assets/animations/avatar_idle.json',
            size,
            key: const ValueKey('idle'),
          ),
          color: AppColors.primary,
        );
      case AvatarState.listening:
        return _buildGlow(
          child: _buildAnimation(
            'assets/animations/avatar_listen.json',
            size,
            key: const ValueKey('listen'),
          ),
          color: AppColors.active,
        );
      case AvatarState.speaking:
        return _buildGlow(
          child: _buildAnimation(
            'assets/animations/avatar_speak.json',
            size,
            key: const ValueKey('speak'),
          ),
          color: AppColors.primary,
        );
      case AvatarState.thinking:
        // Double duration for half-speed effect
        _thinkingController.duration = const Duration(milliseconds: 4000);
        if (!_thinkingController.isAnimating) {
          _thinkingController.repeat();
        }
        return _buildGlow(
          child: _buildAnimation(
            'assets/animations/avatar_idle.json', // Use idle for thinking
            size,
            controller: _thinkingController,
            key: const ValueKey('thinking'),
          ),
          color: AppColors.primary,
        );
    }
  }

  Widget _buildGlow({required Widget child, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAnimation(
    String assetPath,
    double size, {
    AnimationController? controller,
    Key? key,
  }) {
    return Lottie.asset(
      assetPath,
      width: size,
      height: size,
      controller: controller,
      key: key,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(size);
      },
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceLight, width: 2),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: Colors.white54,
        ),
      ),
    );
  }
}

/// Small avatar preview button for the home screen
class AvatarPreviewButton extends ConsumerWidget {
  final VoidCallback? onTap;

  const AvatarPreviewButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(avatarConfigProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              config.character.gender.color.withValues(alpha: 0.8),
              config.character.gender.color.withValues(alpha: 0.4),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            config.character.isHuman ? config.character.gender.icon : Icons.smart_toy,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
