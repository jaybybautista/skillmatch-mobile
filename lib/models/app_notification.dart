import 'package:flutter/material.dart';

/// One row of the shared `notifications` table — the same record the web
/// bell shows.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.timeAgo,
    required this.screen,
    required this.screenParams,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String timeAgo;

  /// Platform-neutral destination from NotificationRouter, so tapping this in
  /// the app lands where tapping it on the web would.
  final String screen;
  final Map<String, dynamic> screenParams;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? false,
      timeAgo: json['time_ago'] as String? ?? '',
      screen: json['screen'] as String? ?? 'notifications',
      screenParams: (json['screen_params'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        isRead: isRead ?? this.isRead,
        timeAgo: timeAgo,
        screen: screen,
        screenParams: screenParams,
      );

  /// Icon and colour per type, matching how the web page labels them.
  IconData get icon => switch (type) {
        'application' => Icons.description_outlined,
        'assessment' => Icons.assignment_turned_in_outlined,
        'recommendation' => Icons.auto_awesome_outlined,
        'announcement' => Icons.campaign_outlined,
        'placement' => Icons.work_outline,
        'review' => Icons.star_outline,
        _ => Icons.notifications_none,
      };

  Color get accent => switch (type) {
        'application' => const Color(0xFF3D6EF5),
        'assessment' => const Color(0xFF7C3AED),
        'recommendation' => const Color(0xFF0EA5E9),
        'announcement' => const Color(0xFFB87700),
        'placement' => const Color(0xFF1A7F4B),
        'review' => const Color(0xFFF5A623),
        _ => const Color(0xFF64748B),
      };

  String get typeLabel => switch (type) {
        'application' => 'Application',
        'assessment' => 'Assessment',
        'recommendation' => 'Recommendation',
        'announcement' => 'Announcement',
        'placement' => 'Placement',
        'review' => 'Review',
        _ => 'System',
      };
}

/// The list plus the per-type counts behind the filter row.
class NotificationPage {
  NotificationPage({required this.notifications, required this.counts});

  final List<AppNotification> notifications;
  final Map<String, int> counts;

  int get unread => counts['unread'] ?? 0;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      notifications: (json['notifications'] as List? ?? [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: ((json['counts'] as Map?) ?? {}).map(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      ),
    );
  }
}
