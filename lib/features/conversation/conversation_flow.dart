import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class ConversationNotifier extends StateNotifier<ConversationState> {
  final Ref _ref;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _finalResultSub;
  StreamSubscription<void>? _ttsCompletionSub;

  ConversationNotifier(this._ref) : super(ConversationState.idle);

  void _updateAvatarState() {
    _ref.read(avatarStateProvider.notifier).updateFromConversation(state);
  }

  Future<void> startListening() async {
    if (state == ConversationState.speaking) {
      await interrupt();
      return;
    }

    if (state != ConversationState.idle) return;

    final sttService = _ref.read(sttServiceProvider);

    if (!sttService.isAvailable) {
      final available = await sttService.initialize();
      if (!available) {
        _ref.read(transcriptProvider.notifier).state =
            'Microphone not available';
        return;
      }
    }

    state = ConversationState.listening;
    _updateAvatarState();
    _ref.read(transcriptProvider.notifier).state = '';

    _transcriptSub?.cancel();
    _transcriptSub = sttService.transcriptStream.listen((text) {
      _ref.read(transcriptProvider.notifier).state = text;
    });

    _finalResultSub?.cancel();
    _finalResultSub = sttService.finalResultStream.listen((finalText) {
      _onSpeechResult(finalText);
    });

    await sttService.startListening();
  }

  Future<void> stopListening() async {
    if (state != ConversationState.listening) return;

    final sttService = _ref.read(sttServiceProvider);
    await sttService.stop();

    final transcript = _ref.read(transcriptProvider);
    _onSpeechResult(transcript);
  }

  Future<void> _onSpeechResult(String transcript) async {
    _transcriptSub?.cancel();
    _finalResultSub?.cancel();

    if (transcript.trim().isEmpty) {
      _ref.read(transcriptProvider.notifier).state = '';
      state = ConversationState.idle;
      _updateAvatarState();
      return;
    }

    state = ConversationState.thinking;
    _updateAvatarState();

    try {
      final chatService = _ref.read(chatServiceProvider);
      final history = _ref.read(chatHistoryProvider);

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

      _ref.read(chatHistoryProvider.notifier).addAssistantMessage(reply);
      _ref.read(aiResponseProvider.notifier).state = reply;
      _ref.read(transcriptProvider.notifier).state = reply;

      state = ConversationState.speaking;
      _updateAvatarState();

      final ttsService = _ref.read(ttsServiceProvider);

      _ttsCompletionSub?.cancel();
      _ttsCompletionSub = ttsService.onComplete.listen((_) {
        if (state == ConversationState.speaking) {
          state = ConversationState.idle;
          _updateAvatarState();
        }
      });

      await ttsService.speak(reply);
    } on ChatException catch (e) {
      _ref.read(transcriptProvider.notifier).state = e.message;
      state = ConversationState.idle;
      _updateAvatarState();
    } catch (e) {
      _ref.read(transcriptProvider.notifier).state =
          'Something went wrong — please try again';
      state = ConversationState.idle;
      _updateAvatarState();
    }
  }

  Future<void> interrupt() async {
    if (state != ConversationState.speaking) return;

    final ttsService = _ref.read(ttsServiceProvider);
    await ttsService.stop();

    _ttsCompletionSub?.cancel();

    state = ConversationState.idle;
    _updateAvatarState();

    await startListening();
  }

  void resetToIdle() {
    _transcriptSub?.cancel();
    _finalResultSub?.cancel();
    _ttsCompletionSub?.cancel();
    _ref.read(transcriptProvider.notifier).state = '';
    state = ConversationState.idle;
    _updateAvatarState();
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _finalResultSub?.cancel();
    _ttsCompletionSub?.cancel();
    super.dispose();
  }
}
