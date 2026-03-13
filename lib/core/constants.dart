class AppConstants {
  AppConstants._();

  // Kimi Chat API (Moonshot AI — OpenAI-compatible)
  static const String kimiApiUrl =
      'https://api.moonshot.cn/v1/chat/completions';
  static const String kimiModel = 'moonshot-v1-8k';
  static const int kimiMaxTokens = 300;
  static const Duration apiTimeout = Duration(seconds: 15);

  // System prompt for conversational avatar
  static const String systemPrompt =
      'You are a friendly, warm AI assistant embodied as an avatar. '
      'Keep ALL responses to exactly 2-3 sentences maximum because '
      'they will be spoken aloud. Be conversational, natural, and '
      'engaging. Never use bullet points, headers, or markdown in '
      'your replies. Speak as if having a real voice conversation.';

  // Conversation limits
  static const int maxHistoryMessages = 20;

  // ElevenLabs API
  static const String elevenLabsApiUrl =
      'https://api.elevenlabs.io/v1/text-to-speech';
  static const String elevenLabsModel = 'eleven_turbo_v2';

  // STT configuration
  static const Duration maxListenDuration = Duration(seconds: 30);
  static const Duration silenceTimeout = Duration(seconds: 2);
  static const String defaultLocale = 'en-US';

  // TTS configuration
  static const double ttsRate = 0.85;
  static const double ttsPitch = 1.05;
  static const double ttsVolume = 1.0;

  // UI
  static const String appTitle = 'AI Avatar Chat';
}
