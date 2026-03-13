import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/env.dart';
import 'core/theme.dart';
import 'features/chat/chat_service.dart' show llmSettingsManagerProvider;
import 'features/chat/unified_llm_service.dart';
import 'features/conversation/conversation_flow.dart';
import 'features/settings/llm_settings.dart';
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
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Initialize settings manager first
      await ref.read(llmSettingsManagerProvider).initialize();
      
      // Pre-warm LLM connection based on selected provider
      ref.read(unifiedLLMServiceProvider).warmUp();

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

      // Show configuration info
      _showConfigInfo();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _initialized = true;
      });
    }
  }

  void _showConfigInfo() {
    final settings = ref.read(llmSettingsManagerProvider).settings;
    
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final String message = switch (settings.provider) {
            LLMProviderType.ollama =>
              'Using Ollama (${settings.ollamaModel}) - Make sure it\'s running',
            LLMProviderType.kimi => !Env.hasKimiKey
                ? 'API key not set — Configure in Settings or switch to Ollama'
                : 'Using Kimi API',
            LLMProviderType.backend => settings.backendUrl?.isEmpty ?? true
                ? 'Backend URL not configured'
                : 'Using Backend API',
            LLMProviderType.selfHosted => settings.selfHostedUrl?.isEmpty ?? true
                ? 'Self-hosted URL not configured'
                : 'Using Self-Hosted Server',
            LLMProviderType.llamaCpp => 'On-Device LLM (Mobile Only)',
            LLMProviderType.webGPU => kIsWeb
                ? 'Using WebGPU (Browser)'
                : 'WebGPU only available on web',
          };
          
          ref.read(errorMessageProvider.notifier).state = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
