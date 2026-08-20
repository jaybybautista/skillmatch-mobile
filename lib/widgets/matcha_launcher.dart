import 'package:flutter/material.dart';

import '../screens/chatbot/matcha_chat_screen.dart';
import 'draggable_chatbot_button.dart';

/// The Matcha launcher — a [DraggableChatbotButton] already wired to open the
/// chat.
///
/// The web renders its chatbot FAB from the shared layout, so it sits on every
/// page. This is the app's equivalent, which is why it's one widget rather
/// than the same five lines copied onto each screen.
///
/// Must be placed as a direct child of a [Stack]; see
/// [DraggableChatbotButton] for why.
class MatchaLauncher extends StatelessWidget {
  const MatchaLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableChatbotButton(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const MatchaChatScreen(),
        ),
      ),
    );
  }
}
