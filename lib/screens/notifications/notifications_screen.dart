import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../chatbot/chat_destinations.dart';

/// The notifications list, mirroring the web page: the same rows, the same
/// type filters, and the same actions.
///
/// It re-reads every 15 seconds, so a notification raised by the website — a
/// status change, a newly assigned assessment, a reply to a review — turns up
/// here without a manual refresh, and marking one read here clears it from the
/// web bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService.instance;

  /// Filter key to the label shown on its chip.
  static const _filters = <String, String>{
    'all': 'All',
    'application': 'Applications',
    'assessment': 'Assessments',
    'review': 'Reviews',
    'placement': 'Placement',
    'announcement': 'Announcements',
    'recommendation': 'Recommendations',
    'system': 'System',
  };

  List<AppNotification> _items = const [];
  Map<String, int> _counts = const {};
  String _type = 'all';
  String? _error;
  bool _isLoading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(NotificationService.pollInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final page = await _service.fetch(type: _type);
      if (!mounted) return;
      setState(() {
        _items = page.notifications;
        _counts = page.counts;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = 'Could not load notifications. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(AppNotification notification) async {
    try {
      // Marks it read server-side and hands back where to go, so the web bell
      // and this list agree on what has been seen.
      final opened = await _service.tap(notification.id);
      if (!mounted) return;

      setState(() {
        _items = [
          for (final item in _items) item.id == opened.id ? opened : item,
        ];
      });

      final destination = chatDestinationFor(opened.screen, opened.screenParams);

      if (destination == null) {
        final reason = unavailableReasonFor(opened.screen);
        if (reason != null) _notify(reason);
        return;
      }

      // Already on this screen — nothing to navigate to.
      if (opened.screen == 'notifications') return;

      destination(context);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _toggleRead(AppNotification notification) async {
    try {
      final updated = await _service.toggleRead(notification.id);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in _items) item.id == updated.id ? updated : item,
        ];
      });
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _delete(AppNotification notification) async {
    // Removed locally first so the swipe completes without a gap, then
    // reconciled against the server.
    setState(() => _items = _items.where((n) => n.id != notification.id).toList());

    try {
      await _service.delete(notification.id);
      await _load(silent: true);
    } on ApiException catch (e) {
      _notify(e.message);
      _load(silent: true);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() => _items = [for (final item in _items) item.copyWith(isRead: true)]);
      _load(silent: true);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _counts['unread'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterRow(
            filters: _filters,
            counts: _counts,
            selected: _type,
            onSelected: (type) {
              setState(() => _type = type);
              _load();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Icon(Icons.notifications_none, size: 56, color: AppColors.border),
            SizedBox(height: 12),
            Text(
              'Nothing here yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Updates about your applications, assessments\nand reviews will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final notification = _items[index];

          return Dismissible(
            key: ValueKey(notification.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => _delete(notification),
            child: _NotificationTile(
              notification: notification,
              onTap: () => _open(notification),
              onToggleRead: () => _toggleRead(notification),
            ),
          );
        },
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, String> filters;
  final Map<String, int> counts;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final entry in filters.entries)
            // A type with nothing in it is not worth a chip, but the active
            // one always stays so the row can't shift under a tap.
            if ((counts[entry.key] ?? 0) > 0 || entry.key == 'all' || entry.key == selected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: entry.key == selected,
                  onSelected: (_) => onSelected(entry.key),
                  label: Text(
                    counts[entry.key] != null && counts[entry.key]! > 0
                        ? '${entry.value} (${counts[entry.key]})'
                        : entry.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: entry.key == selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  showCheckmark: false,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onToggleRead,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.chipBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnread ? AppColors.primaryLight : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: notification.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(notification.icon, size: 19, color: notification.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            notification.typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: notification.accent,
                            ),
                          ),
                          const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            notification.timeAgo,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleRead,
                  visualDensity: VisualDensity.compact,
                  tooltip: isUnread ? 'Mark as read' : 'Mark as unread',
                  icon: Icon(
                    isUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
