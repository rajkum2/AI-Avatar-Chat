import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../features/avatar/avatar_widget.dart';
import '../features/chat/chat_provider.dart';
import '../features/conversation/conversation_flow.dart';
import '../widgets/mic_button.dart';
import '../widgets/transcript_overlay.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        // Clear the error after showing
        Future.microtask(() {
          ref.read(errorMessageProvider.notifier).state = '';
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App title bar — 60px
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Avatar Chat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Clear conversation',
                          onPressed: () {
                            ref
                                .read(chatHistoryProvider.notifier)
                                .clearHistory();
                            ref
                                .read(conversationStateProvider.notifier)
                                .resetToIdle();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Conversation cleared'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Avatar area — 55% of remaining height
            const Expanded(
              flex: 55,
              child: Center(
                child: AvatarWidget(),
              ),
            ),

            // Status indicator — 40px
            const StatusIndicator(),

            // Transcript area — 80px
            const SizedBox(
              height: 80,
              child: TranscriptOverlay(),
            ),

            // Mic button — centered, 40px from bottom
            const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Center(
                child: MicButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
