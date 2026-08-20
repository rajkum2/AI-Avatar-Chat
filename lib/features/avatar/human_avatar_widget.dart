import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'avatar_controller.dart';
import 'avatar_data.dart';
import 'avatar_selection_screen.dart';

/// Human-like avatar widget with expressions and lip-sync
class HumanAvatarWidget extends ConsumerStatefulWidget {
  const HumanAvatarWidget({super.key});

  @override
  ConsumerState<HumanAvatarWidget> createState() => _HumanAvatarWidgetState();
}

class _HumanAvatarWidgetState extends ConsumerState<HumanAvatarWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _breathingController;
  late AnimationController _blinkingController;
  late AnimationController _speakingController;
  late AnimationController _expressionController;

  // Lip sync
  double _mouthOpenness = 0.0;
  StreamSubscription? _lipSyncSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _subscribeToLipSync();
  }

  void _initAnimations() {
    // Breathing animation (subtle scale pulse)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breathingController.repeat(reverse: true);

    // Blinking animation (quick opacity change)
    _blinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Speaking/mouth animation
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // Expression transitions
    _expressionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _subscribeToLipSync() {
    // Listen to the lip sync stream directly
    final subscription = ref.read(avatarConfigProvider.notifier).lipSyncStream.listen((data) {
      if (data != null && mounted) {
        setState(() {
          _mouthOpenness = data.intensity.clamp(0.0, 1.0);
        });
      }
    });
    _lipSyncSubscription = subscription;
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _blinkingController.dispose();
    _speakingController.dispose();
    _expressionController.dispose();
    _lipSyncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(avatarConfigProvider);
    final expression = ref.watch(avatarExpressionProvider);
    final isHuman = config.character.isHuman;

    if (!isHuman) {
      // Fall back to original Lottie avatar for robot
      return const _LottieAvatarFallback();
    }

    return GestureDetector(
      onTap: () => _showAvatarSelection(context),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathingController,
          _blinkingController,
          _expressionController,
        ]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              _buildGlow(config),

              // Main avatar
              _buildAvatarBody(config, expression),

              // Selection hint
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                  onPressed: () => _showAvatarSelection(context),
                  tooltip: 'Change avatar',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlow(AvatarConfig config) {
    final color = config.character.gender.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const [0.3, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildAvatarBody(AvatarConfig config, AvatarExpression expression) {
    final breathingScale = config.enableBreathing
        ? 1.0 + (_breathingController.value * 0.02)
        : 1.0;

    return Transform.scale(
      scale: breathingScale * config.scale,
      child: Container(
        width: 200,
        height: 240,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              config.character.gender.color.withValues(alpha: 0.3),
              config.character.gender.color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: config.character.gender.color.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Face background
            _buildFace(config),

            // Eyes
            Positioned(
              top: 70,
              child: _buildEyes(config, expression),
            ),

            // Mouth (with lip sync)
            Positioned(
              bottom: 70,
              child: _buildMouth(config, expression),
            ),

            // Expression indicator
            Positioned(
              bottom: 20,
              child: _buildExpressionBadge(expression),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFace(AvatarConfig config) {
    return Container(
      width: 160,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: config.character.gender.color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildEyes(AvatarConfig config, AvatarExpression expression) {
    final eyeColor = Colors.black87;
    final isBlinking = _blinkingController.isAnimating;

    // Expression-based eye shapes
    Widget leftEye = _buildSingleEye(
      color: eyeColor,
      isBlinking: isBlinking,
      expression: expression,
    );

    Widget rightEye = _buildSingleEye(
      color: eyeColor,
      isBlinking: isBlinking,
      expression: expression,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leftEye,
        const SizedBox(width: 30),
        rightEye,
      ],
    );
  }

  Widget _buildSingleEye({
    required Color color,
    required bool isBlinking,
    required AvatarExpression expression,
  }) {
    double eyeOpenness = isBlinking ? 0.1 : 1.0;

    // Adjust eye shape based on expression
    switch (expression) {
      case AvatarExpression.happy:
        return _buildHappyEye(color, eyeOpenness);
      case AvatarExpression.surprised:
        return _buildSurprisedEye(color, eyeOpenness);
      case AvatarExpression.thinking:
        return _buildThinkingEye(color, eyeOpenness);
      case AvatarExpression.concerned:
        return _buildConcernedEye(color, eyeOpenness);
      default:
        return _buildNormalEye(color, eyeOpenness);
    }
  }

  Widget _buildNormalEye(Color color, double openness) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 24,
      height: 24 * openness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildHappyEye(Color color, double openness) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 24,
      height: 12 * openness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildSurprisedEye(Color color, double openness) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 28,
      height: 28 * openness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildThinkingEye(Color color, double openness) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 24,
      height: 8 * openness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildConcernedEye(Color color, double openness) {
    return Transform.rotate(
      angle: -0.2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 22,
        height: 18 * openness,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    );
  }

  Widget _buildMouth(AvatarConfig config, AvatarExpression expression) {
    // Base mouth shape
    double width = 40;
    double height = expression == AvatarExpression.speaking
        ? 20 + (_mouthOpenness * 30)  // Lip sync affects height
        : _getMouthHeightForExpression(expression);

    BorderRadius borderRadius = _getMouthShapeForExpression(expression);
    Color mouthColor = expression == AvatarExpression.speaking
        ? const Color(0xFFCC6666)  // Open mouth color
        : const Color(0xFF996666); // Closed mouth color

    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: mouthColor,
        borderRadius: borderRadius,
      ),
    );
  }

  double _getMouthHeightForExpression(AvatarExpression expression) {
    switch (expression) {
      case AvatarExpression.happy:
        return 15;
      case AvatarExpression.surprised:
        return 25;
      case AvatarExpression.thinking:
        return 8;
      case AvatarExpression.concerned:
        return 12;
      case AvatarExpression.speaking:
        return 20;
      default:
        return 10;
    }
  }

  BorderRadius _getMouthShapeForExpression(AvatarExpression expression) {
    switch (expression) {
      case AvatarExpression.happy:
        return const BorderRadius.vertical(
          top: Radius.circular(5),
          bottom: Radius.circular(15),
        );
      case AvatarExpression.surprised:
        return BorderRadius.circular(15);
      case AvatarExpression.thinking:
        return BorderRadius.circular(4);
      default:
        return BorderRadius.circular(10);
    }
  }

  Widget _buildExpressionBadge(AvatarExpression expression) {
    IconData icon;
    String label;
    Color color;

    switch (expression) {
      case AvatarExpression.listening:
        icon = Icons.mic;
        label = 'Listening';
        color = Colors.red;
      case AvatarExpression.thinking:
        icon = Icons.psychology;
        label = 'Thinking';
        color = Colors.orange;
      case AvatarExpression.speaking:
        icon = Icons.record_voice_over;
        label = 'Speaking';
        color = AppColors.primary;
      case AvatarExpression.happy:
        icon = Icons.sentiment_satisfied;
        label = 'Happy';
        color = Colors.green;
      case AvatarExpression.surprised:
        icon = Icons.sentiment_very_satisfied;
        label = 'Surprised';
        color = Colors.purple;
      default:
        icon = Icons.sentiment_neutral;
        label = 'Idle';
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarSelectionScreen(),
      ),
    );
  }
}

/// Fallback to original Lottie avatar for robot/non-human
class _LottieAvatarFallback extends StatelessWidget {
  const _LottieAvatarFallback();

  @override
  Widget build(BuildContext context) {
    // Import and use the original avatar_widget
    return const Center(
      child: Icon(
        Icons.smart_toy,
        size: 120,
        color: Colors.white54,
      ),
    );
  }
}
