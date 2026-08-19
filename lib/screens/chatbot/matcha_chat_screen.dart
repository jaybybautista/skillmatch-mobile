import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/chat_message.dart';
import '../../services/chatbot_service.dart';
import 'chat_destinations.dart';

/// Matcha — the in-app assistant, opened from the floating button on Home.
///
/// Backed by the same `/chatbot` endpoint as the web panel, so it answers the
/// same way; "how do I…" questions come back with destination cards that
/// navigate straight to the screen in question.
class MatchaChatScreen extends StatefulWidget {
  const MatchaChatScreen({super.key, this.service});

  /// Injectable for tests; defaults to the real service.
  final ChatbotService? service;

  @override
  State<MatchaChatScreen> createState() => _MatchaChatScreenState();
}

class _MatchaChatScreenState extends State<MatchaChatScreen> {
  late final ChatbotService _service = widget.service ?? ChatbotService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  /// Shown under the conversation, mirroring the prompts in the mockup.
  static const _suggestions = [
    'Resume Tips',
    'How to improve my match rate?',
    'What internships fit my skills?',
    'How do I take an assessment?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    // History must not include the message being sent, or the server sees it
    // twice.
    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text, sentAt: DateTime.now()));
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        text: '',
        sentAt: DateTime.now(),
        isPending: true,
      ));
      _controller.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await _service.send(text, history);
      if (!mounted) return;

      setState(() {
        _messages
          ..removeLast()
          ..add(ChatMessage(
            role: ChatRole.assistant,
            text: reply.answer,
            sentAt: DateTime.now(),
            cards: reply.cards,
          ));
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e is ApiException
          ? e.message
          : "I couldn't reach the server. Please check your connection and try again.";

      setState(() {
        _messages
          ..removeLast()
          ..add(ChatMessage(
            role: ChatRole.assistant,
            text: message,
            sentAt: DateTime.now(),
            hasFailed: true,
          ));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _openCard(ChatCard card) {
    final destination = chatDestinationFor(card.screen);

    if (destination == null) {
      // Say why when we know, rather than a blanket "not available".
      final reason = unavailableReasonFor(card.screen)
          ?? '${card.title} isn\'t available in the app yet.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      return;
    }

    // The chat is a full-screen overlay, so close it before landing on the
    // destination — otherwise the student has to dismiss it afterwards.
    Navigator.of(context).pop();
    destination(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A3C), Color(0xFF141B8C), Color(0xFF0A0A3C)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: _CloseButton(onTap: () => Navigator.of(context).pop()),
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? const _Welcome()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _Bubble(
                          message: _messages[index],
                          onCardTap: _openCard,
                        ),
                      ),
              ),
              _SuggestionRow(
                suggestions: _suggestions,
                onTap: _isSending ? null : (text) => _send(text),
              ),
              _Composer(
                controller: _controller,
                focusNode: _focusNode,
                isSending: _isSending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// The empty state: logo, greeting, and what Matcha can help with.
class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/ai_chatbot_logo.png', width: 96, height: 96),
            const SizedBox(height: 22),
            Text(
              'Hello, I am Matcha!',
              textAlign: TextAlign.center,
              style: AppFonts.title(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me about internships, skills alignment, or resume creation. '
              "I'm here to assist you!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onCardTap});

  final ChatMessage message;
  final ValueChanged<ChatCard> onCardTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Image.asset('assets/ai_chatbot_logo.png', width: 30, height: 30),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                  ),
                  child: message.isPending
                      ? const _TypingDots()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RichAnswer(
                              text: message.text,
                              isError: message.hasFailed,
                            ),
                            for (final card in message.cards) ...[
                              const SizedBox(height: 12),
                              _DestinationCard(card: card, onTap: () => onCardTap(card)),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (!message.isPending)
            Padding(
              padding: EdgeInsets.only(top: 6, left: isUser ? 0 : 38, right: isUser ? 4 : 0),
              child: Text(
                message.timeLabel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders the `**bold**` emphasis the web answers use, so key terms stand out
/// here the same way they do in the panel.
class _RichAnswer extends StatelessWidget {
  const _RichAnswer({required this.text, required this.isError});

  final String text;
  final bool isError;

  static final _bold = RegExp(r'\*\*(.+?)\*\*', dotAll: true);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 14.5,
      height: 1.5,
      color: isError ? const Color(0xFFB3261E) : AppColors.textDark,
    );

    final spans = <TextSpan>[];
    var index = 0;

    for (final match in _bold.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      ));
      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}

/// A place Matcha is pointing at — tapping it goes there.
class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.card, required this.onTap});

  final ChatCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.code, size: 17, color: AppColors.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    card.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Each dot peaks a third of a cycle after the one before it.
              final phase = (_controller.value + i / 3) % 1.0;
              final lift = (phase < 0.5 ? phase : 1 - phase) * 2;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: 0.35 + lift * 0.65,
                  child: const SizedBox(
                    width: 7,
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Center(
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(text),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ask anything',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 15, color: AppColors.textDark),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: isSending ? AppColors.textMuted : AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isSending ? null : onSend,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
