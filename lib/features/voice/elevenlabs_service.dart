import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env.dart';

/// Service for ElevenLabs text-to-speech API
/// Provides high-quality neural voices with streaming audio playback
class ElevenLabsService {
  final _client = http.Client();
  
  // Cache for preloaded audio (for common phrases)
  final Map<String, Uint8List> _audioCache = {};
  
  // Track if voice is preloaded
  bool _voicePreloaded = false;
  bool _preloading = false;

  bool get isConfigured => Env.hasElevenLabsKey && Env.elevenLabsVoiceId.isNotEmpty;
  bool get isVoicePreloaded => _voicePreloaded;

  /// Preload/warm up the voice by making a test request
  /// This establishes TLS connection and validates credentials
  Future<void> preloadVoice() async {
    if (!isConfigured || _voicePreloaded || _preloading) return;
    
    _preloading = true;
    debugPrint('ElevenLabs: Preloading voice...');
    
    try {
      // Make a minimal request to warm up the connection
      final url = Uri.parse(
        '${AppConstants.elevenLabsApiUrl}/${Env.elevenLabsVoiceId}/stream',
      );
      
      final response = await _client.post(
        url,
        headers: {
          'xi-api-key': Env.elevenLabsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': 'Hi',  // Minimal text for warm-up
          'model_id': AppConstants.elevenLabsModel,
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _voicePreloaded = true;
        debugPrint('ElevenLabs: Voice preloaded successfully');
      } else if (response.statusCode == 401) {
        debugPrint('ElevenLabs: Invalid API key');
      } else if (response.statusCode == 404) {
        debugPrint('ElevenLabs: Invalid voice ID');
      } else {
        debugPrint('ElevenLabs: Preload failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ElevenLabs: Preload error: $e');
    } finally {
      _preloading = false;
    }
  }

  /// Generate speech from text and return audio bytes
  /// Returns null if ElevenLabs is not configured or request fails
  Future<Uint8List?> generateSpeech(String text) async {
    if (!isConfigured) {
      debugPrint('ElevenLabs: Not configured');
      return null;
    }

    if (text.trim().isEmpty) {
      debugPrint('ElevenLabs: Empty text');
      return null;
    }

    // Check cache for common phrases
    final cacheKey = _getCacheKey(text);
    if (_audioCache.containsKey(cacheKey)) {
      debugPrint('ElevenLabs: Cache hit for "$text"');
      return _audioCache[cacheKey];
    }

    debugPrint('ElevenLabs: Generating speech for ${text.length} chars');
    final stopwatch = Stopwatch()..start();

    try {
      final url = Uri.parse(
        '${AppConstants.elevenLabsApiUrl}/${Env.elevenLabsVoiceId}/stream',
      );

      final response = await _client.post(
        url,
        headers: {
          'xi-api-key': Env.elevenLabsApiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': AppConstants.elevenLabsModel,
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.3,
            'use_speaker_boost': true,
          },
          'optimize_streaming_latency': 3, // 3 = max optimization
        }),
      ).timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        debugPrint(
          'ElevenLabs: Generated ${bytes.length} bytes in '
          '${stopwatch.elapsedMilliseconds}ms',
        );

        // Cache short common phrases
        if (text.length < 50 && _audioCache.length < 10) {
          _audioCache[cacheKey] = bytes;
          debugPrint('ElevenLabs: Cached phrase "$text"');
        }

        return bytes;
      } else if (response.statusCode == 401) {
        debugPrint('ElevenLabs: Authentication failed');
        return null;
      } else if (response.statusCode == 429) {
        debugPrint('ElevenLabs: Rate limited');
        return null;
      } else {
        debugPrint('ElevenLabs: Error ${response.statusCode}');
        if (kDebugMode) {
          debugPrint('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint('ElevenLabs: Request failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      return null;
    }
  }

  /// Stream speech audio for lower latency (not yet implemented)
  /// For now, returns the full bytes (same as generateSpeech)
  Future<Uint8List?> streamSpeech(String text) async {
    // TODO: Implement true streaming with chunked playback
    // This would require modifying AudioPlayerService to support
    // chunked audio streaming
    return generateSpeech(text);
  }

  /// Clear the audio cache
  void clearCache() {
    _audioCache.clear();
    debugPrint('ElevenLabs: Cache cleared');
  }

  /// Get cache key for a text string
  String _getCacheKey(String text) {
    return text.trim().toLowerCase().hashCode.toString();
  }

  void dispose() {
    _client.close();
    clearCache();
  }
}
