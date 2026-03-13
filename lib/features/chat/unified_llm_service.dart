import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/llm_settings.dart';
import 'backend_chat_service.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';
import 'chat_service.dart' show llmSettingsManagerProvider;
import 'kimi_service_impl.dart';
import 'llama_cpp_service.dart';
import 'ollama_service.dart';
import 'self_hosted_service.dart';
import 'web_gpu_service.dart';

/// Unified LLM service that can switch between all providers at runtime
class UnifiedLLMService implements ChatServiceInterface {
  final Ref _ref;
  LLMSettings _settings;
  
  ChatServiceInterface? _currentService;
  LLMProviderType? _currentProvider;

  UnifiedLLMService(this._ref, this._settings) {
    _updateService();
  }

  /// Update settings and switch service if provider changed
  void updateSettings(LLMSettings newSettings) {
    final providerChanged = newSettings.provider != _settings.provider;
    final configChanged = _hasConfigChanged(newSettings);
    
    _settings = newSettings;
    
    if (providerChanged || configChanged) {
      _disposeCurrentService();
      _updateService();
    }
  }

  bool _hasConfigChanged(LLMSettings newSettings) {
    switch (_settings.provider) {
      case LLMProviderType.kimi:
        return newSettings.kimiApiKey != _settings.kimiApiKey;
      case LLMProviderType.backend:
        return newSettings.backendUrl != _settings.backendUrl;
      case LLMProviderType.ollama:
        return newSettings.ollamaUrl != _settings.ollamaUrl ||
               newSettings.ollamaModel != _settings.ollamaModel;
      case LLMProviderType.selfHosted:
        return newSettings.selfHostedUrl != _settings.selfHostedUrl ||
               newSettings.selfHostedModel != _settings.selfHostedModel;
      case LLMProviderType.llamaCpp:
        return newSettings.llamaCppModelPath != _settings.llamaCppModelPath;
      case LLMProviderType.webGPU:
        return newSettings.webGpuModel != _settings.webGpuModel;
    }
  }

  void _updateService() {
    _currentProvider = _settings.provider;
    
    switch (_settings.provider) {
      case LLMProviderType.kimi:
        debugPrint('UnifiedLLM: Switching to Kimi API');
        _currentService = ChatService();
        break;
        
      case LLMProviderType.ollama:
        debugPrint('UnifiedLLM: Switching to Ollama (${_settings.ollamaModel})');
        _currentService = OllamaService();
        break;
        
      case LLMProviderType.backend:
        debugPrint('UnifiedLLM: Switching to Backend (${_settings.backendUrl})');
        _currentService = BackendChatService(_ref);
        break;
        
      case LLMProviderType.selfHosted:
        debugPrint('UnifiedLLM: Switching to Self-Hosted (${_settings.selfHostedUrl})');
        _currentService = SelfHostedService(_settings);
        break;
        
      case LLMProviderType.llamaCpp:
        debugPrint('UnifiedLLM: Switching to llama.cpp FFI');
        // Only available on mobile
        if (kIsWeb) {
          debugPrint('UnifiedLLM: llama.cpp not available on web, falling back to Ollama');
          _currentService = OllamaService();
          _currentProvider = LLMProviderType.ollama;
        } else {
          _currentService = LlamaCppService(_settings);
        }
        break;
        
      case LLMProviderType.webGPU:
        debugPrint('UnifiedLLM: Switching to WebGPU');
        // Only available on web
        if (kIsWeb) {
          _currentService = WebGPUService(_settings);
        } else {
          debugPrint('UnifiedLLM: WebGPU not available on mobile, falling back to Ollama');
          _currentService = OllamaService();
          _currentProvider = LLMProviderType.ollama;
        }
        break;
    }
  }

  void _disposeCurrentService() {
    if (_currentService is OllamaService) {
      (_currentService as OllamaService).dispose();
    } else if (_currentService is BackendChatService) {
      (_currentService as BackendChatService).dispose();
    } else if (_currentService is SelfHostedService) {
      (_currentService as SelfHostedService).dispose();
    } else if (_currentService is LlamaCppService) {
      (_currentService as LlamaCppService).dispose();
    }
    _currentService = null;
  }

  @override
  Future<void> warmUp() async {
    await _currentService?.warmUp();
  }

  @override
  Stream<String> streamMessage(String userMessage, List<ChatMessage> history) async* {
    if (_currentService == null) {
      throw ChatException('No LLM service configured');
    }
    
    try {
      yield* _currentService!.streamMessage(userMessage, history);
    } on ChatException {
      rethrow;
    } catch (e) {
      throw ChatException('LLM service error: $e');
    }
  }

  @override
  Future<String> sendMessage(String userMessage, List<ChatMessage> history) async {
    if (_currentService == null) {
      throw ChatException('No LLM service configured');
    }
    
    try {
      return await _currentService!.sendMessage(userMessage, history);
    } on ChatException {
      rethrow;
    } catch (e) {
      throw ChatException('LLM service error: $e');
    }
  }

  /// Get current provider info
  String get currentProviderInfo {
    switch (_currentProvider) {
      case LLMProviderType.kimi:
        return 'Kimi API';
      case LLMProviderType.ollama:
        return 'Ollama (${_settings.ollamaModel})';
      case LLMProviderType.backend:
        return 'Backend (${_settings.backendUrl})';
      case LLMProviderType.selfHosted:
        return 'Self-Hosted (${_settings.selfHostedModel})';
      case LLMProviderType.llamaCpp:
        return 'On-Device';
      case LLMProviderType.webGPU:
        return 'WebGPU (${_settings.webGpuModel})';
      case null:
        return 'Not configured';
    }
  }

  /// Check if current service is available
  Future<bool> checkAvailability() async {
    if (_currentService is OllamaService) {
      return await (_currentService as OllamaService).checkAvailability();
    }
    // Other services don't have explicit availability checks
    return _currentService != null;
  }

  void dispose() {
    _disposeCurrentService();
  }
}

/// Provider for the unified LLM service
final unifiedLLMServiceProvider = Provider<UnifiedLLMService>((ref) {
  // Get current settings from the manager
  final settingsManager = ref.watch(llmSettingsManagerProvider);
  return UnifiedLLMService(ref, settingsManager.settings);
});

/// Async initialization provider
final llmSettingsInitializationProvider = FutureProvider<void>((ref) async {
  await ref.read(llmSettingsManagerProvider).initialize();
});
