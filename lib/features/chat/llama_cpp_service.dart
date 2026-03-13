import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../settings/llm_settings.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';

// dart:ffi is not available on web, so we use conditional imports
// For now, we just stub out the FFI functionality on web
import 'llama_cpp_stub.dart' 
  if (dart.library.ffi) 'llama_cpp_impl.dart';

/// On-device LLM via llama.cpp FFI
/// 
/// NOTE: Full implementation requires:
/// 1. Compiling llama.cpp as shared library (libllama.so / libllama.dylib)
/// 2. Placing it in android/src/main/jniLibs/ and ios/Frameworks/
/// 3. Downloading .gguf model files to device storage
/// 
/// This implementation provides the Dart interface. Native bindings are
/// generated using ffigen from llama.h
class LlamaCppService implements ChatServiceInterface {
  final LLMSettings _settings;
  
  final LlamaCppImpl _impl;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  LlamaCppService(this._settings) : _impl = LlamaCppImpl();

  @override
  Future<void> warmUp() async {
    if (_initialized) return;
    
    if (kIsWeb) {
      throw UnsupportedError('llama.cpp FFI not available on web');
    }
    
    try {
      await _impl.initialize(_settings.llamaCppModelPath);
      _initialized = true;
      debugPrint('LlamaCpp: Initialized successfully');
    } catch (e) {
      debugPrint('LlamaCpp: Initialization failed: $e');
      throw ChatException('Failed to initialize on-device LLM: $e');
    }
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
    debugPrint('LlamaCpp: Generating ${prompt.length} chars');

    await for (final chunk in _impl.generate(prompt, _settings.maxTokens)) {
      yield chunk;
    }
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
    
    // System prompt
    buffer.writeln('<|system|>');
    buffer.writeln(
      'You are a friendly AI assistant. Keep responses to 2-3 sentences maximum.'
    );
    buffer.writeln('<|end|>');
    
    // Chat history
    for (final msg in history.take(10)) {
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

  /// Download a model from URL to local storage
  Future<String> downloadModel(String url, String filename) async {
    debugPrint('LlamaCpp: Downloading model from $url');
    
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(dir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    
    final filePath = path.join(modelsDir.path, filename);
    final file = File(filePath);
    
    if (await file.exists()) {
      debugPrint('LlamaCpp: Model already exists at $filePath');
      return filePath;
    }

    // Download with progress
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    
    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    
    final sink = file.openWrite();
    await for (final chunk in response) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        final progress = (receivedBytes / totalBytes * 100).toStringAsFixed(1);
        debugPrint('LlamaCpp: Download progress: $progress%');
      }
    }
    await sink.close();
    
    debugPrint('LlamaCpp: Download complete: $filePath');
    return filePath;
  }

  /// List downloaded models
  Future<List<String>> listDownloadedModels() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(dir.path, 'models'));
      
      if (!await modelsDir.exists()) return [];
      
      final files = await modelsDir
        .list()
        .where((f) => f.path.endsWith('.gguf'))
        .map((f) => path.basename(f.path))
        .toList();
      
      return files;
    } catch (e) {
      debugPrint('LlamaCpp: Failed to list models: $e');
      return [];
    }
  }

  void dispose() {
    _impl.dispose();
    _initialized = false;
  }
}
