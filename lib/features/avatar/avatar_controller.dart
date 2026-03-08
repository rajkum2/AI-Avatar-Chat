import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'avatar_state.dart';
import '../conversation/conversation_state.dart';

final avatarStateProvider =
    StateNotifierProvider<AvatarController, AvatarState>((ref) {
  return AvatarController();
});

class AvatarController extends StateNotifier<AvatarState> {
  AvatarController() : super(AvatarState.idle);

  void updateFromConversation(ConversationState conversationState) {
    switch (conversationState) {
      case ConversationState.idle:
        state = AvatarState.idle;
      case ConversationState.listening:
        state = AvatarState.listening;
      case ConversationState.thinking:
        state = AvatarState.thinking;
      case ConversationState.speaking:
        state = AvatarState.speaking;
    }
  }
}
