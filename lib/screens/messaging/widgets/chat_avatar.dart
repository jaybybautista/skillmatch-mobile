import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Round avatar with an initial fallback and an optional green "online" dot,
/// the same shape the web chat list and thread header use.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.initial,
    this.url,
    this.size = 44,
    this.online = false,
    this.square = false,
  });

  final String initial;
  final String? url;
  final double size;
  final bool online;

  /// Group photos are drawn as rounded squares.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final radius = square ? BorderRadius.circular(size * 0.28) : BorderRadius.circular(size);

    Widget avatar = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Fallback(initial: initial, size: size),
              )
            : _Fallback(initial: initial, size: size),
      ),
    );

    if (!online) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: const Color(0xFF31A24C),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.chipBackground,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// "2:15 PM", "Yesterday", "Mon", "Sep 3" — the chat-list timestamp.
String chatListTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return clockTime(time);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][time.weekday - 1];
  return '${_months[time.month - 1]} ${time.day}${time.year != now.year ? ', ${time.year}' : ''}';
}

/// "2:15 PM".
String clockTime(DateTime time) {
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// The separator between groups of messages: "Today 2:15 PM", "Sep 3, 10:02 AM".
String threadSeparator(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Today ${clockTime(time)}';
  if (diff == 1) return 'Yesterday ${clockTime(time)}';
  return '${_months[time.month - 1]} ${time.day}${time.year != now.year ? ', ${time.year}' : ''}, ${clockTime(time)}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
