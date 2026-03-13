import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static bool _loaded = false;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
      debugPrint('Env: .env loaded successfully');

      if (!hasKimiKey && !useBackend) {
        debugPrint('Env: WARNING — KIMI_API_KEY is not set in .env');
      }
    } catch (e) {
      debugPrint('Env: Could not load .env file: $e');
      debugPrint('Env: Create a .env file with required API keys');
      _loaded = false;
    }
  }

  static bool get isLoaded => _loaded;

  // Backend API URL (for Phase 2)
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  // Feature flags
  static bool get useBackend =>
      dotenv.env['USE_BACKEND']?.toLowerCase() == 'true';

  // Direct API keys (fallback when not using backend)
  static String get kimiApiKey =>
      dotenv.env['KIMI_API_KEY'] ?? '';

  static String get elevenLabsApiKey =>
      dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  static String get elevenLabsVoiceId =>
      dotenv.env['ELEVENLABS_VOICE_ID'] ?? '';

  // Validation
  static bool get hasKimiKey =>
      kimiApiKey.isNotEmpty &&
      kimiApiKey != 'your_kimi_api_key_here';

  static bool get hasElevenLabsKey =>
      elevenLabsApiKey.isNotEmpty &&
      elevenLabsApiKey != 'your_elevenlabs_api_key_here';

  static bool get hasBackendUrl =>
      backendUrl.isNotEmpty &&
      !backendUrl.contains('localhost');
}
