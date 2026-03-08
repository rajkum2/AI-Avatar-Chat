import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  static String get elevenLabsApiKey =>
      dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  static String get elevenLabsVoiceId =>
      dotenv.env['ELEVENLABS_VOICE_ID'] ?? '';

  static bool get hasAnthropicKey => anthropicApiKey.isNotEmpty;
  static bool get hasElevenLabsKey => elevenLabsApiKey.isNotEmpty;
}
