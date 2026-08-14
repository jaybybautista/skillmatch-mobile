import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_notification.dart';

/// Talks to Api\NotificationController, which reads and writes the same
/// `notifications` rows the web bell uses.
///
/// [unreadCount] is a [ValueListenable] refreshed by a shared 15-second poll,
/// so the sidebar badge and any screen showing a count all move together —
/// including when the change happened on the website.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Test seam: lets a test drive the badge without a server.
  @visibleForTesting
  NotificationService.forTesting();

  final ApiClient _client = ApiClient.instance;

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Timer? _poll;
  int _listeners = 0;

  static const pollInterval = Duration(seconds: 15);

  /// Starts the shared poll. Every widget showing the badge calls this and
  /// [stopPolling] on dispose; the timer runs while at least one is alive.
  void startPolling() {
    _listeners++;
    if (_poll != null) return;

    refreshUnreadCount();
    _poll = Timer.periodic(pollInterval, (_) => refreshUnreadCount());
  }

  void stopPolling() {
    _listeners = (_listeners - 1).clamp(0, 1 << 30);
    if (_listeners == 0) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final response = await _client.get('/notifications/unread-count', authenticated: true);
      unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // A failed poll is not worth surfacing — the next tick tries again.
    }
  }

  Future<NotificationPage> fetch({String type = 'all'}) async {
    final response = await _client.get(
      '/notifications?type=${Uri.encodeQueryComponent(type)}',
      authenticated: true,
    );

    final page = NotificationPage.fromJson(response);
    unreadCount.value = page.unread;
    return page;
  }

  /// Marks read and returns the notification with its destination.
  Future<AppNotification> tap(int id) async {
    final response = await _client.post('/notifications/$id/tap', {}, authenticated: true);
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
    return AppNotification.fromJson(response['notification'] as Map<String, dynamic>);
  }

  Future<AppNotification> toggleRead(int id) async {
    final response = await _client.post('/notifications/$id/toggle-read', {}, authenticated: true);
    unreadCount.value = (response['unread_count'] as num?)?.toInt() ?? unreadCount.value;
    return AppNotification.fromJson(response['notification'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _client.delete('/notifications/$id', authenticated: true);
    await refreshUnreadCount();
  }

  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all', {}, authenticated: true);
    unreadCount.value = 0;
  }

  @override
  void dispose() {
    _poll?.cancel();
    unreadCount.dispose();
    super.dispose();
  }
}
