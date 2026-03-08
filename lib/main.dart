import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/env.dart';
import 'core/theme.dart';
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
    // Pre-initialize TTS so it's ready when first response arrives
    final tts = ref.read(ttsServiceProvider);
    await tts.initialize();

    // Pre-initialize STT so mic permission prompt shows early
    final stt = ref.read(sttServiceProvider);
    await stt.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
