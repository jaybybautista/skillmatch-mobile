import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/match_details.dart';
import '../services/internship_service.dart';

/// Opens the "Why this match" sheet for a posting: the web's match details
/// panel (tier, skill coverage, evaluation matrix, Explain with AI, skills
/// you have / are missing, preferred applicants) as a bottom sheet, so the
/// listing card itself stays short.
Future<void> showMatchDetailsSheet(BuildContext context, int internshipId, {InternshipService? service}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, controller) => MatchDetailsSheet(
        internshipId: internshipId,
        scrollController: controller,
        service: service,
      ),
    ),
  );
}

class MatchDetailsSheet extends StatefulWidget {
  const MatchDetailsSheet({
    super.key,
    required this.internshipId,
    this.scrollController,
    this.service,
    this.inline = false,
  });

  final int internshipId;
  final ScrollController? scrollController;
  final InternshipService? service;

  /// Rendered inside another page (the internship detail screen): no
  /// sheet handle or header, and the content lays out in the parent's
  /// scroll view instead of its own list.
  final bool inline;

  @override
  State<MatchDetailsSheet> createState() => _MatchDetailsSheetState();
}

class _MatchDetailsSheetState extends State<MatchDetailsSheet> {
  late final InternshipService _service = widget.service ?? InternshipService();

  MatchDetails? _details;
  String? _error;
  bool _explaining = false;
  String? _explainError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _details = null;
    });
    try {
      final details = await _service.fetchMatchDetails(widget.internshipId);
      if (mounted) setState(() => _details = details);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the match details. Please check your connection.');
    }
  }

  Future<void> _explain() async {
    setState(() {
      _explaining = true;
      _explainError = null;
    });
    try {
      final (text, at) = await _service.explainMatch(widget.internshipId);
      if (!mounted) return;
      setState(() => _details = _details?.withExplanation(text, at));
    } on ApiException catch (e) {
      if (mounted) setState(() => _explainError = e.message);
    } catch (_) {
      if (mounted) setState(() => _explainError = 'The AI explanation is not available right now.');
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  List<Widget> _children(MatchDetails d) => [
        _tierAndCoverage(d),
        const SizedBox(height: 12),
        Text(d.summary, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        if (d.rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _matrix(d),
          const SizedBox(height: 12),
          _explainBlock(d),
        ],
        const SizedBox(height: 16),
        _skillsColumns(d),
        if (d.extra.isNotEmpty) ...[
          const SizedBox(height: 14),
          _extraSkills(d),
        ],
        const SizedBox(height: 16),
        _factors(d),
        if (d.scoreNote != null) ...[
          const SizedBox(height: 14),
          Text(d.scoreNote!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5)),
        ],
        if (d.aiNote != null) ...[
          const SizedBox(height: 6),
          Text(d.aiNote!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5)),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final d = _details;

    if (widget.inline) {
      return d == null
          ? SizedBox(height: 120, child: _stateView())
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _children(d));
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why this match', style: AppFonts.title(fontSize: 18)),
                    if (d != null)
                      Text(
                        [d.title, if (d.companyName != null) d.companyName!].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: d == null
              ? _stateView()
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: _children(d),
                ),
        ),
      ],
    );
  }

  Widget _stateView() {
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
    return const Center(child: CircularProgressIndicator());
  }

  /* ── Pieces ─────────────────────────────────────────────────────── */

  Color _tierColor(String tier) => switch (tier) {
        'strong' => const Color(0xFF1A7F4B),
        'good' => AppColors.primary,
        'partial' => const Color(0xFFB87700),
        'low' => const Color(0xFFE03E3E),
        _ => AppColors.textMuted,
      };

  Color _tierBackground(String tier) => switch (tier) {
        'strong' => const Color(0xFFEAFAF1),
        'good' => AppColors.chipBackground,
        'partial' => const Color(0xFFFFF4E5),
        'low' => const Color(0xFFFFF1F1),
        _ => AppColors.background,
      };

  Widget _tierAndCoverage(MatchDetails d) {
    final color = _tierColor(d.tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _tierBackground(d.tier), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(d.tierLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              if (d.score != null) Text(' · ${d.score!.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Skill coverage', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text('${d.coverageHave} of ${d.coverageTotal} skills (${d.coveragePercent}%)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: d.coveragePercent / 100,
            minHeight: 8,
            backgroundColor: AppColors.background,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _kindChip(MatchDetails d, MatrixRow row) {
    final isFull = row.kind == 'exact' || row.kind == 'equivalent';
    final color = isFull ? const Color(0xFF1A7F4B) : (row.kind == 'related' ? const Color(0xFFB87700) : const Color(0xFFC83232));
    final bg = isFull ? const Color(0xFFEAFAF1) : (row.kind == 'related' ? const Color(0xFFFFF4E5) : const Color(0xFFFFF1F1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '${d.kindLabels[row.kind] ?? row.kind}${row.fromAi ? ' (AI)' : ''}',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _matrix(MatchDetails d) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evaluation matrix', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text('One row per required skill. The score is the average of the credits.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          for (final row in d.rows) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              row.required,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: row.kind == 'missing' ? const Color(0xFFC83232) : AppColors.textDark,
                              ),
                            ),
                            _kindChip(d, row),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Your closest skill: ${row.yours ?? 'None'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                        ),
                        Text(
                          (row.reason ?? '').isNotEmpty ? row.reason! : 'No skill in your profile is close to this.',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Text('${row.credit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const Text('credit', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1, color: AppColors.border),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Average of ${d.rows.length} ${d.rows.length == 1 ? 'credit' : 'credits'}: ${d.creditSum} / ${d.rows.length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                Text('${d.matrixScore}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
            child: Text(
              'Exact match or Equivalent: ${d.creditFull} credit (you have it, or the same skill under a different name). '
              'Related: ${d.creditRelated} credit (a close skill partly covers it; "(AI)" means the SkillMatch AI model found the link by meaning). '
              'Missing: 0 credit.',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explainBlock(MatchDetails d) {
    if (d.explanation != null && d.explanation!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
          borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.explanation!, style: const TextStyle(fontSize: 13, height: 1.55)),
            const SizedBox(height: 6),
            Text(
              'Written by AI from the table above${d.explainedAt != null ? ', ${d.explainedAt}' : ''}. It only restates the rows; the score itself is not decided by the AI.',
              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _explaining ? null : _explain,
          icon: _explaining
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.lightbulb_outline, size: 16),
          label: Text(_explaining ? 'Thinking…' : 'Explain with AI'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        if (_explainError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_explainError!, style: const TextStyle(fontSize: 12, color: Color(0xFFC83232))),
          ),
      ],
    );
  }

  Widget _chip(String text, {required Color color, required Color bg, Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border ?? bg),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _skillsColumns(MatchDetails d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _column(
          title: 'You have these (${d.matched.length})',
          color: const Color(0xFF1A7F4B),
          icon: Icons.check,
          child: d.matched.isEmpty
              ? Text(
                  d.noSkills ? 'Your profile has no skills yet. Add your skills to get matched.' : 'None of the required skills are in your profile.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in d.matched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _chip(
                              m.required,
                              color: m.credit == d.creditFull ? const Color(0xFF1A7F4B) : const Color(0xFFB87700),
                              bg: m.credit == d.creditFull ? const Color(0xFFEAFAF1) : const Color(0xFFFFF4E5),
                              border: m.credit == d.creditFull ? const Color(0xFFC9EFD9) : const Color(0xFFFBE2B6),
                            ),
                            if (m.yours != null && m.credit != d.creditFull)
                              Text('partly, through your ${m.yours}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted))
                            else if (m.yours != null && m.yours!.toLowerCase() != m.required.toLowerCase())
                              Text('from your ${m.yours}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        _column(
          title: 'Missing from your profile (${d.missing.length})',
          color: const Color(0xFFE03E3E),
          icon: Icons.close,
          child: d.missing.isEmpty
              ? const Text('Nothing missing - you cover every required skill.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in d.missing)
                          _chip(s, color: const Color(0xFFC83232), bg: const Color(0xFFFFF1F1), border: const Color(0xFFFECACA)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Already know these? Add them to your profile. Want to learn them? Open your Skill Roadmap.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _column({required String title, required Color color, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _extraSkills(MatchDetails d) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Also in your profile, not required here:', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        for (final s in d.extra) _chip(s, color: AppColors.textMuted, bg: Colors.white, border: AppColors.border),
        if (d.extraMore > 0) _chip('+${d.extraMore} more', color: AppColors.textMuted, bg: Colors.white, border: AppColors.border),
      ],
    );
  }

  Widget _factors(MatchDetails d) {
    final rows = <Widget>[];

    void factor(IconData icon, InlineSpan text) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text.rich(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5))),
          ],
        ),
      ));
    }

    const strong = TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark);

    if (d.distance != null) {
      factor(Icons.place_outlined, TextSpan(children: [
        const TextSpan(text: 'Distance from you: '),
        TextSpan(text: d.distance!, style: strong),
        if (d.sameCity) const TextSpan(text: ' (same city)'),
      ]));
    }
    if (d.hasMoa) {
      factor(Icons.assignment_turned_in_outlined, const TextSpan(children: [
        TextSpan(text: 'With MOA', style: strong),
        TextSpan(text: ': the school has a signed agreement with this company.'),
      ]));
    }
    if (d.hasPreference) {
      final fits = d.preferenceFits;
      factor(
        fits == true ? Icons.how_to_reg_outlined : Icons.person_search_outlined,
        TextSpan(children: [
          const TextSpan(text: 'Preferred applicants: ', style: strong),
          TextSpan(text: d.preferenceSummary ?? ''),
          if (fits != null)
            TextSpan(
              text: fits ? ' · You fit the preferred profile.' : ' · You are outside the preferred profile; you can still apply.',
              style: TextStyle(fontWeight: FontWeight.w600, color: fits ? const Color(0xFF1A7F4B) : const Color(0xFFB87700)),
            ),
          for (final c in d.preferenceChecks)
            TextSpan(text: '\n${c.label}: wants ${c.wanted ?? 'any'} · yours: ${c.yours ?? 'not set'}'),
        ]),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}
