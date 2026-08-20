import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../conversation/conversation_state.dart';
import 'avatar_data.dart';

import 'avatar_state.dart';

/// Provider for avatar state (idle, listening, speaking, thinking)
final avatarStateProvider = StateNotifierProvider<AvatarStateNotifier, AvatarState>((ref) {
  return AvatarStateNotifier();
});

/// Provider for avatar configuration
final avatarConfigProvider = StateNotifierProvider<AvatarConfigNotifier, AvatarConfig>((ref) {
  return AvatarConfigNotifier();
});

/// Provider for current expression
final avatarExpressionProvider = StateProvider<AvatarExpression>((ref) => AvatarExpression.neutral);

/// Provider for lip sync data stream
final lipSyncProvider = StreamProvider<LipSyncData?>((ref) {
  return ref.watch(avatarConfigProvider.notifier).lipSyncStream;
});

/// Simple state notifier for avatar state
class AvatarStateNotifier extends StateNotifier<AvatarState> {
  AvatarStateNotifier() : super(AvatarState.idle);

  void updateFromConversation(ConversationState conversationState) {
    state = switch (conversationState) {
      ConversationState.idle => AvatarState.idle,
      ConversationState.listening => AvatarState.listening,
      ConversationState.thinking => AvatarState.thinking,
      ConversationState.speaking => AvatarState.speaking,
    };
  }
}

/// Controller for avatar animations and state
class AvatarConfigNotifier extends StateNotifier<AvatarConfig> {
  AvatarConfigNotifier() : super(const AvatarConfig());

  final _lipSyncController = StreamController<LipSyncData?>.broadcast();
  Stream<LipSyncData?> get lipSyncStream => _lipSyncController.stream;

  Timer? _blinkTimer;
  Timer? _breathingTimer;
  bool _isSpeaking = false;

  /// Select a different avatar character
  void selectCharacter(AvatarCharacter character) {
    state = state.copyWith(character: character);
    debugPrint('Avatar: Selected ${character.displayName}');
  }

  /// Update expression
  void setExpression(AvatarExpression expression) {
    state = state.copyWith(expression: expression);
  }

  /// Update from conversation state
  void updateFromConversation(ConversationState conversationState) {
    switch (conversationState) {
      case ConversationState.idle:
        if (_isSpeaking) {
          _stopSpeaking();
        }
        setExpression(AvatarExpression.neutral);
        _startIdleAnimations();
        break;
      case ConversationState.listening:
        if (_isSpeaking) {
          _stopSpeaking();
        }
        setExpression(AvatarExpression.listening);
        _startIdleAnimations();
        break;
      case ConversationState.thinking:
        if (_isSpeaking) {
          _stopSpeaking();
        }
        setExpression(AvatarExpression.thinking);
        _stopIdleAnimations();
        break;
      case ConversationState.speaking:
        setExpression(AvatarExpression.speaking);
        _startSpeaking();
        _startIdleAnimations();
        break;
    }
  }

  /// Start speaking with lip sync
  void _startSpeaking() {
    _isSpeaking = true;
    _startLipSyncSimulation();
  }

  /// Stop speaking
  void _stopSpeaking() {
    _isSpeaking = false;
    _lipSyncController.add(null);
  }

  /// Simulate lip sync data (replace with actual TTS analysis)
  void _startLipSyncSimulation() {
    if (!state.enableLipSync) return;

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isSpeaking) {
        timer.cancel();
        return;
      }

      // Generate random viseme data for simulation
      // In production, this would come from TTS phoneme analysis
      final visemes = List<double>.filled(Viseme.values.length, 0.0);
      final activeViseme = math.Random().nextInt(Viseme.values.length);
      visemes[activeViseme] = 0.5 + math.Random().nextDouble() * 0.5;

      _lipSyncController.add(LipSyncData(
        visemeValues: visemes,
        intensity: 0.5 + math.Random().nextDouble() * 0.5,
        timestamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }

  /// Start idle animations (blinking, breathing)
  void _startIdleAnimations() {
    if (state.enableBlinking && _blinkTimer == null) {
      _startBlinking();
    }
    if (state.enableBreathing && _breathingTimer == null) {
      _startBreathing();
    }
  }

  /// Stop idle animations
  void _stopIdleAnimations() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _breathingTimer?.cancel();
    _breathingTimer = null;
  }

  /// Blink animation
  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(
      Duration(milliseconds: 3000 + math.Random().nextInt(2000)),
      (_) => _triggerBlink(),
    );
  }

  void _triggerBlink() {
    // Blink signal would be sent to the avatar widget
    debugPrint('Avatar: Blink');
  }

  /// Breathing animation
  void _startBreathing() {
    _breathingTimer?.cancel();
    _breathingTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) => _triggerBreath(),
    );
  }

  void _triggerBreath() {
    // Breathing signal would be sent to the avatar widget
    debugPrint('Avatar: Breathe');
  }

  /// Toggle features
  void toggleLipSync(bool enabled) {
    state = state.copyWith(enableLipSync: enabled);
  }

  void toggleBlinking(bool enabled) {
    state = state.copyWith(enableBlinking: enabled);
    if (enabled) {
      _startBlinking();
    } else {
      _blinkTimer?.cancel();
      _blinkTimer = null;
    }
  }

  void toggleBreathing(bool enabled) {
    state = state.copyWith(enableBreathing: enabled);
    if (enabled) {
      _startBreathing();
    } else {
      _breathingTimer?.cancel();
      _breathingTimer = null;
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathingTimer?.cancel();
    _lipSyncController.close();
    super.dispose();
  }
}

/// Provider to check if avatar is human-like
final isHumanAvatarProvider = Provider<bool>((ref) {
  return ref.watch(avatarConfigProvider).character.isHuman;
});
