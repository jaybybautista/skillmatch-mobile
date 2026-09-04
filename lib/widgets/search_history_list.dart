import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/search_history_entry.dart';
import '../services/search_history_service.dart';

/// The list of past searches shown above an empty search box. It is the phone's
/// half of the dropdown the website drops under its search inputs.
///
/// A typed word is a plain row with a clock. A result the person opened is a
/// tile with its picture, its name, and what it is. Both carry an "x" for
/// dropping just that one, and the header clears the whole list.
///
/// Loading and deleting are handled here rather than by each screen, so a new
/// search box only has to say which [context] it belongs to.
class SearchHistoryList extends StatefulWidget {
  const SearchHistoryList({
    super.key,
    required this.context,
    required this.onTermPicked,
    this.onEntityPicked,
    this.service,
  });

  /// Which search box this list belongs to. See [SearchContext].
  final String context;

  /// A remembered word was tapped, so the screen puts it back in the box and
  /// searches for it again.
  final ValueChanged<String> onTermPicked;

  /// A remembered result was tapped. Screens that can open that kind of
  /// record handle it; leaving this out turns those tiles into plain rows
  /// that search for the name instead.
  final ValueChanged<SearchHistoryEntry>? onEntityPicked;

  final SearchHistoryService? service;

  @override
  State<SearchHistoryList> createState() => SearchHistoryListState();
}

class SearchHistoryListState extends State<SearchHistoryList> {
  late final SearchHistoryService _service =
      widget.service ?? SearchHistoryService();

  List<SearchHistoryEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(SearchHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Switching tabs swaps which list this is, and the entries on screen
    // belong to the old one until they are fetched again.
    if (oldWidget.context != widget.context) reload();
  }

  /// Called by the screen after it records a new search, so the list is
  /// already up to date the next time the box is emptied.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final entries = await _service.recent(widget.context);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      // Dagdag lang ito sa paghahanap. Pag hindi umabot yung listahan,
      // walang ipinapakita - hindi naman ito dapat maging harang.
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _loading = false;
      });
    }
  }

  Future<void> _forget(SearchHistoryEntry entry) async {
    setState(() {
      _entries = _entries.where((e) => e.id != entry.id).toList();
    });

    try {
      await _service.forget(entry.id);
    } catch (_) {
      // Naalis na sa nakikita. Pag hindi umabot sa server, babalik lang ito
      // sa susunod na pagbukas - mas mabuti yun kaysa sa nakabitin na pindot.
    }
  }

  Future<void> _clearAll() async {
    setState(() => _entries = const []);

    try {
      await _service.clear(widget.context);
    } catch (_) {
      // Ganoon din dito.
    }
  }

  @override
  Widget build(BuildContext buildContext) {
    if (_loading || _entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        for (final entry in _entries)
          _HistoryRow(
            entry: entry,
            onTap: () {
              if (entry.isEntity && widget.onEntityPicked != null) {
                widget.onEntityPicked!(entry);
              } else {
                widget.onTermPicked(entry.term ?? entry.label);
              }
            },
            onRemove: () => _forget(entry),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
        child: Row(
          children: [
            _Thumbnail(entry: entry),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                      fontWeight:
                          entry.isEntity ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (entry.isEntity && (entry.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove from history',
            ),
          ],
        ),
      ),
    );
  }
}

/// Larawan pag resulta, orasan pag tinipa lang. Pag may larawan dapat pero
/// hindi ito umabot, yung unang dalawang letra ang pumapalit - kaya kumpleto
/// pa rin yung hanay kahit patay ang koneksyon.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entry});

  final SearchHistoryEntry entry;

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    if (!entry.isEntity) {
      return Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: AppColors.chipBackground,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.history,
          size: 17,
          color: AppColors.textMuted,
        ),
      );
    }

    final image = entry.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: _size,
        height: _size,
        child: image != null && image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(entry: entry),
              )
            : _Initials(entry: entry),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.entry});

  final SearchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final initials = (entry.initials ?? '').isNotEmpty
        ? entry.initials!
        : (entry.label.isNotEmpty
              ? entry.label.substring(0, 1).toUpperCase()
              : '?');

    return Container(
      color: AppColors.chipBackground,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
