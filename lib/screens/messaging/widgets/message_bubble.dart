import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../models/messaging/chat_message.dart';
import '../../../models/messaging/chat_user.dart';
import '../photo_viewer_screen.dart';
import 'chat_avatar.dart';

/// One message in the thread, drawn the way the web bubbles are: mine on
/// the right in blue, theirs on the left in white, system lines centred,
/// calls as a small card with "Call again", photos inline, files as a chip,
/// a quote above a reply, and @Name chips (amber when it is me).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.isGroup,
    required this.showSender,
    required this.showAvatar,
    required this.showStatus,
    required this.myId,
    required this.imageHeaders,
    this.seenBy = const [],
    this.onLongPress,
    this.onRetry,
    this.onCallAgain,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final bool mine;
  final bool isGroup;
  final bool showSender;
  final bool showAvatar;

  /// Sent / Delivered / Seen under my latest message.
  final bool showStatus;
  final int myId;
  final Map<String, String> imageHeaders;
  final List<ChatUser> seenBy;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final VoidCallback? onCallAgain;
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final m = message;

    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Text(
          m.body ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      );
    }

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: m.isCall ? _callCard(context) : _bubble(context),
    );

    return Padding(
      padding: EdgeInsets.only(top: showSender ? 8 : 2, bottom: 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 2),
              child: Text(
                m.sender?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine)
                SizedBox(
                  width: 36,
                  child: showAvatar
                      ? ChatAvatar(initial: m.sender?.initial ?? '?', url: m.sender?.avatarUrl, size: 28)
                      : null,
                ),
              if (!mine) const SizedBox(width: 6),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: bubble,
                ),
              ),
            ],
          ),
          if (m.failed)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: GestureDetector(
                onTap: onRetry,
                child: const Text('Not sent · Retry', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
            )
          else if (showStatus)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: _status(),
            ),
        ],
      ),
    );
  }

  Widget _status() {
    if (isGroup) {
      if (seenBy.isEmpty) {
        return Text(message.sending ? 'Sending…' : 'Sent', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted));
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Seen by ', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          for (final u in seenBy.take(5))
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: ChatAvatar(initial: u.initial, url: u.avatarUrl, size: 14),
            ),
          if (seenBy.length > 5) Text(' +${seenBy.length - 5}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      );
    }

    final label = switch (message.status) {
      'seen' => 'Seen',
      'delivered' => 'Delivered',
      'sending' => 'Sending…',
      _ => message.sending ? 'Sending…' : 'Sent',
    };
    return Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted));
  }

  Widget _bubble(BuildContext context) {
    final m = message;
    final bg = m.unsent ? Colors.transparent : (mine ? AppColors.primary : Colors.white);
    final fg = mine && !m.unsent ? Colors.white : AppColors.textDark;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 6),
      bottomRight: Radius.circular(mine ? 6 : 18),
    );

    if (m.unsent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: radius),
        child: const Text('Message unsent', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
      );
    }

    final att = m.attachment;
    final children = <Widget>[];

    if (m.replyTo != null) {
      final q = m.replyTo!;
      children.add(GestureDetector(
        onTap: onQuoteTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: mine ? Colors.white.withValues(alpha: 0.18) : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: mine ? Colors.white70 : AppColors.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.senderId == myId ? 'You' : (q.senderName ?? 'Someone'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.85)),
              ),
              Text(q.preview, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.85), fontStyle: q.unsent ? FontStyle.italic : FontStyle.normal)),
            ],
          ),
        ),
      ));
    }

    if (att != null && att.isImage) {
      children.add(GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PhotoViewerScreen(url: att.url, headers: imageHeaders, title: att.name)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            att.url,
            headers: imageHeaders,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(width: 220, height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (_, _, _) => const SizedBox(
              width: 220,
              height: 80,
              child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
            ),
          ),
        ),
      ));
    } else if (att != null) {
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 20, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(att.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                Text(att.readableSize, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ));
    }

    if ((m.body ?? '').isNotEmpty) {
      if (att != null) children.add(const SizedBox(height: 6));
      children.add(_richBody(m.body!, fg));
    } else if (att == null && m.sending) {
      children.add(Text('Sending…', style: TextStyle(fontSize: 13, color: fg)));
    }

    return Container(
      padding: att != null && att.isImage && (m.body ?? '').isEmpty && m.replyTo == null
          ? const EdgeInsets.all(3)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: mine ? null : Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// Renders "@Full Name" mentions as chips inside the text.
  Widget _richBody(String body, Color fg) {
    final names = <String>[];
    final mentionsMe = message.mentions.contains(myId);
    // Names are not carried with the message, so any "@Word Word" run is
    // treated as a mention chip; the amber colour marks one that is me.
    final pattern = RegExp(r'@([A-Z][\w.\-]*(?:\s[A-Z][\w.\-]*)*)');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(body)) {
      if (match.start > last) spans.add(TextSpan(text: body.substring(last, match.start)));
      names.add(match.group(1)!);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: mentionsMe ? const Color(0xFFFFE7B3) : (mine ? Colors.white.withValues(alpha: 0.22) : AppColors.chipBackground),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '@${match.group(1)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mentionsMe ? const Color(0xFF7A4B00) : (mine ? Colors.white : AppColors.primary),
            ),
          ),
        ),
      ));
      last = match.end;
    }
    if (last < body.length) spans.add(TextSpan(text: body.substring(last)));

    if (names.isEmpty) {
      return Text(body, style: TextStyle(fontSize: 14.5, color: fg, height: 1.35));
    }
    return Text.rich(TextSpan(children: spans, style: TextStyle(fontSize: 14.5, color: fg, height: 1.35)));
  }

  Widget _callCard(BuildContext context) {
    final call = message.call!;
    final missed = call.status == 'missed' || call.status == 'declined';
    final icon = call.type == 'video' ? Icons.videocam_outlined : Icons.call_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: missed ? const Color(0xFFFFF1F1) : AppColors.chipBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: missed ? AppColors.danger : AppColors.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(call.label(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: missed ? AppColors.danger : AppColors.textDark)),
              if (onCallAgain != null)
                GestureDetector(
                  onTap: onCallAgain,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Call again', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Drag a bubble to the right to reply to it (Messenger / WhatsApp style).
/// The bubble follows the finger up to a short distance with a reply arrow
/// fading in behind it; letting go past the threshold fires [onReply].
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply, this.enabled = true});

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _max = 72.0;
  static const _threshold = 48.0;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() => setState(() => _offset = _snapFrom * (1 - _snap.value)));

  double _offset = 0;
  double _snapFrom = 0;
  bool _fired = false;

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    setState(() {
      _offset = (_offset + d.delta.dx).clamp(0.0, _max);
      if (_offset >= _threshold && !_fired) {
        _fired = true;
        HapticFeedback.selectionClick();
      } else if (_offset < _threshold) {
        _fired = false;
      }
    });
  }

  void _onEnd(DragEndDetails _) {
    if (_offset >= _threshold) widget.onReply();
    _snapFrom = _offset;
    _fired = false;
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_offset / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => _onEnd(DragEndDetails()),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_offset > 0)
            Positioned(
              left: 8,
              child: Opacity(
                opacity: progress,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: progress >= 1 ? AppColors.primary : AppColors.chipBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.reply, size: 17, color: progress >= 1 ? Colors.white : AppColors.primary),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_offset, 0), child: widget.child),
        ],
      ),
    );
  }
}
