import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/llm_settings.dart' show LLMProviderType, LLMSettingsManager;
import 'backend_chat_service.dart';
import 'chat_service_interface.dart';
import 'kimi_service_impl.dart';
import 'llama_cpp_service.dart';
import 'ollama_service.dart';
import 'self_hosted_service.dart';
import 'web_gpu_service.dart';
export 'chat_service_interface.dart';
export 'kimi_service_impl.dart';
export '../settings/llm_settings.dart';

/// Provider for settings manager
final llmSettingsManagerProvider = ChangeNotifierProvider<LLMSettingsManager>((ref) {
  return LLMSettingsManager();
});

/// Legacy provider - now redirects to settings-based selection
/// Use unifiedLLMServiceProvider for full runtime switching support
final chatServiceProvider = Provider<ChatServiceInterface>((ref) {
  // Check if we have runtime settings first
  final settings = ref.watch(llmSettingsManagerProvider).settings;
  
  switch (settings.provider) {
    case LLMProviderType.ollama:
      debugPrint('ChatService: Using Ollama (${settings.ollamaModel})');
      return OllamaService();
    case LLMProviderType.backend:
      debugPrint('ChatService: Using Backend API');
      return BackendChatService(ref);
    case LLMProviderType.selfHosted:
      debugPrint('ChatService: Using Self-Hosted Server');
      return SelfHostedService(settings);
    case LLMProviderType.llamaCpp:
      debugPrint('ChatService: Using llama.cpp FFI');
      return LlamaCppService(settings);
    case LLMProviderType.webGPU:
      debugPrint('ChatService: Using WebGPU');
      return WebGPUService(settings);
    case LLMProviderType.kimi:
      debugPrint('ChatService: Using Kimi API');
      return ChatService();
  }
});
