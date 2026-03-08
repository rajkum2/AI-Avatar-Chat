import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'avatar_controller.dart';
import 'avatar_state.dart';

class AvatarWidget extends ConsumerWidget {
  const AvatarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final bool animate;
    final double speed;

    switch (state) {
      case AvatarState.idle:
        assetPath = 'assets/animations/avatar_idle.json';
        animate = true;
        speed = 1.0;
      case AvatarState.listening:
        assetPath = 'assets/animations/avatar_listen.json';
        animate = true;
        speed = 1.0;
      case AvatarState.speaking:
        assetPath = 'assets/animations/avatar_speak.json';
        animate = true;
        speed = 1.0;
      case AvatarState.thinking:
        assetPath = 'assets/animations/avatar_idle.json';
        animate = true;
        speed = 0.5;
    }

    return Lottie.asset(
      assetPath,
      animate: animate,
      repeat: true,
      fit: BoxFit.contain,
      delegates: LottieDelegates(
        values: [
          if (speed != 1.0)
            ValueDelegate.transformOpacity(
              const ['**'],
              value: (speed * 100).round(),
            ),
        ],
      ),
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
