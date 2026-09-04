import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/assessment.dart';
import '../services/company_assessment_service.dart';
import 'code_viewer.dart';

/// Ang pamimili ng wika sa isang code tracing na tanong.
///
/// Kambal ito ng dropdown sa web builder. Isang hanay ng mapipilian, may
/// hanapan sa taas, hati sa wika at framework, at may tanda kada isa - para
/// alam agad ng estudyante kung anong wika yung binabasa niya.
///
/// Sa server nanggagaling ang listahan, hindi nakasulat dito. Kaya pag may
/// naidagdag na wika sa ProgrammingLanguages, lumalabas agad ito sa web at
/// sa app nang walang bagong build.
Future<LanguageBadge?> showLanguagePicker(
  BuildContext context, {
  String? currentSlug,
  CompanyAssessmentService? service,
}) {
  return showModalBottomSheet<LanguageBadge>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LanguagePickerSheet(
      currentSlug: currentSlug,
      service: service ?? CompanyAssessmentService(),
    ),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.currentSlug,
    required this.service,
  });

  final String? currentSlug;
  final CompanyAssessmentService service;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _search = TextEditingController();

  List<LanguageBadge> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final languages = await widget.service.languages();
      if (!mounted) return;
      setState(() {
        _all = languages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the language list. Check your connection.';
        _loading = false;
      });
    }
  }

  /// Hinahanap sa pangalan at sa slug. Kaya lumalabas pa rin ang C++ kahit
  /// "cpp" ang tinipa, at ang C# kahit "csharp".
  List<LanguageBadge> get _matches {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _all;

    return _all
        .where(
          (l) =>
              l.label.toLowerCase().contains(term) ||
              l.slug.toLowerCase().contains(term),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final languages = matches.where((l) => l.kind == 'language').toList();
    final frameworks = matches.where((l) => l.kind != 'language').toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _search,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search a language or framework',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(child: _body(languages, frameworks)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<LanguageBadge> languages, List<LanguageBadge> frameworks) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    if (languages.isEmpty && frameworks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Text(
          'No language matches that.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      shrinkWrap: true,
      children: [
        if (languages.isNotEmpty) const _GroupHeading('Languages'),
        for (final badge in languages) _row(badge),
        if (frameworks.isNotEmpty) const _GroupHeading('Frameworks'),
        for (final badge in frameworks) _row(badge),
      ],
    );
  }

  Widget _row(LanguageBadge badge) {
    final selected = badge.slug == widget.currentSlug;

    return InkWell(
      onTap: () => Navigator.of(context).pop(badge),
      child: Container(
        color: selected ? AppColors.chipBackground : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            LanguageTile(badge: badge, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                badge.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (selected)
              const Text(
                'Selected',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
