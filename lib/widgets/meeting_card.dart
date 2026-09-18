import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/meeting.dart';

/// One online meeting on an application card, drawn like the web's meeting
/// item: title, when, type and length, a status badge, the agenda, the
/// student's reschedule note, and the actions the caller passes in
/// (Join, Confirm, Ask to reschedule; or Reschedule, Cancel, Complete).
class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.meeting,
    this.actions = const [],
    this.compact = false,
  });

  final Meeting meeting;
  final List<Widget> actions;

  /// Past meetings: title, when and status only.
  final bool compact;

  static Color badgeColor(String status) => switch (status) {
        'confirmed' || 'completed' => const Color(0xFF1A7F4B),
        'reschedule_requested' => const Color(0xFFB87700),
        'cancelled' || 'missed' => const Color(0xFFC83232),
        _ => AppColors.primary,
      };

  static Color badgeBackground(String status) => switch (status) {
        'confirmed' || 'completed' => const Color(0xFFEAFAF1),
        'reschedule_requested' => const Color(0xFFFFF4E5),
        'cancelled' || 'missed' => const Color(0xFFFFF1F1),
        _ => AppColors.chipBackground,
      };

  @override
  Widget build(BuildContext context) {
    final m = meeting;
    final live = m.isJoinable && !compact;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: live ? const Color(0xFFEAFAF1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: live ? const Color(0xFFC9EFD9) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(m.isVideo ? Icons.videocam_outlined : Icons.call_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      compact ? m.whenLabel : '${m.whenLabel} · ${m.isVideo ? 'Video' : 'Audio'} · ${m.durationMinutes} min',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBackground(m.status), borderRadius: BorderRadius.circular(999)),
                child: Text(m.statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor(m.status))),
              ),
            ],
          ),
          if (!compact && (m.agenda ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.agenda!, style: const TextStyle(fontSize: 12.5, height: 1.45)),
          ],
          if (!compact && m.status == 'reschedule_requested') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Another time was requested${m.proposedLabel != null ? ' (${m.proposedLabel})' : ''}'
                '${(m.studentNote ?? '').isNotEmpty ? ': ${m.studentNote}' : '.'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A4B00), height: 1.4),
              ),
            ),
          ],
          if (!compact && actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}

/// A date and time picker in one go, for scheduling / moving a meeting.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: start.isBefore(now) ? now : start,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// "Mon, Sep 28 · 2:00 PM" for a picked date.
String formatPickedDateTime(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day} · $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}
