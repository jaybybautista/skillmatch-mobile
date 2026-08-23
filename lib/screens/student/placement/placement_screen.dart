import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/placement.dart';
import '../../../services/placement_service.dart';
import '../../../widgets/app_sidebar.dart';
import '../../../widgets/status_badge.dart';
import '../internship/internship_detail_screen.dart';
import '../matches/matches_list_screen.dart';

/// My Placement — GET /api/student/placement, backed by the same
/// `placements` row the web app's My Placement page reads: the same
/// company, coordinator, dates, remarks, evaluation score and history, plus
/// the hours the coordinator has recorded against the placement.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key, this.service});

  /// Injected in tests so the screen can be driven without a server.
  final PlacementService? service;

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  late final PlacementService _service = widget.service ?? PlacementService();

  bool _isLoading = true;
  Object? _error;
  PlacementSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await _service.fetchPlacement();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(current: SidebarItem.placement),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A drawer rather than a back arrow: this is one of the
                  // sidebar's own destinations now, the same as Requirements
                  // and Applications, so it has to be able to reach the rest
                  // of the app instead of only the screen that opened it.
                  Builder(
                    builder: (context) => InkWell(
                      onTap: Scaffold.of(context).openDrawer,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Placement',
                          style: AppFonts.title(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Track your OJT progress, rendered hours, and coordinator details',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      final message = _error is ApiException
          ? (_error as ApiException).message
          : 'Could not load your placement.';
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final summary = _summary!;
    final placement = summary.placement;

    if (placement == null) return _NoPlacementCard();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _HeroCard(placement: placement, summary: summary),
        const SizedBox(height: 16),
        _InfoPanel(
          icon: Icons.person_outline,
          title: 'Your OJT coordinator',
          rows: [
            ('Name', placement.coordinatorName),
            ('Department', placement.coordinatorDept ?? 'OJT department'),
            ('Email', placement.coordinatorEmail ?? 'Not available'),
            (
              'Campus',
              placement.coordinatorCampus ??
                  summary.studentCampus ??
                  'Not available',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _EvaluationCard(score: placement.evaluationScore),
        // Finishing one OJT and starting another should not hide the first,
        // which is why the web lists earlier records underneath.
        if (summary.history.isNotEmpty) ...[
          const SizedBox(height: 16),
          _HistoryPanel(entries: summary.history),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.placement, required this.summary});

  final Placement placement;
  final PlacementSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompanyLogo(
                logoUrl: placement.companyLogoUrl,
                initial: placement.companyInitial,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placement.roleTitle,
                      style: AppFonts.title(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      placement.companyName,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: placement.status, compact: true),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _FieldGrid(
            fields: [
              ('Start date', placement.startDate, placement.startDate == null),
              ('End date', placement.endDate, placement.endDate == null),
              ('Location', placement.location ?? 'Not specified', false),
              (
                'Record created',
                placement.recordedAt ?? 'Not available',
                placement.recordedAt == null,
              ),
            ],
          ),
          // How much of the *period* has passed, counted in days. Only shown
          // when both dates are set, because otherwise there is no period to
          // measure — the same rule the web page follows.
          if (summary.progressPercent != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Progress',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: summary.progressPercent! / 100,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${summary.progressPercent}% of your placement period has passed',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          if (placement.internshipId != null) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InternshipDetailScreen(
                    internshipId: placement.internshipId!,
                  ),
                ),
              ),
              child: const Text(
                'View the original posting',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The web lays the placement's fields out two to a row, with the label
/// above the value and unset values greyed.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});

  /// (label, value, isEmpty) — an empty value still shows its placeholder,
  /// just muted, so the row keeps its shape.
  final List<(String, String?, bool)> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < fields.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Field(field: fields[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < fields.length
                    ? _Field(field: fields[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.field});

  final (String, String?, bool) field;

  @override
  Widget build(BuildContext context) {
    final (label, value, isEmpty) = field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? 'Not set',
          style: TextStyle(
            fontSize: 13.5,
            color: isEmpty ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

/// The evaluation card: the coordinator's mark out of 100, or a line saying
/// there isn't one yet.
class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evaluation', style: AppFonts.title(fontSize: 15)),
          const SizedBox(height: 12),
          if (score == null)
            const Text(
              'No evaluation score has been recorded yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$score', style: AppFonts.title(fontSize: 26)),
                const SizedBox(width: 4),
                const Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppFonts.title(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Earlier placements, newest first — the same list the web page keeps
/// below the current record.
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.entries});

  final List<PlacementHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Previous Placements', style: AppFonts.title(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.roleTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.companyName} \u00b7 ${entry.period}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusBadge(status: entry.status),
              ],
            ),
            if (entry != entries.last) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _NoPlacementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.chipBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Active Placement Recorded',
                textAlign: TextAlign.center,
                style: AppFonts.title(fontSize: 17),
              ),
              const SizedBox(height: 10),
              const Text(
                'Once a company accepts your application and your OJT placement is confirmed by your academic '
                'coordinator, your placement details and hours tracker will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MatchesListScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Browse Internships'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Applications are coming soon.'),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('View Applications'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.logoUrl, required this.initial});

  final String? logoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Text(
    initial,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
      fontSize: 20,
    ),
  );
}
