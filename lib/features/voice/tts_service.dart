import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';

final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});

class TTSService {
  final FlutterTts _tts = FlutterTts();
  final _completionController = StreamController<void>.broadcast();
  bool _isSpeaking = false;
  bool _initialized = false;
  Timer? _fallbackTimer;

  Stream<void> get onComplete => _completionController.stream;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _tts.setLanguage(AppConstants.defaultLocale);
      await _tts.setSpeechRate(AppConstants.ttsRate);
      await _tts.setPitch(AppConstants.ttsPitch);
      await _tts.setVolume(AppConstants.ttsVolume);

      // On web, set the engine to use the browser's speech synthesis
      if (kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }

      _tts.setStartHandler(() {
        debugPrint('TTS: Started speaking');
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        debugPrint('TTS: Completed');
        _onSpeakComplete();
      });

      _tts.setCancelHandler(() {
        debugPrint('TTS: Cancelled');
        _onSpeakComplete();
      });

      _tts.setErrorHandler((message) {
        debugPrint('TTS Error: $message');
        _onSpeakComplete();
      });

      // Log available voices for debugging
      if (kDebugMode) {
        final voices = await _tts.getVoices;
        final enVoices = (voices as List)
            .where((v) =>
                v['locale']?.toString().startsWith('en') == true)
            .take(5)
            .toList();
        debugPrint('TTS: ${enVoices.length} English voices available');
        for (final v in enVoices) {
          debugPrint('  - ${v['name']} (${v['locale']})');
        }
      }

      _initialized = true;
      debugPrint('TTS: Initialized successfully');
    } catch (e) {
      debugPrint('TTS: Init failed: $e');
      _initialized = true; // Mark as initialized to avoid retry loops
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      debugPrint('TTS: Skipping empty text');
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    _isSpeaking = true;
    _fallbackTimer?.cancel();

    debugPrint('TTS: Speaking ${text.length} chars');

    // Fallback timer in case completion handler never fires (web quirk)
    // Estimate ~150ms per word + 2s buffer
    final wordCount = text.split(' ').length;
    final estimatedMs = (wordCount * 150 / AppConstants.ttsRate).round() + 2000;
    _fallbackTimer = Timer(Duration(milliseconds: estimatedMs), () {
      if (_isSpeaking) {
        debugPrint('TTS: Fallback timer triggered after ${estimatedMs}ms');
        _onSpeakComplete();
      }
    });

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS: speak() error: $e');
      _onSpeakComplete();
    }
  }

  Future<void> stop() async {
    _fallbackTimer?.cancel();
    if (_isSpeaking) {
      debugPrint('TTS: Stopping');
      try {
        await _tts.stop();
      } catch (e) {
        debugPrint('TTS: stop() error: $e');
      }
      _isSpeaking = false;
    }
  }

  void _onSpeakComplete() {
    _fallbackTimer?.cancel();
    if (_isSpeaking) {
      _isSpeaking = false;
      _completionController.add(null);
    }
  }

  void dispose() {
    _fallbackTimer?.cancel();
    _tts.stop();
    _completionController.close();
  }
}
