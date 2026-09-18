import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/messaging/conversation.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../core/app_navigation.dart';
import '../../core/company_navigation.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import 'chat_info_screen.dart';
import 'chat_thread_screen.dart';
import 'people_picker_screen.dart';
import 'widgets/chat_avatar.dart';

/// The Messages page: chats on top, Archived behind a tab, a "new message"
/// search and a "new group" composer, and the same per-chat menu the web
/// list has (mark unread, pin, mute, archive, delete, leave group).
///
/// Re-reads every 5 seconds so a message sent from the website shows up
/// without a manual refresh.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.openUserId});

  /// Opens (or starts) the direct chat with this user as soon as the screen
  /// appears — the "Message" button on a profile.
  final int? openUserId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final _service = MessagingService.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<Conversation> _chats = const [];
  List<Conversation> _archived = const [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _service.startPolling();
    _service.listRevision.addListener(_onRevision);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load(silent: true);
    });
    _load();
    _poll = Timer.periodic(
      MessagingService.pollInterval,
      (_) => _load(silent: true),
    );

    final open = widget.openUserId;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openWith(open));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _service.listRevision.removeListener(_onRevision);
    _tabs.dispose();
    super.dispose();
  }

  void _onRevision() => _load(silent: true);

  bool get _showingArchived => _tabs.index == 1;

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final list = await _service.conversations(archived: _showingArchived);
      if (!mounted) return;
      setState(() {
        if (_showingArchived) {
          _archived = list;
        } else {
          _chats = list;
        }
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _error = 'Could not load your chats. Please check your connection.';
        }
        _loading = false;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openWith(int userId) async {
    try {
      final conversation = await _service.open(userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(conversation: conversation),
        ),
      );
      _load(silent: true);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _newMessage() async {
    final result = await Navigator.of(context).push<PeoplePickerResult>(
      MaterialPageRoute(
        builder: (_) => const PeoplePickerScreen(title: 'New message'),
      ),
    );
    if (result == null || result.people.isEmpty) return;
    await _openWith(result.people.first.id);
  }

  Future<void> _newGroup() async {
    final result = await Navigator.of(context).push<PeoplePickerResult>(
      MaterialPageRoute(
        builder: (_) => const PeoplePickerScreen(
          title: 'New group',
          multi: true,
          groupName: true,
          confirmLabel: 'Create',
        ),
      ),
    );
    if (result == null || result.people.isEmpty) return;

    try {
      final conversation = await _service.createGroup(
        result.groupName,
        result.people.map((p) => p.id).toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(conversation: conversation),
        ),
      );
      _load(silent: true);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _openThread(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(conversation: conversation),
      ),
    );
    _load(silent: true);
  }

  Future<void> _menu(Conversation c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ChatAvatar(
                initial: c.initial,
                url: c.displayAvatar,
                size: 36,
                square: c.isGroup,
              ),
              title: Text(
                c.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            if (!c.isInvited)
              _sheetItem(
                context,
                Icons.info_outline,
                c.isGroup ? 'Group info' : 'Chat info',
                'info',
              ),
            _sheetItem(
              context,
              Icons.mark_chat_unread_outlined,
              c.showsUnread ? 'Mark as read' : 'Mark as unread',
              'unread',
            ),
            _sheetItem(
              context,
              c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              c.pinned ? 'Unpin' : 'Pin to top',
              'pin',
            ),
            _sheetItem(
              context,
              c.muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              c.muted ? 'Unmute notifications' : 'Mute notifications',
              'mute',
            ),
            _sheetItem(
              context,
              c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              c.archived ? 'Unarchive chat' : 'Archive chat',
              'archive',
            ),
            if (c.isGroup && !c.isInvited)
              _sheetItem(
                context,
                Icons.logout,
                'Leave group',
                'leave',
                danger: true,
              ),
            _sheetItem(
              context,
              Icons.delete_outline,
              'Delete chat',
              'delete',
              danger: true,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final me = context.read<AuthService>().currentUser?.id;

    try {
      switch (action) {
        case 'info':
          final result = await Navigator.of(context).push<ChatInfoResult>(
            MaterialPageRoute(builder: (_) => ChatInfoScreen(conversation: c)),
          );
          if (result?.open != null && mounted) await _openThread(result!.open!);
        case 'unread':
          // "Mark as read" = the same as opening it; "Mark as unread" sets
          // the flag that reading clears.
          if (c.showsUnread) {
            await _service.markRead(c.id);
          } else {
            await _service.setPreference(c.id, 'unread');
          }
        case 'pin':
        case 'mute':
        case 'archive':
          await _service.setPreference(c.id, action);
        case 'leave':
          final ok = await _confirm(
            'Leave group?',
            'You will stop receiving messages from ${c.name}.',
          );
          if (!ok) return;
          if (me != null) await _service.removeMember(c.id, me);
        case 'delete':
          final ok = await _confirm(
            'Delete chat?',
            'This hides the conversation for you only. A new message will bring it back with only the new messages.',
          );
          if (!ok) return;
          await _service.deleteForMe(c.id);
      }
      _load(silent: true);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Widget _sheetItem(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool danger = false,
  }) {
    final color = danger ? AppColors.danger : AppColors.textDark;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isCompany =
        context.read<AuthService>().currentUser?.role == 'company';

    final actions = [
      IconButton(
        tooltip: 'New group',
        icon: const Icon(Icons.group_add_outlined, color: Colors.white),
        onPressed: _newGroup,
      ),
      IconButton(
        tooltip: 'New message',
        icon: const Icon(Icons.edit_square, color: Colors.white),
        onPressed: _newMessage,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      drawer: isCompany
          ? const CompanySidebar(current: CompanySidebarItem.messages)
          : const AppSidebar(current: SidebarItem.messages),
      // Each side keeps its own top-level header: the company gradient bar,
      // or the student navy header with the content sheet curving under it.
      body: isCompany ? _companyLayout(actions) : _studentLayout(actions),
      // Messages is the fifth tab on both sides, so the bar stays here like
      // on every other top-level screen.
      bottomNavigationBar: isCompany
          ? CompanyBottomNav(
              currentIndex: 4,
              onSelect: (i) => handleCompanyNavTap(context, i),
            )
          : AppBottomNav(
              currentIndex: 4,
              onSelect: (i) => handleAppNavTap(context, i),
            ),
    );
  }

  Widget _studentLayout(List<Widget> actions) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
            child: Row(
              children: [
                // Builder so openDrawer() sees the Scaffold above it.
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: Scaffold.of(context).openDrawer,
                    tooltip: 'Menu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Messages',
                    style: AppFonts.title(color: Colors.white, fontSize: 24),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
        _tabBar(onNavy: true),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: _tabViews(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _companyLayout(List<Widget> actions) {
    return Column(
      children: [
        CompanyScreenHeader(
          title: 'Messages',
          showMenuButton: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: Column(
              children: [
                ColoredBox(color: Colors.white, child: _tabBar(onNavy: false)),
                Expanded(child: _tabViews()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabBar({required bool onNavy}) {
    return TabBar(
      controller: _tabs,
      indicatorColor: onNavy ? Colors.white : AppColors.primary,
      labelColor: onNavy ? Colors.white : AppColors.primary,
      unselectedLabelColor: onNavy ? Colors.white70 : AppColors.textMuted,
      dividerColor: onNavy ? Colors.transparent : AppColors.border,
      tabs: const [
        Tab(text: 'Chats'),
        Tab(text: 'Archived'),
      ],
    );
  }

  Widget _tabViews() {
    return TabBarView(
      controller: _tabs,
      children: [
        _list(_chats, 'No chats yet. Tap the pencil to message someone.'),
        _list(_archived, 'No archived chats.'),
      ],
    );
  }

  Widget _list(List<Conversation> items, String emptyText) {
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final me = context.read<AuthService>().currentUser?.id;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 90),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 56,
                  color: AppColors.border,
                ),
                const SizedBox(height: 12),
                Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 76, color: AppColors.border),
              itemBuilder: (context, i) => _ConversationRow(
                conversation: items[i],
                myId: me,
                onTap: () => _openThread(items[i]),
                onLongPress: () => _menu(items[i]),
                onMenu: () => _menu(items[i]),
              ),
            ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.myId,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final Conversation conversation;
  final int? myId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// The "⋯" button at the end of the row, like the web list.
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.showsUnread;

    String preview;
    if (c.isInvited) {
      preview = 'Invited by ${c.invitedBy ?? 'a member'} · tap to join';
    } else if (last == null) {
      preview = 'Say hello';
    } else if (last.isSystem || last.isCall) {
      preview = last.preview;
    } else if (last.senderId == myId) {
      preview = 'You: ${last.preview}';
    } else if (c.isGroup && last.senderName != null) {
      preview = '${last.senderName!.split(' ').first}: ${last.preview}';
    } else {
      preview = last.preview;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ChatAvatar(
              initial: c.initial,
              url: c.displayAvatar,
              size: 48,
              online: !c.isGroup && (c.user?.online ?? false),
              square: c.isGroup || c.user?.role == 'company',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c.pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (c.muted)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        chatListTime(last?.createdAt ?? c.updatedAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: unread
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (c.activeCall != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.phone_in_talk,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      if (last?.mentionsMe == true && unread)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '@',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB87700),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread
                                ? AppColors.textDark
                                : AppColors.textMuted,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontStyle: c.isInvited
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (c.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (c.markedUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Same "⋯" menu as the web chat rows: mark unread, pin, mute,
            // archive, delete, info, leave.
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                splashRadius: 18,
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
                onPressed: onMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
