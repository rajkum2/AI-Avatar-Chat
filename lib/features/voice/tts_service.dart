import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';
import 'audio_player_service.dart';
import 'elevenlabs_service.dart';

final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService(ref);
});

/// Unified TTS service that uses ElevenLabs when available,
/// with fallback to system TTS (flutter_tts)
class TTSService {
  final Ref _ref;
  
  // System TTS fallback
  final FlutterTts _tts = FlutterTts();
  
  // ElevenLabs service
  late final ElevenLabsService _elevenLabs;
  
  // State
  final _completionController = StreamController<void>.broadcast();
  bool _isSpeaking = false;
  bool _initialized = false;
  bool _useElevenLabs = false;
  Timer? _fallbackTimer;
  StreamSubscription<void>? _audioCompleteSub;

  Stream<void> get onComplete => _completionController.stream;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _initialized;
  bool get useElevenLabs => _useElevenLabs;

  TTSService(this._ref) {
    _elevenLabs = ElevenLabsService();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize ElevenLabs first
    if (_elevenLabs.isConfigured) {
      debugPrint('TTS: ElevenLabs configured, preloading voice...');
      await _elevenLabs.preloadVoice();
      _useElevenLabs = _elevenLabs.isVoicePreloaded;
      debugPrint('TTS: ElevenLabs preloaded = $_useElevenLabs');
    } else {
      debugPrint('TTS: ElevenLabs not configured, using system TTS');
      _useElevenLabs = false;
    }

    // Initialize system TTS as fallback
    await _initSystemTTS();

    _initialized = true;
  }

  Future<void> _initSystemTTS() async {
    try {
      await _tts.setLanguage(AppConstants.defaultLocale);
      await _tts.setSpeechRate(AppConstants.ttsRate);
      await _tts.setPitch(AppConstants.ttsPitch);
      await _tts.setVolume(AppConstants.ttsVolume);

      if (kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }

      _tts.setStartHandler(() {
        debugPrint('TTS (System): Started');
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        debugPrint('TTS (System): Completed');
        _onSpeakComplete();
      });

      _tts.setCancelHandler(() {
        debugPrint('TTS (System): Cancelled');
        _onSpeakComplete();
      });

      _tts.setErrorHandler((message) {
        debugPrint('TTS (System) Error: $message');
        _onSpeakComplete();
      });

      debugPrint('TTS: System TTS initialized');
    } catch (e) {
      debugPrint('TTS: System TTS init failed: $e');
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

    // Stop any current speech
    await stop();

    _isSpeaking = true;

    // Try ElevenLabs first if enabled
    if (_useElevenLabs) {
      final success = await _speakWithElevenLabs(text);
      if (success) return;
      
      // Fallback to system TTS on failure
      debugPrint('TTS: ElevenLabs failed, falling back to system TTS');
    }

    // Use system TTS
    await _speakWithSystemTTS(text);
  }

  Future<bool> _speakWithElevenLabs(String text) async {
    try {
      final audioBytes = await _elevenLabs.generateSpeech(text);
      
      if (audioBytes == null || audioBytes.isEmpty) {
        return false;
      }

      // Get audio player and play the bytes
      final audioPlayer = _ref.read(audioPlayerServiceProvider);
      
      // Listen for completion
      _audioCompleteSub?.cancel();
      _audioCompleteSub = audioPlayer.onComplete.listen((_) {
        if (_isSpeaking) {
          debugPrint('TTS (ElevenLabs): Completed');
          _onSpeakComplete();
        }
      });

      await audioPlayer.playBytes(audioBytes);
      return true;
    } catch (e) {
      debugPrint('TTS (ElevenLabs): Error: $e');
      return false;
    }
  }

  Future<void> _speakWithSystemTTS(String text) async {
    _fallbackTimer?.cancel();

    debugPrint('TTS (System): Speaking ${text.length} chars');

    // Fallback timer in case completion handler never fires
    final wordCount = text.split(' ').length;
    final estimatedMs = (wordCount * 150 / AppConstants.ttsRate).round() + 2000;
    _fallbackTimer = Timer(Duration(milliseconds: estimatedMs), () {
      if (_isSpeaking) {
        debugPrint('TTS (System): Fallback timer triggered');
        _onSpeakComplete();
      }
    });

    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS (System): speak() error: $e');
      _onSpeakComplete();
    }
  }

  Future<void> stop() async {
    _fallbackTimer?.cancel();
    _audioCompleteSub?.cancel();

    if (_isSpeaking) {
      debugPrint('TTS: Stopping');
      
      // Stop both services
      if (_useElevenLabs) {
        try {
          await _ref.read(audioPlayerServiceProvider).stop();
        } catch (e) {
          debugPrint('TTS: Audio player stop error: $e');
        }
      }
      
      try {
        await _tts.stop();
      } catch (e) {
        debugPrint('TTS: System TTS stop error: $e');
      }
      
      _isSpeaking = false;
    }
  }

  void _onSpeakComplete() {
    _fallbackTimer?.cancel();
    _audioCompleteSub?.cancel();
    
    if (_isSpeaking) {
      _isSpeaking = false;
      _completionController.add(null);
    }
  }

  /// Force using a specific TTS engine
  void setUseElevenLabs(bool use) {
    if (_useElevenLabs != use) {
      _useElevenLabs = use && _elevenLabs.isConfigured;
      debugPrint('TTS: ElevenLabs preference set to $_useElevenLabs');
    }
  }

  void dispose() {
    _fallbackTimer?.cancel();
    _audioCompleteSub?.cancel();
    _tts.stop();
    _completionController.close();
    _elevenLabs.dispose();
  }
}
