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

      if (!hasAnthropicKey) {
        debugPrint('Env: WARNING — ANTHROPIC_API_KEY is not set in .env');
      }
    } catch (e) {
      debugPrint('Env: Could not load .env file: $e');
      debugPrint('Env: Create a .env file with ANTHROPIC_API_KEY=your_key');
      _loaded = false;
    }
  }

  static bool get isLoaded => _loaded;

  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  static String get elevenLabsApiKey =>
      dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  static String get elevenLabsVoiceId =>
      dotenv.env['ELEVENLABS_VOICE_ID'] ?? '';

  static bool get hasAnthropicKey =>
      anthropicApiKey.isNotEmpty &&
      anthropicApiKey != 'your_anthropic_api_key_here';

  static bool get hasElevenLabsKey =>
      elevenLabsApiKey.isNotEmpty &&
      elevenLabsApiKey != 'your_elevenlabs_api_key_here';
}
