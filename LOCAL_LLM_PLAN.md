# AI Avatar Chat - Local LLM Integration Plan

## Executive Summary

Replace paid AI providers (Kimi/Claude) with local or self-hosted open-source LLMs. This plan covers multiple deployment strategies from edge devices to self-hosted servers.

## Architecture Options

### Option 1: Local LLM via Ollama (Recommended for Desktop/Web)
```
Flutter App → Ollama API (localhost:11434) → Local Model
```

### Option 2: llama.cpp with FFI (Mobile-First)
```
Flutter App → llama.cpp (Dart FFI) → On-Device Model
```

### Option 3: WebGPU in Browser (Web-Only)
```
Flutter Web → wasm + WebGPU → Browser-Running Model
```

### Option 4: Self-Hosted Server (Multi-User)
```
Flutter App → Your Backend → vLLM/llama.cpp server → GPU Server
```

---

## Option 1: Ollama Integration (Easiest)

### Overview
Ollama provides a simple HTTP API for running local models. Best for:
- macOS/Linux desktop apps
- Web apps with local Ollama
- Rapid prototyping

### Pros
- Simple REST API (OpenAI-compatible)
- Easy model management (`ollama pull llama3.2`)
- Streaming support
- No Flutter code changes needed (just URL swap)

### Cons
- Requires separate Ollama installation
- Not feasible for mobile (models too large)
- Desktop only

### Implementation

#### 1.1 New Files
```
lib/
├── features/
│   └── chat/
│       ├── local_llm_service.dart      # Ollama client
│       └── llm_provider.dart           # Provider selector
```

#### 1.2 Service Implementation
```dart
// lib/features/chat/ollama_service.dart
class OllamaService implements ChatServiceInterface {
  static const String baseUrl = 'http://localhost:11434';
  static const String model = 'llama3.2'; // or phi3, mistral, etc.
  
  Stream<String> streamMessage(String message, List<ChatMessage> history) async* {
    final response = await http.post(
      Uri.parse('$baseUrl/api/generate'),
      body: jsonEncode({
        'model': model,
        'prompt': _buildPrompt(message, history),
        'stream': true,
        'options': {
          'temperature': 0.7,
          'num_predict': 150,  // Max tokens
        },
      }),
    );
    
    // Handle SSE streaming
    await for (final chunk in response.body) {
      final data = jsonDecode(chunk);
      yield data['response'];
    }
  }
}
```

#### 1.3 Prompt Format
```dart
String _buildPrompt(String message, List<ChatMessage> history) {
  final buffer = StringBuffer();
  buffer.writeln('<|system|>');
  buffer.writeln('You are a friendly AI assistant. Keep responses to 2-3 sentences maximum.');
  buffer.writeln('<|end|>');
  
  for (final msg in history) {
    buffer.writeln('<|${msg.role}|>');
    buffer.writeln(msg.content);
    buffer.writeln('<|end|>');
  }
  
  buffer.writeln('<|user|>');
  buffer.writeln(message);
  buffer.writeln('<|end|>');
  buffer.writeln('<|assistant|>');
  
  return buffer.toString();
}
```

### Model Recommendations for Ollama

| Model | Size | Quality | Speed | Best For |
|-------|------|---------|-------|----------|
| llama3.2:1b | 1.3GB | ⭐⭐ | ⭐⭐⭐⭐⭐ | Ultra-fast, simple responses |
| llama3.2:3b | 2.0GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | Good balance |
| phi3:mini | 1.8GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | Microsoft, good instruction following |
| gemma2:2b | 1.6GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | Google, compact |
| qwen2.5:3b | 2.0GB | ⭐⭐⭐⭐ | ⭐⭐⭐ | Alibaba, multilingual |

---

## Option 2: On-Device llama.cpp (Mobile-First)

### Overview
Run models directly on mobile devices using llama.cpp via Dart FFI. Best for:
- Complete offline operation
- Privacy-sensitive applications
- Mobile apps without backend

### Pros
- True offline operation
- No server needed
- Complete privacy

### Cons
- Limited to small models (1-3B parameters on mobile)
- Complex FFI integration
- Battery impact
- Slower than cloud APIs

### Implementation

#### 2.1 Dependencies
```yaml
# pubspec.yaml
dependencies:
  ffi: ^2.1.0
  path_provider: ^2.1.0
  path: ^1.9.0

dev_dependencies:
  ffigen: ^11.0.0
```

#### 2.2 New Files
```
lib/
├── core/
│   └── ffi/
│       ├── llama_bindings.dart       # Auto-generated FFI bindings
│       ├── llama_manager.dart        # Model loading/management
│       └── llama_inference.dart      # Inference engine
android/
├── src/
│   └── main/
│       └── jniLibs/
│           └── arm64-v8a/
│               └── libllama.so       # Compiled llama.cpp
ios/
├── Frameworks/
│   └── llama.xcframework             # Compiled llama.cpp
```

#### 2.3 Model Manager
```dart
// lib/core/ffi/llama_manager.dart
class LlamaManager {
  static const String modelFile = 'llama3.2-1b-q4_0.gguf';
  
  DynamicLibrary? _lib;
  Pointer<Void>? _model;
  Pointer<Void>? _ctx;
  
  Future<void> loadModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = path.join(dir.path, 'models', modelFile);
    
    // Download if not exists
    if (!File(modelPath).existsSync()) {
      await _downloadModel(modelFile);
    }
    
    // Load native library
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libllama.so')
        : DynamicLibrary.process();
    
    // Initialize llama.cpp
    _model = _initModel(modelPath);
    _ctx = _createContext(_model);
  }
  
  Stream<String> generate(String prompt) async* {
    // Tokenize prompt
    final tokens = _tokenize(prompt);
    
    // Generate tokens one by one
    for (var i = 0; i < maxTokens; i++) {
      final token = _sampleToken(_ctx);
      final text = _tokenToString(token);
      yield text;
      
      if (_isEosToken(token)) break;
    }
  }
}
```

#### 2.4 Platform Setup

**Android (build.gradle)**
```kotlin
android {
    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
        }
    }
}
```

**iOS (Podfile)**
```ruby
# Build llama.cpp as static library
# Use pre-built xcframework or build from source
```

### Mobile-Optimized Models

| Model | Quantization | Size | RAM Usage | Device Target |
|-------|--------------|------|-----------|---------------|
| Llama 3.2 1B | Q4_0 | 0.7GB | 1.2GB | Mid-range phones |
| Llama 3.2 3B | Q4_K_M | 1.9GB | 3GB | Flagship phones |
| Phi-3 Mini | Q4_0 | 1.8GB | 2.8GB | Modern phones |
| Gemma 2 2B | Q4_0 | 1.6GB | 2.5GB | Modern phones |
| Qwen 2.5 1.5B | Q4_0 | 1.0GB | 1.8GB | Mid-range phones |

---

## Option 3: WebGPU in Browser (Web-Only)

### Overview
Run models directly in the browser using WebGPU and WASM. Best for:
- Web apps without backend
- Privacy-preserving web apps
- Zero server costs

### Pros
- No backend infrastructure
- Runs entirely in browser
- WebGPU acceleration

### Cons
- Web only (not mobile apps)
- WebGPU support limited (Chrome/Edge only)
- First load is slow (model download)
- Limited model size (browser storage)

### Implementation

#### 3.1 Using Transformers.js
```html
<!-- web/index.html -->
<script type="module">
  import { pipeline } from 'https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2';
  
  const generator = await pipeline(
    'text-generation',
    'Xenova/Phi-3-mini-4k-instruct',
    { dtype: 'q4' }
  );
  
  // Expose to Flutter
  window.llmGenerate = async (prompt) => {
    const output = await generator(prompt, {
      max_new_tokens: 128,
      temperature: 0.7,
    });
    return output[0].generated_text;
  };
</script>
```

#### 3.2 Flutter Integration
```dart
// lib/features/chat/web_llm_service.dart
import 'dart:js' as js;

class WebLLMService implements ChatServiceInterface {
  @override
  Stream<String> streamMessage(String message, List<ChatMessage> history) async* {
    final prompt = _buildPrompt(message, history);
    
    // Call JavaScript function
    final result = await js.context.callMethod('llmGenerate', [prompt]);
    
    // For streaming, use a callback-based approach
    yield result;
  }
}
```

#### 3.3 Model Options for Web

| Model | Size | Format | Provider |
|-------|------|--------|----------|
| Phi-3 Mini | 1.8GB | ONNX | Xenova/transformers.js |
| Gemma 2B | 1.6GB | ONNX | Xenova/transformers.js |
| TinyLlama 1.1B | 0.6GB | ONNX | Xenova/transformers.js |
| Qwen2 0.5B | 0.4GB | ONNX | Xenova/transformers.js |

---

## Option 4: Self-Hosted Server (Multi-User)

### Overview
Self-host LLM on your own GPU server. Best for:
- Multi-user applications
- Larger models (7B-70B)
- Production deployments
- Cost savings at scale

### Pros
- Full control over models
- Larger models possible
- Multi-user support
- API-compatible with OpenAI

### Cons
- GPU infrastructure costs
- DevOps complexity
- Network latency

### Implementation

#### 4.1 Server Options

**Option A: vLLM (Recommended)**
```bash
# Server setup
pip install vllm

# Run server
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.2-3B-Instruct \
  --quantization awq \
  --port 8000
```

**Option B: text-generation-inference (TGI)**
```bash
docker run --gpus all \
  -p 8080:80 \
  -v $PWD/data:/data \
  ghcr.io/huggingface/text-generation-inference:2.0 \
  --model-id meta-llama/Llama-3.2-3B-Instruct
```

**Option C: llama.cpp server**
```bash
./server \
  -m models/llama-3.2-3b-q4_K_M.gguf \
  --port 8080 \
  -c 4096
```

#### 4.2 Flutter Integration

The existing backend chat service can be pointed to your self-hosted server:

```dart
// lib/core/env.dart
static String get backendUrl =>
    dotenv.env['BACKEND_URL'] ?? 'http://your-server:8000/v1';
```

Or use the existing `ChatService` with modified constants:

```dart
// lib/core/constants.dart
static const String kimiApiUrl = 'http://your-server:8000/v1/chat/completions';
```

### Server Hardware Requirements

| Model Size | GPU VRAM | RAM | Example GPU | Users |
|------------|----------|-----|-------------|-------|
| 3B Q4 | 4GB | 8GB | RTX 3060 | 5-10 |
| 7B Q4 | 8GB | 16GB | RTX 4070 | 3-5 |
| 13B Q4 | 16GB | 32GB | RTX 4090 | 2-3 |
| 70B Q4 | 48GB | 64GB | A6000/A100 | 1 |

---

## Unified Provider Architecture

### Provider Selection Strategy
```dart
// lib/features/chat/llm_provider.dart
enum LLMProvider {
  kimi,           // Paid API (current)
  ollama,         // Local desktop
  llamaCpp,       // On-device mobile
  webGPU,         // Browser
  selfHosted,     // Your server
}

final llmProvider = Provider<ChatServiceInterface>((ref) {
  switch (Env.llmProvider) {
    case 'ollama':
      return OllamaService();
    case 'llama_cpp':
      return LlamaCppService();
    case 'web_gpu':
      return WebLLMService();
    case 'self_hosted':
      return SelfHostedService();
    default:
      return ChatService(); // Kimi
  }
});
```

### Environment Configuration
```bash
# .env - Choose your provider
LLM_PROVIDER=ollama          # Options: kimi, ollama, llama_cpp, web_gpu, self_hosted

# Ollama specific
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b

# Self-hosted specific
SELF_HOSTED_URL=http://your-server:8000/v1
SELF_HOSTED_MODEL=meta-llama/Llama-3.2-3B-Instruct

# llama.cpp mobile specific
LLAMA_MODEL_PATH=models/llama-3.2-1b-q4_0.gguf
```

---

## Implementation Roadmap

### Phase 1: Ollama Desktop (Week 1)
1. Create `OllamaService` class
2. Add prompt formatting for chat templates
3. Test with llama3.2, phi3
4. Update UI to show "Local Mode" indicator

### Phase 2: Self-Hosted Server (Week 2)
1. Set up vLLM or TGI on GPU server
2. Create deployment scripts (Docker)
3. Point existing backend to self-hosted
4. Add health checks and fallbacks

### Phase 3: Mobile On-Device (Week 3-4)
1. Set up FFI bindings for llama.cpp
2. Implement model download/management
3. Create native plugins for iOS/Android
4. Optimize for battery/thermal

### Phase 4: WebGPU (Week 5)
1. Integrate transformers.js
2. Model loading UI (progress bar)
3. Browser storage for model cache
4. WebGPU detection and fallback

---

## Recommended Model per Platform

### Desktop (macOS/Windows/Linux)
- **Primary**: Llama 3.2 3B (Q4_K_M)
- **Fallback**: Phi-3 Mini 3.8B
- **High-end**: Llama 3.1 8B (Q4)

### Mobile (iOS/Android)
- **Budget devices**: Llama 3.2 1B
- **Modern phones**: Llama 3.2 3B or Phi-3 Mini
- **Tablets**: Qwen 2.5 7B (Q4)

### Web
- **Fast**: TinyLlama 1.1B
- **Balanced**: Phi-3 Mini
- **Quality**: Gemma 2 2B

### Server
- **Entry**: Llama 3.2 3B (single GPU)
- **Balanced**: Llama 3.1 8B (single GPU)
- **Advanced**: Mixtral 8x7B (multi-GPU)

---

## Performance Benchmarks

### Response Latency (Tokens/Second)

| Model | Platform | tok/s | Time for 50 tokens |
|-------|----------|-------|-------------------|
| Llama 3.2 1B | M1 Mac | ~40 | 1.2s |
| Llama 3.2 3B | M1 Mac | ~25 | 2.0s |
| Llama 3.2 3B | iPhone 15 | ~8 | 6.2s |
| Llama 3.2 1B | Pixel 7 | ~12 | 4.1s |
| Phi-3 Mini | RTX 4090 | ~80 | 0.6s |
| Kimi API | Cloud | ~50 | 1.0s |

---

## Next Steps

1. **Choose your target platforms** (Desktop/Mobile/Web/Server)
2. **Start with Ollama** for rapid prototyping
3. **Benchmark on your target hardware**
4. **Implement FFI for mobile** if needed
5. **Set up self-hosted** for production

Would you like me to implement any of these options? I recommend starting with **Option 1 (Ollama)** for desktop or **Option 4 (Self-Hosted)** if you have a GPU server, as they're the fastest to implement.
