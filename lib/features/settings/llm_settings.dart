import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LLM Provider types supported by the app
enum LLMProviderType {
  kimi('Kimi API (Cloud)', 'kimi', 'Paid cloud API - requires API key'),
  ollama('Ollama (Local)', 'ollama', 'Free local LLM - requires Ollama installed'),
  backend('Backend Server', 'backend', 'Your own backend API'),
  selfHosted('Self-Hosted vLLM', 'self_hosted', 'Your own GPU server with vLLM'),
  llamaCpp('On-Device (Mobile)', 'llama_cpp', 'Run model directly on phone (offline)'),
  webGPU('WebGPU (Browser)', 'web_gpu', 'Run in browser with WebGPU'),
  ;

  final String displayName;
  final String key;
  final String description;

  const LLMProviderType(this.displayName, this.key, this.description);

  static LLMProviderType fromKey(String key) {
    return LLMProviderType.values.firstWhere(
      (p) => p.key == key,
      orElse: () => LLMProviderType.kimi,
    );
  }

  bool get isLocal => this == LLMProviderType.ollama || 
                      this == LLMProviderType.llamaCpp ||
                      this == LLMProviderType.webGPU;
  
  bool get requiresServer => this == LLMProviderType.backend || 
                             this == LLMProviderType.selfHosted ||
                             this == LLMProviderType.kimi;
  
  bool get isMobileOnly => this == LLMProviderType.llamaCpp;
  bool get isWebOnly => this == LLMProviderType.webGPU;
}

/// Settings for LLM configuration
class LLMSettings {
  final LLMProviderType provider;
  final String? kimiApiKey;
  final String? backendUrl;
  final String? ollamaUrl;
  final String? ollamaModel;
  final String? selfHostedUrl;
  final String? selfHostedModel;
  final String? llamaCppModelPath;
  final String? webGpuModel;
  final double temperature;
  final int maxTokens;

  const LLMSettings({
    this.provider = LLMProviderType.kimi,
    this.kimiApiKey,
    this.backendUrl,
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'llama3.2:3b',
    this.selfHostedUrl,
    this.selfHostedModel = 'meta-llama/Llama-3.2-3B-Instruct',
    this.llamaCppModelPath,
    this.webGpuModel = 'Xenova/Phi-3-mini-4k-instruct',
    this.temperature = 0.7,
    this.maxTokens = 150,
  });

  factory LLMSettings.fromJson(Map<String, dynamic> json) {
    return LLMSettings(
      provider: LLMProviderType.fromKey(json['provider'] as String? ?? 'kimi'),
      kimiApiKey: json['kimiApiKey'] as String?,
      backendUrl: json['backendUrl'] as String?,
      ollamaUrl: json['ollamaUrl'] as String? ?? 'http://localhost:11434',
      ollamaModel: json['ollamaModel'] as String? ?? 'llama3.2:3b',
      selfHostedUrl: json['selfHostedUrl'] as String?,
      selfHostedModel: json['selfHostedModel'] as String? ?? 'meta-llama/Llama-3.2-3B-Instruct',
      llamaCppModelPath: json['llamaCppModelPath'] as String?,
      webGpuModel: json['webGpuModel'] as String? ?? 'Xenova/Phi-3-mini-4k-instruct',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 150,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.key,
    'kimiApiKey': kimiApiKey,
    'backendUrl': backendUrl,
    'ollamaUrl': ollamaUrl,
    'ollamaModel': ollamaModel,
    'selfHostedUrl': selfHostedUrl,
    'selfHostedModel': selfHostedModel,
    'llamaCppModelPath': llamaCppModelPath,
    'webGpuModel': webGpuModel,
    'temperature': temperature,
    'maxTokens': maxTokens,
  };

  LLMSettings copyWith({
    LLMProviderType? provider,
    String? kimiApiKey,
    String? backendUrl,
    String? ollamaUrl,
    String? ollamaModel,
    String? selfHostedUrl,
    String? selfHostedModel,
    String? llamaCppModelPath,
    String? webGpuModel,
    double? temperature,
    int? maxTokens,
  }) {
    return LLMSettings(
      provider: provider ?? this.provider,
      kimiApiKey: kimiApiKey ?? this.kimiApiKey,
      backendUrl: backendUrl ?? this.backendUrl,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      selfHostedUrl: selfHostedUrl ?? this.selfHostedUrl,
      selfHostedModel: selfHostedModel ?? this.selfHostedModel,
      llamaCppModelPath: llamaCppModelPath ?? this.llamaCppModelPath,
      webGpuModel: webGpuModel ?? this.webGpuModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  @override
  String toString() => 'LLMSettings(provider: ${provider.displayName})';
}

/// Manager for LLM settings with persistence
class LLMSettingsManager extends ChangeNotifier {
  static const String _prefsKey = 'llm_settings';
  
  LLMSettings _settings = const LLMSettings();
  SharedPreferences? _prefs;
  bool _initialized = false;

  LLMSettings get settings => _settings;
  bool get initialized => _initialized;

  /// Initialize and load saved settings
  Future<void> initialize() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    final jsonString = _prefs?.getString(_prefsKey);
    
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _settings = LLMSettings.fromJson(json);
        debugPrint('LLMSettings: Loaded saved settings - $_settings');
      } catch (e) {
        debugPrint('LLMSettings: Failed to load settings: $e');
      }
    }
    
    _initialized = true;
    notifyListeners();
  }

  /// Update settings and persist
  Future<void> updateSettings(LLMSettings newSettings) async {
    _settings = newSettings;
    
    try {
      final jsonString = jsonEncode(newSettings.toJson());
      await _prefs?.setString(_prefsKey, jsonString);
      debugPrint('LLMSettings: Saved settings - $newSettings');
    } catch (e) {
      debugPrint('LLMSettings: Failed to save settings: $e');
    }
    
    notifyListeners();
  }

  /// Update just the provider
  Future<void> setProvider(LLMProviderType provider) async {
    await updateSettings(_settings.copyWith(provider: provider));
  }

  /// Reset to defaults
  Future<void> reset() async {
    await updateSettings(const LLMSettings());
  }

  /// Get available providers for current platform
  List<LLMProviderType> getAvailableProviders() {
    return LLMProviderType.values.where((p) {
      if (kIsWeb) {
        // Web only supports: kimi, backend, selfHosted, ollama (if accessible), webGPU
        return p != LLMProviderType.llamaCpp;
      } else {
        // Mobile supports all except webGPU
        return p != LLMProviderType.webGPU;
      }
    }).toList();
  }

  /// Check if current provider is properly configured
  String? getConfigurationError() {
    switch (_settings.provider) {
      case LLMProviderType.kimi:
        if (_settings.kimiApiKey?.isEmpty ?? true) {
          return 'Kimi API key not configured';
        }
        break;
      case LLMProviderType.backend:
        if (_settings.backendUrl?.isEmpty ?? true) {
          return 'Backend URL not configured';
        }
        break;
      case LLMProviderType.selfHosted:
        if (_settings.selfHostedUrl?.isEmpty ?? true) {
          return 'Self-hosted URL not configured';
        }
        break;
      case LLMProviderType.llamaCpp:
        if (_settings.llamaCppModelPath?.isEmpty ?? true) {
          return 'Model file path not configured';
        }
        break;
      case LLMProviderType.ollama:
      case LLMProviderType.webGPU:
        // These have defaults, no error
        break;
    }
    return null;
  }
}
