import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/messaging/conversation.dart';
import '../../services/messaging_service.dart';
import 'widgets/chat_avatar.dart';

/// Search-and-pick people, the way the web's "new group" composer and
/// "add people" panel do. In [multi] mode the picked people are ticked and
/// returned together; otherwise tapping one returns it at once.
///
/// Returns a [PeoplePickerResult], or null when dismissed.
class PeoplePickerScreen extends StatefulWidget {
  const PeoplePickerScreen({
    super.key,
    required this.title,
    this.multi = false,
    this.exclude = const [],
    this.confirmLabel = 'Done',
    this.groupName = false,
  });

  final String title;
  final bool multi;

  /// User ids not offered (already in the group, etc).
  final List<int> exclude;
  final String confirmLabel;

  /// Shows a group-name field above the list (new group).
  final bool groupName;

  @override
  State<PeoplePickerScreen> createState() => _PeoplePickerScreenState();
}

class _PeoplePickerScreenState extends State<PeoplePickerScreen> {
  final _service = MessagingService.instance;
  final _search = TextEditingController();
  final _name = TextEditingController();

  List<ChatPerson> _results = const [];
  final Map<int, ChatPerson> _picked = {};
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final people = await _service.people(_search.text.trim(), exclude: widget.exclude);
      if (!mounted) return;
      setState(() {
        _results = people;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load people. Please check your connection.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _tap(ChatPerson person) {
    if (!widget.multi) {
      Navigator.of(context).pop(PeoplePickerResult(people: [person]));
      return;
    }
    setState(() {
      if (_picked.containsKey(person.id)) {
        _picked.remove(person.id);
      } else {
        _picked[person.id] = person;
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop(PeoplePickerResult(
      people: _picked.values.toList(),
      groupName: _name.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: AppFonts.title(color: Colors.white, fontSize: 18)),
        actions: [
          if (widget.multi)
            TextButton(
              onPressed: _picked.isEmpty ? null : _confirm,
              child: Text(
                '${widget.confirmLabel}${_picked.isEmpty ? '' : ' (${_picked.length})'}',
                style: TextStyle(color: _picked.isEmpty ? Colors.white54 : Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.groupName)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Group name (optional)',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              autofocus: !widget.groupName,
              decoration: InputDecoration(
                hintText: 'Search students, companies, coordinators',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          if (widget.multi && _picked.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final p in _picked.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(p.firstNameOr()),
                        avatar: ChatAvatar(initial: p.initial, url: p.avatarUrl, size: 22),
                        onDeleted: () => setState(() => _picked.remove(p.id)),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No one matches that search.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, color: AppColors.border),
      itemBuilder: (context, i) {
        final p = _results[i];
        final picked = _picked.containsKey(p.id);
        return ListTile(
          tileColor: Colors.white,
          leading: ChatAvatar(initial: p.initial, url: p.avatarUrl, online: p.online, square: p.role == 'company'),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [if (p.roleLabel != null) p.roleLabel!, if (p.subtitle != null) p.subtitle!].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          trailing: widget.multi
              ? Icon(picked ? Icons.check_circle : Icons.circle_outlined,
                  color: picked ? AppColors.primary : AppColors.border)
              : null,
          onTap: () => _tap(p),
        );
      },
    );
  }
}

/// What [PeoplePickerScreen] hands back in multi mode.
class PeoplePickerResult {
  const PeoplePickerResult({required this.people, this.groupName = ''});

  final List<ChatPerson> people;
  final String groupName;
}

extension on ChatPerson {
  String firstNameOr() => name.split(' ').first;
}
