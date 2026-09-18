import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/file_share.dart';
import '../../models/messaging/chat_message.dart';
import '../../models/messaging/chat_user.dart';
import '../../models/messaging/conversation.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../chatbot/chat_destinations.dart';
import 'people_picker_screen.dart';
import 'photo_viewer_screen.dart';
import 'widgets/chat_avatar.dart';

/// What the info screen tells the thread when it closes.
class ChatInfoResult {
  const ChatInfoResult({this.conversation, this.left = false, this.deleted = false, this.open});

  final Conversation? conversation;
  final bool left;
  final bool deleted;

  /// A different chat to open next (Message a member).
  final Conversation? open;
}

/// The web's chat info drawer, as a screen: big avatar (tap to change a
/// group photo), name and status, a row of quick actions (Profile · Mute ·
/// Pin · Archive / Photo), then the same collapsible sections - Chat info,
/// Customize chat, Chat members, Media & files, Privacy & support.
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({super.key, required this.conversation, this.messages = const []});

  final Conversation conversation;

  /// What the thread has loaded, for the Media & files section.
  final List<ChatMessage> messages;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final _service = MessagingService.instance;
  late Conversation _c = widget.conversation;
  late final TextEditingController _name = TextEditingController(text: _c.name);
  bool _busy = false;

  // Same defaults as the web: everything open except media.
  final Map<String, bool> _open = {'info': true, 'customize': true, 'members': true, 'media': false, 'privacy': true};

  int get _myId => context.read<AuthService>().currentUser?.id ?? 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<Conversation?> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      if (updated != null) setState(() => _c = updated);
      if (done != null) _notify(done);
    } on ApiException catch (e) {
      _notify(e.message);
    } catch (_) {
      _notify('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, {String action = 'Confirm'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /* ── Actions ─────────────────────────────────────────────────────── */

  void _openProfile() {
    final u = _c.user;
    final screen = u?.profileScreen;
    final go = u == null || screen == null ? null : chatDestinationFor(screen, u.profileParams);
    if (go == null) {
      _notify('This profile is not available in the app.');
      return;
    }
    go(context);
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name == _c.name) return;
    await _run(() => _service.renameGroup(_c.id, name), done: 'Group renamed.');
  }

  Future<void> _photo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;
    await _run(() => _service.setGroupPhoto(_c.id, picked.path), done: 'Group photo updated.');
  }

  Future<void> _addPeople() async {
    final result = await Navigator.of(context).push<PeoplePickerResult>(
      MaterialPageRoute(
        builder: (_) => PeoplePickerScreen(
          title: 'Add people',
          multi: true,
          confirmLabel: 'Invite',
          exclude: [for (final m in _c.members) m.id, for (final m in _c.invited) m.id],
        ),
      ),
    );
    if (result == null || result.people.isEmpty) return;
    await _run(
      () => _service.addMembers(_c.id, result.people.map((p) => p.id).toList()),
      done: 'Invitation sent.',
    );
  }

  Future<void> _memberMenu(ChatUser member, {bool pending = false}) async {
    if (member.id == _myId && !pending) return;
    final canManage = _c.isAdmin;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ChatAvatar(initial: member.initial, url: member.avatarUrl, size: 36),
              title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(pending ? 'Invited' : (member.isAdmin ? 'Admin' : 'Member')),
            ),
            const Divider(height: 1),
            if (!pending)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Message'),
                onTap: () => Navigator.pop(context, 'message'),
              ),
            if (canManage && !pending)
              ListTile(
                leading: Icon(member.isAdmin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined),
                title: Text(member.isAdmin ? 'Remove as admin' : 'Make admin'),
                onTap: () => Navigator.pop(context, 'admin'),
              ),
            if (canManage)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
                title: Text(pending ? 'Cancel invitation' : 'Remove from group', style: const TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (action == null) return;

    switch (action) {
      case 'message':
        try {
          final conversation = await _service.open(member.id);
          if (!mounted) return;
          Navigator.of(context).pop(ChatInfoResult(conversation: _c, open: conversation));
        } on ApiException catch (e) {
          _notify(e.message);
        }
      case 'admin':
        await _run(() => _service.setAdmin(_c.id, member.id, !member.isAdmin));
      case 'remove':
        final ok = await _confirm(
          pending ? 'Cancel invitation?' : 'Remove ${member.firstName}?',
          pending ? '${member.name} will no longer be able to join.' : '${member.name} will be removed from the group.',
          action: pending ? 'Cancel invite' : 'Remove',
        );
        if (!ok) return;
        await _run(() => _service.removeMember(_c.id, member.id));
    }
  }

  Future<void> _leave() async {
    final ok = await _confirm('Leave group?', 'You will stop receiving messages from ${_c.name}.', action: 'Leave');
    if (!ok) return;
    try {
      await _service.removeMember(_c.id, _myId);
      if (mounted) Navigator.of(context).pop(const ChatInfoResult(left: true));
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      'Delete chat?',
      'This hides the conversation for you only. A new message will bring it back with only the new messages.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await _service.deleteForMe(_c.id);
      if (mounted) Navigator.of(context).pop(const ChatInfoResult(deleted: true));
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _saveFile(ChatMessage m) async {
    final att = m.attachment;
    if (att == null) return;
    _notify('Preparing ${att.name}…');
    try {
      final bytes = await _service.attachmentBytes(m.id);
      await shareFileBytes(bytes, att.name);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  /* ── Build ───────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final other = c.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(ChatInfoResult(conversation: _c));
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(c.isGroup ? 'Group info' : 'Chat info', style: AppFonts.title(color: Colors.white, fontSize: 18)),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _hero(c, other),
            _section('info', 'Chat info', _infoBody(c, other)),
            if (c.isGroup) _section('customize', 'Customize chat', _customizeBody(c)),
            if (c.isGroup) _section('members', 'Chat members', _membersBody(c)),
            _section('media', 'Media & files', _mediaBody()),
            _section('privacy', 'Privacy & support', _privacyBody(c)),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Conversation c, ChatUser? other) {
    final avatar = ChatAvatar(
      initial: c.initial,
      url: c.displayAvatar,
      size: 96,
      online: !c.isGroup && (other?.online ?? false),
      square: c.isGroup || other?.role == 'company',
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Column(
        children: [
          if (c.isGroup)
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(onTap: _photo, child: avatar),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GestureDetector(
                    onTap: _photo,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            avatar,
          const SizedBox(height: 12),
          Text(c.name, textAlign: TextAlign.center, style: AppFonts.title(fontSize: 20)),
          const SizedBox(height: 3),
          Text(
            c.isGroup ? '${c.members.length} members' : (other?.activityLabel ?? other?.roleLabel ?? ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!c.isGroup && other?.profileScreen != null)
                _QuickAction(icon: Icons.person_outline, label: 'Profile', onTap: _openProfile),
              _QuickAction(
                icon: c.muted ? Icons.notifications_off : Icons.notifications_none,
                label: c.muted ? 'Unmute' : 'Mute',
                onTap: () => _run(() => _service.setPreference(c.id, 'mute')),
              ),
              _QuickAction(
                icon: c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: c.pinned ? 'Unpin' : 'Pin',
                onTap: () => _run(() => _service.setPreference(c.id, 'pin')),
              ),
              if (c.isGroup)
                _QuickAction(icon: Icons.photo_camera_outlined, label: 'Photo', onTap: _photo)
              else
                _QuickAction(
                  icon: c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  label: c.archived ? 'Unarchive' : 'Archive',
                  onTap: () => _run(() => _service.setPreference(c.id, 'archive')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A collapsible section, like the web's `<details>` blocks.
  Widget _section(String key, String title, Widget body) {
    final open = _open[key] ?? true;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open[key] = !open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: body),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, VoidCallback onTap, {bool danger = false, String? subtitle}) {
    final color = danger ? AppColors.danger : AppColors.textDark;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 14)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _infoBody(Conversation c, ChatUser? other) {
    if (c.isGroup) {
      final creator = c.members.where((m) => m.id == c.createdBy).firstOrNull;
      return Column(
        children: [
          _kv('Members', '${c.members.length}'),
          if (creator != null) _kv('Created by', creator.name),
          _kv('Your role', c.isAdmin ? 'Admin' : 'Member'),
        ],
      );
    }
    return Column(
      children: [
        _kv('Role', other?.roleLabel ?? ''),
        if (other?.subtitle != null) _kv('About', other!.subtitle!),
        _kv('Status', other?.activityLabel ?? 'Offline'),
      ],
    );
  }

  Widget _customizeBody(Conversation c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Group name',
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : _saveName, child: const Text('Save')),
            ],
          ),
        ),
        _row(Icons.photo_camera_outlined, 'Change group photo', _photo),
      ],
    );
  }

  Widget _membersBody(Conversation c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in c.members)
          ListTile(
            dense: true,
            leading: ChatAvatar(initial: m.initial, url: m.avatarUrl, size: 36, online: m.online),
            title: Row(
              children: [
                Flexible(child: Text(m.id == _myId ? '${m.name} (you)' : m.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (m.isAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Admin', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
              ],
            ),
            trailing: m.id == _myId ? null : const Icon(Icons.more_horiz, color: AppColors.textMuted),
            onTap: () => _memberMenu(m),
          ),
        if (c.invited.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text('Invited', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          for (final m in c.invited)
            ListTile(
              dense: true,
              leading: ChatAvatar(initial: m.initial, url: m.avatarUrl, size: 36),
              title: Text('${m.name} (invited)', style: const TextStyle(color: AppColors.textMuted)),
              trailing: c.isAdmin ? const Icon(Icons.close, size: 18, color: AppColors.textMuted) : null,
              onTap: c.isAdmin ? () => _memberMenu(m, pending: true) : null,
            ),
        ],
        _row(Icons.person_add_alt_outlined, 'Add people', _addPeople),
      ],
    );
  }

  Widget _mediaBody() {
    final images = <ChatMessage>[];
    final files = <ChatMessage>[];
    for (final m in widget.messages) {
      final a = m.attachment;
      if (a == null || m.unsent) continue;
      (a.isImage ? images : files).add(m);
    }

    if (images.isEmpty && files.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Text('No photos or files in this chat yet.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      );
    }

    final headers = _service.imageHeaders;
    final recentImages = images.reversed.take(9).toList();
    final recentFiles = files.reversed.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recentImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final m in recentImages)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(url: m.attachment!.url, headers: headers, title: m.attachment!.name),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        m.attachment!.url,
                        headers: headers,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (final m in recentFiles)
          ListTile(
            dense: true,
            leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.textDark),
            title: Text(m.attachment!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            subtitle: Text(m.attachment!.readableSize, style: const TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.download_outlined, size: 20, color: AppColors.textMuted),
            onTap: () => _saveFile(m),
          ),
      ],
    );
  }

  Widget _privacyBody(Conversation c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          c.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          c.muted ? 'Unmute notifications' : 'Mute notifications',
          () => _run(() => _service.setPreference(c.id, 'mute')),
        ),
        _row(
          c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          c.archived ? 'Unarchive chat' : 'Archive chat',
          () => _run(() => _service.setPreference(c.id, 'archive')),
        ),
        _row(Icons.delete_outline, 'Delete chat', _delete, danger: true, subtitle: 'For you only'),
        if (c.isGroup) _row(Icons.logout, 'Leave group', _leave, danger: true),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
