import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'avatar_controller.dart';
import 'avatar_state.dart';

class AvatarWidget extends ConsumerStatefulWidget {
  const AvatarWidget({super.key});

  @override
  ConsumerState<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends ConsumerState<AvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarState = ref.watch(avatarStateProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxHeight * 0.8;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: SizedBox(
            key: ValueKey(avatarState),
            width: size,
            height: size,
            child: _buildAnimation(avatarState),
          ),
        );
      },
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

    return Lottie.asset(
      assetPath,
      controller: state == AvatarState.thinking ? _animationController : null,
      animate: state != AvatarState.thinking,
      repeat: true,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        if (state == AvatarState.thinking) {
          _animationController
            ..duration = composition.duration * 2 // Half speed
            ..repeat();
        }
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(state);
      },
    );
  }

  Widget _buildPlaceholder(AvatarState state) {
    final IconData icon;
    final Color color;

    switch (state) {
      case AvatarState.idle:
        icon = Icons.face;
        color = const Color(0xFF3B82F6);
      case AvatarState.listening:
        icon = Icons.hearing;
        color = const Color(0xFF60A5FA);
      case AvatarState.speaking:
        icon = Icons.record_voice_over;
        color = const Color(0xFF3B82F6);
      case AvatarState.thinking:
        icon = Icons.psychology;
        color = const Color(0xFF94A3B8);
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(icon, size: 120, color: color),
    );
  }
}
