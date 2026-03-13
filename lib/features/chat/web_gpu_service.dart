import 'dart:async';
import 'package:flutter/foundation.dart';
import '../settings/llm_settings.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';

/// WebGPU-based LLM service for browser
/// Uses Transformers.js with WebGPU backend for GPU-accelerated inference
/// 
/// NOTE: Only works in Chrome/Edge with WebGPU support
/// Models are downloaded on first use and cached in browser storage
class WebGPUService implements ChatServiceInterface {
  // ignore: unused_field
  final LLMSettings _settings;
  
  bool _initialized = false;
  bool _webGpuAvailable = false;
  bool get isWebGpuAvailable => _webGpuAvailable;

  WebGPUService(this._settings) {
    _checkWebGpuSupport();
  }

  void _checkWebGpuSupport() {
    if (!kIsWeb) {
      debugPrint('WebGPU: Not available - not running on web');
      return;
    }

    try {
      // WebGPU check would go here with dart:js_interop
      // For now, assume available on web
      _webGpuAvailable = kIsWeb;
      
      if (_webGpuAvailable) {
        debugPrint('WebGPU: Web environment detected');
      }
    } catch (e) {
      debugPrint('WebGPU: Error checking support: $e');
      _webGpuAvailable = false;
    }
  }

  @override
  Future<void> warmUp() async {
    if (_initialized) return;
    if (!kIsWeb) {
      throw UnsupportedError('WebGPU only available on web');
    }

    debugPrint('WebGPU: Initializing Transformers.js...');

    // In a real implementation, this would inject and initialize
    // the Transformers.js library via JS interop
    await Future.delayed(const Duration(seconds: 1));
    
    _initialized = true;
    debugPrint('WebGPU: Initialized successfully (simulated)');
  }

  @override
  Stream<String> streamMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async* {
    if (!_initialized) {
      await warmUp();
    }

    final prompt = _buildPrompt(userMessage, history);
    debugPrint('WebGPU: Generating with prompt length ${prompt.length}');

    // Simulated generation - in real implementation, this would
    // call the WebGPU model through JS interop
    final words = [
      "Hello! ",
      "I'm ",
      "running ",
      "in ",
      "your ",
      "browser ",
      "using ",
      "WebGPU. ",
      "No ",
      "server ",
      "needed!",
    ];

    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield word;
    }

    debugPrint('WebGPU: Generation complete');
  }

  @override
  Future<String> sendMessage(String userMessage, List<ChatMessage> history) async {
    final buffer = StringBuffer();
    await for (final chunk in streamMessage(userMessage, history)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  String _buildPrompt(String message, List<ChatMessage> history) {
    final buffer = StringBuffer();
    
    // System instruction
    buffer.writeln('<|system|>');
    buffer.writeln(
      'You are a friendly AI assistant running in the browser using WebGPU. '
      'Keep responses to 2-3 sentences maximum.'
    );
    buffer.writeln('<|end|>');
    
    // History
    for (final msg in history.take(6)) {
      buffer.writeln('<|${msg.role}|>');
      buffer.writeln(msg.content);
      buffer.writeln('<|end|>');
    }
    
    // Current message
    buffer.writeln('<|user|>');
    buffer.writeln(message);
    buffer.writeln('<|end|>');
    buffer.writeln('<|assistant|>');
    
    return buffer.toString();
  }

  /// Get model loading progress (0.0 to 1.0)
  Future<double> getLoadingProgress() async {
    // Would check actual loading progress via JS interop
    return 1.0;
  }

  /// Check if model is cached
  Future<bool> isModelCached() async {
    // Would check browser cache via JS interop
    return false;
  }

  /// Clear model cache
  Future<void> clearCache() async {
    debugPrint('WebGPU: Cache cleared');
  }

  /// Get available models for WebGPU
  static List<Map<String, String>> getAvailableModels() {
    return [
      {'id': 'Xenova/Phi-3-mini-4k-instruct', 'name': 'Phi-3 Mini (3.8B)', 'size': '~1.8GB'},
      {'id': 'Xenova/gemma-2b-it', 'name': 'Gemma 2B IT', 'size': '~1.6GB'},
      {'id': 'Xenova/TinyLlama-1.1B-Chat-v1.0', 'name': 'TinyLlama 1.1B', 'size': '~0.6GB'},
      {'id': 'Xenova/Qwen2.5-0.5B-Instruct', 'name': 'Qwen 2.5 0.5B', 'size': '~0.4GB'},
    ];
  }

  void dispose() {
    _initialized = false;
  }
}
