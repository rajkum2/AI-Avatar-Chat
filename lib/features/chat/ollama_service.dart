import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/env.dart';
import 'chat_message.dart';
import 'chat_service_interface.dart';

/// Ollama-based local LLM service
/// Requires Ollama running locally: https://ollama.com
/// 
/// Quick start:
/// 1. Install Ollama
/// 2. Run: ollama pull llama3.2:3b
/// 3. Ollama runs automatically on localhost:11434
/// 4. Set LLM_PROVIDER=ollama in .env
class OllamaService implements ChatServiceInterface {
  final http.Client _client = http.Client();
  
  String get baseUrl => Env.ollamaUrl;
  String get model => Env.ollamaModel;
  
  bool _available = false;
  bool get isAvailable => _available;

  /// Check if Ollama is running
  Future<bool> checkAvailability() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 3));
      
      _available = response.statusCode == 200;
      if (_available) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List?)
            ?.map((m) => m['name'] as String?)
            .where((name) => name != null)
            .toList();
        debugPrint('Ollama: Available with models: $models');
      }
      return _available;
    } catch (e) {
      debugPrint('Ollama: Not available - $e');
      _available = false;
      return false;
    }
  }

  @override
  Future<void> warmUp() async {
    await checkAvailability();
  }

  @override
  Stream<String> streamMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async* {
    if (!_available) {
      final available = await checkAvailability();
      if (!available) {
        throw ChatException(
          'Ollama not running. Install from ollama.com and run: ollama pull $model'
        );
      }
    }

    final prompt = _buildPrompt(userMessage, history);
    
    debugPrint('Ollama: Generating with $model');
    final stopwatch = Stopwatch()..start();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/generate'),
      );
      
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': true,
        'options': {
          'temperature': 0.7,
          'num_predict': 150,
          'top_p': 0.9,
          'repeat_penalty': 1.1,
        },
      });

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ChatException('Ollama error: ${response.statusCode} - $body');
      }

      // Ollama returns NDJSON (newline-delimited JSON)
      String buffer = '';
      await for (final bytes in response.stream) {
        buffer += utf8.decode(bytes);
        
        // Process complete lines
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);
          
          if (line.isEmpty) continue;
          
          try {
            final data = jsonDecode(line);
            final text = data['response'] as String?;
            final done = data['done'] as bool? ?? false;
            
            if (text != null && text.isNotEmpty) {
              yield text;
            }
            
            if (done) {
              stopwatch.stop();
              final evalCount = data['eval_count'] as int? ?? 0;
              final tokPerSec = evalCount / (stopwatch.elapsedMilliseconds / 1000);
              debugPrint(
                'Ollama: Generated in ${stopwatch.elapsedMilliseconds}ms '
                '($evalCount tokens, ${tokPerSec.toStringAsFixed(1)} tok/s)'
              );
              return;
            }
          } catch (e) {
            debugPrint('Ollama: Failed to parse line: $line');
          }
        }
      }
    } on SocketException catch (e) {
      _available = false;
      throw ChatException(
        'Cannot connect to Ollama at $baseUrl. Is it running? ($e)'
      );
    } catch (e) {
      throw ChatException('Ollama request failed: $e');
    }
  }

  @override
  Future<String> sendMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async {
    final buffer = StringBuffer();
    await for (final chunk in streamMessage(userMessage, history)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// Build prompt with chat template
  String _buildPrompt(String message, List<ChatMessage> history) {
    final buffer = StringBuffer();
    
    // System prompt
    buffer.writeln('<|system|>');
    buffer.writeln(
      'You are a friendly, warm AI assistant embodied as an avatar. '
      'Keep ALL responses to exactly 2-3 sentences maximum because '
      'they will be spoken aloud. Be conversational, natural, and '
      'engaging. Never use bullet points, headers, or markdown in '
      'your replies. Speak as if having a real voice conversation.'
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

  /// Get list of available models from Ollama
  Future<List<String>> listModels() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List?)
            ?.map((m) => m['name'] as String?)
            .where((name) => name != null)
            .cast<String>()
            .toList() ?? [];
        return models;
      }
    } catch (e) {
      debugPrint('Ollama: Failed to list models: $e');
    }
    return [];
  }

  /// Pull a model (download)
  Future<void> pullModel(String modelName) async {
    debugPrint('Ollama: Pulling model $modelName...');
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );
      
      if (response.statusCode != 200) {
        throw ChatException('Failed to pull model: ${response.body}');
      }
      
      debugPrint('Ollama: Model $modelName pulled successfully');
    } catch (e) {
      throw ChatException('Failed to pull model: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
