import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/env.dart';
import 'core/theme.dart';
import 'features/chat/chat_service.dart';
import 'features/conversation/conversation_flow.dart';
import 'features/voice/stt_service.dart';
import 'features/voice/tts_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  runApp(const ProviderScope(child: AiAvatarChatApp()));
}

class AiAvatarChatApp extends StatelessWidget {
  const AiAvatarChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Avatar Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppInitializer(),
    );
  }
}

/// Initializes services eagerly on first build, then shows HomeScreen.
class _AppInitializer extends ConsumerStatefulWidget {
  const _AppInitializer();

  @override
  ConsumerState<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // Pre-warm HTTPS connection to Kimi API (fire and forget)
    ref.read(chatServiceProvider).warmUp();

    // Pre-initialize TTS so it's ready when first response arrives
    final tts = ref.read(ttsServiceProvider);
    await tts.initialize();

    // Pre-initialize STT so mic permission prompt shows early
    final stt = ref.read(sttServiceProvider);
    final sttAvailable = await stt.initialize();

    // If STT not available on web, likely unsupported browser
    if (!sttAvailable && kIsWeb && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(persistentErrorProvider.notifier).state =
              'Browser not supported — please use Chrome';
        }
      });
    }

    // Warn if API keys are missing after everything is loaded
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          if (!Env.hasKimiKey) {
            ref.read(errorMessageProvider.notifier).state =
                'API key not set — add KIMI_API_KEY to .env file';
          } else if (!Env.hasElevenLabsKey) {
            // Only show if Kimi is configured but ElevenLabs isn't
            ref.read(errorMessageProvider.notifier).state =
                'ElevenLabs not configured — using system TTS';
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
