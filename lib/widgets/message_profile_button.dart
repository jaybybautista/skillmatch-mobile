import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../screens/messaging/chat_thread_screen.dart';
import '../services/messaging_service.dart';

/// The "Message" button under a public profile: opens (or starts) the direct
/// chat with that account, like the button on the web profile pages. Hidden
/// when the profile has no account to write to (a company a coordinator
/// added by hand).
class MessageProfileButton extends StatefulWidget {
  const MessageProfileButton({super.key, required this.userId});

  final int? userId;

  @override
  State<MessageProfileButton> createState() => _MessageProfileButtonState();
}

class _MessageProfileButtonState extends State<MessageProfileButton> {
  bool _busy = false;

  Future<void> _open() async {
    final id = widget.userId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final conversation = await MessagingService.instance.open(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatThreadScreen(conversation: conversation)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy ? null : _open,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 17),
          label: Text(_busy ? 'Opening…' : 'Message'),
        ),
      ),
    );
  }
}
