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

      // Log which provider is configured
      debugPrint('Env: LLM Provider = $llmProvider');
    } catch (e) {
      debugPrint('Env: Could not load .env file: $e');
      debugPrint('Env: Create a .env file with required configuration');
      _loaded = false;
    }
  }

  static bool get isLoaded => _loaded;

  // ==========================================
  // LLM Provider Selection
  // ==========================================
  // Options: kimi, ollama, backend, llama_cpp, web_gpu
  static String get llmProvider =>
      dotenv.env['LLM_PROVIDER']?.toLowerCase() ?? 'kimi';

  static bool get useOllama => llmProvider == 'ollama';
  static bool get useKimi => llmProvider == 'kimi';
  static bool get useBackend => llmProvider == 'backend' || 
      dotenv.env['USE_BACKEND']?.toLowerCase() == 'true';

  // ==========================================
  // Backend API (Phase 2)
  // ==========================================
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  // ==========================================
  // Ollama (Local LLM)
  // ==========================================
  static String get ollamaUrl =>
      dotenv.env['OLLAMA_URL'] ?? 'http://localhost:11434';

  static String get ollamaModel =>
      dotenv.env['OLLAMA_MODEL'] ?? 'llama3.2:3b';

  // ==========================================
  // Direct API Keys (fallback)
  // ==========================================
  static String get kimiApiKey =>
      dotenv.env['KIMI_API_KEY'] ?? '';

  static String get elevenLabsApiKey =>
      dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  static String get elevenLabsVoiceId =>
      dotenv.env['ELEVENLABS_VOICE_ID'] ?? '';

  // ==========================================
  // Validation
  // ==========================================
  static bool get hasKimiKey =>
      kimiApiKey.isNotEmpty &&
      kimiApiKey != 'your_kimi_api_key_here';

  static bool get hasElevenLabsKey =>
      elevenLabsApiKey.isNotEmpty &&
      elevenLabsApiKey != 'your_elevenlabs_api_key_here';

  static bool get hasBackendUrl =>
      backendUrl.isNotEmpty &&
      !backendUrl.contains('localhost');

  /// Get configuration status message
  static String get configStatus {
    if (useOllama) {
      return 'Using Ollama (Local LLM) - Model: $ollamaModel';
    } else if (useBackend) {
      return 'Using Backend API - URL: $backendUrl';
    } else if (useKimi && hasKimiKey) {
      return 'Using Kimi API (Cloud)';
    } else {
      return 'No LLM configured - Set LLM_PROVIDER in .env';
    }
  }
}
