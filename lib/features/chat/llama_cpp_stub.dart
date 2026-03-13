/// Stub implementation for web (dart:ffi not available)
class LlamaCppImpl {
  Future<void> initialize(String? modelPath) async {
    throw UnsupportedError('llama.cpp FFI not available on web');
  }

  Stream<String> generate(String prompt, int maxTokens) async* {
    throw UnsupportedError('llama.cpp FFI not available on web');
  }

  void dispose() {}
}
