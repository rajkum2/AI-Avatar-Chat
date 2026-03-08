import 'dart:async';
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

  Stream<void> get onComplete => _completionController.stream;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _tts.setLanguage(AppConstants.defaultLocale);
    await _tts.setSpeechRate(AppConstants.ttsRate);
    await _tts.setPitch(AppConstants.ttsPitch);
    await _tts.setVolume(AppConstants.ttsVolume);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _completionController.add(null);
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      _completionController.add(null);
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  void dispose() {
    _tts.stop();
    _completionController.close();
  }
}
