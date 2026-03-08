import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_avatar_chat/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AiAvatarChatApp()),
    );

    expect(find.text('AI Avatar Chat'), findsOneWidget);
  });
}
