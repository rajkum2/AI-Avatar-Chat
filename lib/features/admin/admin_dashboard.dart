
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../features/chat/chat_service.dart' show llmSettingsManagerProvider;
import '../../features/chat/unified_llm_service.dart';
import '../../features/settings/llm_settings.dart';

/// Admin dashboard for managing LLM providers and settings
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  late LLMSettings _tempSettings;
  bool _hasChanges = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _tempSettings = ref.read(llmSettingsManagerProvider).settings;
  }

  void _updateSettings(LLMSettings newSettings) {
    setState(() {
      _tempSettings = newSettings;
      _hasChanges = true;
      _testResult = null;
    });
  }

  Future<void> _saveSettings() async {
    await ref.read(llmSettingsManagerProvider).updateSettings(_tempSettings);
    
    // Update the unified service
    ref.read(unifiedLLMServiceProvider).updateSettings(_tempSettings);
    
    setState(() {
      _hasChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final service = ref.read(unifiedLLMServiceProvider);
      service.updateSettings(_tempSettings);
      
      final available = await service.checkAvailability();
      
      setState(() {
        _isTesting = false;
        _testResult = available ? '✅ Connection successful!' : '❌ Connection failed';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testResult = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSettings = ref.watch(llmSettingsManagerProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('LLM Settings'),
        actions: [
          if (_hasChanges)
            TextButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('SAVE'),
            ),
        ],
      ),
      body: currentSettings.initialized
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentProviderCard(),
          const SizedBox(height: 24),
          _buildProviderSelector(),
          const SizedBox(height: 24),
          _buildProviderSettings(),
          const SizedBox(height: 24),
          _buildTestConnection(),
          const SizedBox(height: 24),
          _buildAdvancedSettings(),
        ],
      ),
    );
  }

  Widget _buildCurrentProviderCard() {
    final unifiedService = ref.read(unifiedLLMServiceProvider);
    
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Current Provider',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              unifiedService.currentProviderInfo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tempSettings.provider.description,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    final settingsManager = ref.read(llmSettingsManagerProvider);
    final availableProviders = settingsManager.getAvailableProviders();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Provider',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...LLMProviderType.values.map((provider) {
          final isAvailable = availableProviders.contains(provider);
          final isSelected = _tempSettings.provider == provider;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProviderCard(
              provider: provider,
              isSelected: isSelected,
              isAvailable: isAvailable,
              onTap: isAvailable
                  ? () => _updateSettings(_tempSettings.copyWith(provider: provider))
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProviderSettings() {
    switch (_tempSettings.provider) {
      case LLMProviderType.kimi:
        return _KimiSettings(
          apiKey: _tempSettings.kimiApiKey ?? '',
          onChanged: (value) => _updateSettings(
            _tempSettings.copyWith(kimiApiKey: value),
          ),
        );
      case LLMProviderType.ollama:
        return _OllamaSettings(
          url: _tempSettings.ollamaUrl ?? 'http://localhost:11434',
          model: _tempSettings.ollamaModel ?? 'llama3.2:3b',
          onUrlChanged: (value) => _updateSettings(
            _tempSettings.copyWith(ollamaUrl: value),
          ),
          onModelChanged: (value) => _updateSettings(
            _tempSettings.copyWith(ollamaModel: value),
          ),
        );
      case LLMProviderType.backend:
        return _BackendSettings(
          url: _tempSettings.backendUrl ?? '',
          onChanged: (value) => _updateSettings(
            _tempSettings.copyWith(backendUrl: value),
          ),
        );
      case LLMProviderType.selfHosted:
        return _SelfHostedSettings(
          url: _tempSettings.selfHostedUrl ?? '',
          model: _tempSettings.selfHostedModel ?? '',
          onUrlChanged: (value) => _updateSettings(
            _tempSettings.copyWith(selfHostedUrl: value),
          ),
          onModelChanged: (value) => _updateSettings(
            _tempSettings.copyWith(selfHostedModel: value),
          ),
        );
      case LLMProviderType.llamaCpp:
        return _LlamaCppSettings(
          modelPath: _tempSettings.llamaCppModelPath ?? '',
          onChanged: (value) => _updateSettings(
            _tempSettings.copyWith(llamaCppModelPath: value),
          ),
        );
      case LLMProviderType.webGPU:
        return _WebGPUSettings(
          model: _tempSettings.webGpuModel ?? 'Xenova/Phi-3-mini-4k-instruct',
          onChanged: (value) => _updateSettings(
            _tempSettings.copyWith(webGpuModel: value),
          ),
        );
    }
  }

  Widget _buildTestConnection() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Connection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Temperature',
              value: _tempSettings.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) => _updateSettings(
                _tempSettings.copyWith(temperature: value),
              ),
            ),
            _buildSlider(
              label: 'Max Tokens',
              value: _tempSettings.maxTokens.toDouble(),
              min: 50,
              max: 500,
              divisions: 45,
              onChanged: (value) => _updateSettings(
                _tempSettings.copyWith(maxTokens: value.toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary)),
            Text(
              value.toStringAsFixed(label == 'Temperature' ? 1 : 0),
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Provider selection card
class _ProviderCard extends StatelessWidget {
  final LLMProviderType provider;
  final bool isSelected;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _ProviderCard({
    required this.provider,
    required this.isSelected,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _getIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        color: isAvailable ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.primary)
              else if (!isAvailable)
                Icon(Icons.lock, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIcon() {
    IconData icon;
    Color color;
    
    switch (provider) {
      case LLMProviderType.kimi:
        icon = Icons.cloud;
        color = Colors.blue;
      case LLMProviderType.ollama:
        icon = Icons.computer;
        color = Colors.green;
      case LLMProviderType.backend:
        icon = Icons.dns;
        color = Colors.orange;
      case LLMProviderType.selfHosted:
        icon = Icons.storage;
        color = Colors.purple;
      case LLMProviderType.llamaCpp:
        icon = Icons.phone_android;
        color = Colors.teal;
      case LLMProviderType.webGPU:
        icon = Icons.web;
        color = Colors.cyan;
    }
    
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// Settings widgets for each provider
class _KimiSettings extends StatelessWidget {
  final String apiKey;
  final ValueChanged<String> onChanged;

  const _KimiSettings({required this.apiKey, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Kimi API Settings',
      children: [
        _TextField(
          label: 'API Key',
          value: apiKey,
          hint: 'sk-...',
          obscureText: true,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Get your API key from platform.moonshot.cn',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _OllamaSettings extends StatelessWidget {
  final String url;
  final String model;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onModelChanged;

  const _OllamaSettings({
    required this.url,
    required this.model,
    required this.onUrlChanged,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Ollama Settings',
      children: [
        _TextField(
          label: 'Ollama URL',
          value: url,
          hint: 'http://localhost:11434',
          onChanged: onUrlChanged,
        ),
        const SizedBox(height: 16),
        _TextField(
          label: 'Model',
          value: model,
          hint: 'llama3.2:3b',
          onChanged: onModelChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure Ollama is installed and running. Run: ollama pull $model',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _BackendSettings extends StatelessWidget {
  final String url;
  final ValueChanged<String> onChanged;

  const _BackendSettings({required this.url, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Backend Server Settings',
      children: [
        _TextField(
          label: 'Backend URL',
          value: url,
          hint: 'http://localhost:3000',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelfHostedSettings extends StatelessWidget {
  final String url;
  final String model;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onModelChanged;

  const _SelfHostedSettings({
    required this.url,
    required this.model,
    required this.onUrlChanged,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Self-Hosted vLLM Settings',
      children: [
        _TextField(
          label: 'Server URL',
          value: url,
          hint: 'http://your-server:8000/v1',
          onChanged: onUrlChanged,
        ),
        const SizedBox(height: 16),
        _TextField(
          label: 'Model Name',
          value: model,
          hint: 'meta-llama/Llama-3.2-3B-Instruct',
          onChanged: onModelChanged,
        ),
      ],
    );
  }
}

class _LlamaCppSettings extends StatelessWidget {
  final String modelPath;
  final ValueChanged<String> onChanged;

  const _LlamaCppSettings({required this.modelPath, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'On-Device Model Settings',
      children: [
        _TextField(
          label: 'Model Path',
          value: modelPath,
          hint: '/path/to/model.gguf',
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Download .gguf models from huggingface.co',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _WebGPUSettings extends StatelessWidget {
  final String model;
  final ValueChanged<String> onChanged;

  const _WebGPUSettings({required this.model, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'WebGPU Model Settings',
      children: [
        _TextField(
          label: 'Model ID',
          value: model,
          hint: 'Xenova/Phi-3-mini-4k-instruct',
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Requires Chrome/Edge with WebGPU support. Model will be cached in browser.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final bool obscureText;
  final ValueChanged<String> onChanged;

  const _TextField({
    required this.label,
    required this.value,
    required this.hint,
    this.obscureText = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      obscureText: obscureText,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
