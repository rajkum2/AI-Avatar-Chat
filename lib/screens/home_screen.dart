import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../features/avatar/avatar_widget.dart';
import '../features/chat/chat_provider.dart';
import '../features/conversation/conversation_flow.dart';
import '../features/conversation/conversation_state.dart';
import '../widgets/mic_button.dart';
import '../widgets/transcript_overlay.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationState = ref.watch(conversationStateProvider);

    // Listen for error messages and show SnackBar
    ref.listen<String>(errorMessageProvider, (previous, next) {
      if (next.isNotEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          ),
        );
        Future.microtask(() {
          ref.read(errorMessageProvider.notifier).state = '';
        });
      }
    });

    final persistentError = ref.watch(persistentErrorProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Color(0xFF0B1120),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Title bar ──
              _buildTitleBar(context, ref),

              // ── Divider ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Divider(
                  height: 1,
                  color: AppColors.surfaceLight.withValues(alpha: 0.2),
                ),
              ),

              // ── Persistent error banner ──
              if (persistentError.isNotEmpty)
                _buildErrorBanner(persistentError, ref),

              // ── Avatar area — 55% ──
              const Expanded(
                flex: 55,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AvatarWidget(),
                ),
              ),

              // ── Status + Transcript + Mic ──
              _buildBottomSection(conversationState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Text(
              'AI Avatar Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear conversation',
              onPressed: () {
                ref.read(chatHistoryProvider.notifier).clearHistory();
                ref.read(conversationStateProvider.notifier).resetToIdle();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation cleared'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Settings',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.active.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.active,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(persistentErrorProvider.notifier).state = '';
            },
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(ConversationState conversationState) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.surface.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          StatusIndicator(),

          // Transcript area — constrained height, scrollable
          SizedBox(
            height: 80,
            child: TranscriptOverlay(),
          ),

          // Mic button with bottom padding
          Padding(
            padding: EdgeInsets.only(bottom: 32, top: 8),
            child: MicButton(),
          ),
        ],
      ),
    );
  }
}
