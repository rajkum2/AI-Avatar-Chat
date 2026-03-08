import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/constants.dart';

final sttServiceProvider = Provider<STTService>((ref) {
  return STTService();
});

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _finalResultController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get finalResultStream => _finalResultController.stream;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        _isListening = false;
        if (error.permanent) {
          _finalResultController.add('');
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isAvailable;
  }

  Future<void> startListening() async {
    if (!_isAvailable) return;

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        _transcriptController.add(result.recognizedWords);
        if (result.finalResult) {
          _isListening = false;
          _finalResultController.add(result.recognizedWords);
        }
      },
      listenFor: AppConstants.maxListenDuration,
      pauseFor: AppConstants.silenceTimeout,
      localeId: AppConstants.defaultLocale,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> stop() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  void dispose() {
    _speech.stop();
    _transcriptController.close();
    _finalResultController.close();
  }
}
