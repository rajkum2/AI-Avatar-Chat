import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _initialized = false;
  bool _finalResultSent = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _finalResultController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get finalResultStream => _finalResultController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  bool get isInitialized => _initialized;

  String _lastPartialResult = '';

  Future<bool> initialize() async {
    if (_initialized) return _isAvailable;

    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: ${error.errorMsg} (permanent: ${error.permanent})');
          _isListening = false;

          if (error.errorMsg == 'error_no_match' ||
              error.errorMsg == 'error_speech_timeout') {
            _sendFinalResult(_lastPartialResult);
          } else if (error.permanent) {
            _errorController.add(_mapErrorMessage(error.errorMsg));
            _sendFinalResult('');
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              _isListening = false;
              // If status changes to done without a final result,
              // send the last partial result we captured
              _sendFinalResult(_lastPartialResult);
              _lastPartialResult = '';
            }
          }
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('STT init failed: $e');
      _isAvailable = false;
      _initialized = true;
    }

    return _isAvailable;
  }

  Future<void> startListening() async {
    if (!_isAvailable) return;
    if (_isListening) return;

    _isListening = true;
    _lastPartialResult = '';
    _finalResultSent = false;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          _transcriptController.add(words);

          if (result.finalResult) {
            _isListening = false;
            _lastPartialResult = '';
            _sendFinalResult(words);
          } else {
            _lastPartialResult = words;
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
    } catch (e) {
      debugPrint('STT listen failed: $e');
      _isListening = false;
      _errorController.add('Could not start listening');
      _finalResultController.add('');
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('STT stop error: $e');
    }
    _isListening = false;
  }

  /// Sends the final result exactly once per listen session.
  void _sendFinalResult(String text) {
    if (_finalResultSent) return;
    _finalResultSent = true;
    debugPrint('STT: Final result (${text.length} chars): "$text"');
    _finalResultController.add(text);
  }

  String _mapErrorMessage(String errorMsg) {
    switch (errorMsg) {
      case 'error_no_match':
        return "Couldn't hear you — please try again";
      case 'error_speech_timeout':
        return "Couldn't hear you — please try again";
      case 'error_audio':
        return 'Microphone error — please check permissions';
      case 'error_permission':
        return 'Microphone permission denied';
      case 'error_not_available':
        return 'Speech recognition not available';
      case 'error_network':
        return 'Network error during speech recognition';
      default:
        return 'Speech recognition error';
    }
  }

  void dispose() {
    _speech.stop();
    _transcriptController.close();
    _finalResultController.close();
    _errorController.close();
  }
}
