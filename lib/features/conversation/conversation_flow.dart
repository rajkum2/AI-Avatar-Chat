import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/env.dart';
import 'conversation_state.dart';
import '../avatar/avatar_controller.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import '../chat/chat_service.dart';
import '../chat/chat_provider.dart';

final conversationStateProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  return ConversationNotifier(ref);
});

final transcriptProvider = StateProvider<String>((ref) => '');

final aiResponseProvider = StateProvider<String>((ref) => '');

// Provides error messages for SnackBar display
final errorMessageProvider = StateProvider<String>((ref) => '');

class ConversationNotifier extends StateNotifier<ConversationState> {
  final Ref _ref;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _finalResultSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<void>? _ttsCompletionSub;
  bool _processingResult = false;

  ConversationNotifier(this._ref) : super(ConversationState.idle);

  void _updateAvatarState() {
    _ref.read(avatarStateProvider.notifier).updateFromConversation(state);
  }

  void _showError(String message) {
    _ref.read(errorMessageProvider.notifier).state = message;
  }

  Future<void> startListening() async {
    if (state == ConversationState.speaking) {
      await interrupt();
      return;
    }

    if (state != ConversationState.idle) return;

    final sttService = _ref.read(sttServiceProvider);

    // Initialize on first use
    if (!sttService.isInitialized) {
      final available = await sttService.initialize();
      if (!available) {
        if (kIsWeb) {
          _showError('Browser not supported — please use Chrome');
        } else {
          _showError('Microphone not available');
        }
        return;
      }
    }

    if (!sttService.isAvailable) {
      _showError('Microphone not available');
      return;
    }

    state = ConversationState.listening;
    _updateAvatarState();
    _ref.read(transcriptProvider.notifier).state = '';
    _processingResult = false;

    // Listen for partial transcripts
    _transcriptSub?.cancel();
    _transcriptSub = sttService.transcriptStream.listen((text) {
      if (state == ConversationState.listening) {
        _ref.read(transcriptProvider.notifier).state = text;
      }
    });

    // Listen for final result
    _finalResultSub?.cancel();
    _finalResultSub = sttService.finalResultStream.listen((finalText) {
      if (!_processingResult) {
        _processingResult = true;
        _onSpeechResult(finalText);
      }
    });

    // Listen for STT errors
    _errorSub?.cancel();
    _errorSub = sttService.errorStream.listen((errorMsg) {
      _showError(errorMsg);
      if (state == ConversationState.listening) {
        _cancelListenSubscriptions();
        state = ConversationState.idle;
        _updateAvatarState();
      }
    });

    await sttService.startListening();
  }

  Future<void> stopListening() async {
    if (state != ConversationState.listening) return;

    final sttService = _ref.read(sttServiceProvider);
    await sttService.stop();

    // Give a brief moment for the final result callback to fire
    await Future.delayed(const Duration(milliseconds: 200));

    // If no final result was processed, use the current partial transcript
    if (!_processingResult) {
      _processingResult = true;
      final transcript = _ref.read(transcriptProvider);
      _onSpeechResult(transcript);
    }
  }

  Future<void> _onSpeechResult(String transcript) async {
    _cancelListenSubscriptions();

    if (transcript.trim().isEmpty) {
      _ref.read(transcriptProvider.notifier).state = '';
      _showError("Couldn't hear you — please try again");
      state = ConversationState.idle;
      _updateAvatarState();
      return;
    }

    // Check API key before making the call
    if (!Env.hasAnthropicKey) {
      _showError('API key not configured — add ANTHROPIC_API_KEY to .env');
      state = ConversationState.idle;
      _updateAvatarState();
      return;
    }

    // Transition to THINKING
    state = ConversationState.thinking;
    _updateAvatarState();

    try {
      final chatService = _ref.read(chatServiceProvider);
      final history = _ref.read(chatHistoryProvider);

      // Add user message to history before sending
      _ref.read(chatHistoryProvider.notifier).addUserMessage(transcript);

      String reply;
      try {
        reply = await chatService.sendMessage(transcript, history);
      } on ChatRateLimitException {
        _ref.read(transcriptProvider.notifier).state =
            'Give me a moment...';
        await Future.delayed(const Duration(seconds: 2));
        reply = await chatService.sendMessage(transcript, history);
      }

      // Store AI response
      _ref.read(chatHistoryProvider.notifier).addAssistantMessage(reply);
      _ref.read(aiResponseProvider.notifier).state = reply;
      _ref.read(transcriptProvider.notifier).state = reply;

      // Transition to SPEAKING
      state = ConversationState.speaking;
      _updateAvatarState();

      final ttsService = _ref.read(ttsServiceProvider);

      // Listen for TTS completion
      _ttsCompletionSub?.cancel();
      _ttsCompletionSub = ttsService.onComplete.listen((_) {
        if (state == ConversationState.speaking) {
          state = ConversationState.idle;
          _updateAvatarState();
          _ttsCompletionSub?.cancel();
        }
      });

      await ttsService.speak(reply);
    } on ChatException catch (e) {
      _showError(e.message);
      _ref.read(transcriptProvider.notifier).state = '';
      state = ConversationState.idle;
      _updateAvatarState();
    } catch (e) {
      debugPrint('Conversation error: $e');
      _showError('Something went wrong — please try again');
      _ref.read(transcriptProvider.notifier).state = '';
      state = ConversationState.idle;
      _updateAvatarState();
    }
  }

  Future<void> interrupt() async {
    if (state != ConversationState.speaking) return;

    final ttsService = _ref.read(ttsServiceProvider);
    await ttsService.stop();
    _ttsCompletionSub?.cancel();

    // Reset to idle first, then start listening
    state = ConversationState.idle;
    _updateAvatarState();

    await startListening();
  }

  void resetToIdle() {
    _cancelListenSubscriptions();
    _ttsCompletionSub?.cancel();
    _processingResult = false;

    // Stop any active STT or TTS
    _ref.read(sttServiceProvider).stop();
    _ref.read(ttsServiceProvider).stop();

    _ref.read(transcriptProvider.notifier).state = '';
    state = ConversationState.idle;
    _updateAvatarState();
  }

  void _cancelListenSubscriptions() {
    _transcriptSub?.cancel();
    _finalResultSub?.cancel();
    _errorSub?.cancel();
  }

  @override
  void dispose() {
    _cancelListenSubscriptions();
    _ttsCompletionSub?.cancel();
    super.dispose();
  }
}
