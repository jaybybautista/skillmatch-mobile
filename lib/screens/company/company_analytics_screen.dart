import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_analytics.dart';
import '../../models/company_application.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import 'browse_candidates_screen.dart';
import 'company_applications_screen.dart';
import 'company_placements_screen.dart';
import 'company_postings_screen.dart';

/// Dashboard and analytics — the phone's version of the website's
/// company.analytics page.
///
/// Every figure is computed by CompanyAnalyticsService on the backend, which
/// the web page also asks, so the two never disagree. The metric cards lead
/// to the same screens the web cards link to.
class CompanyAnalyticsScreen extends StatefulWidget {
  const CompanyAnalyticsScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyAnalyticsScreen> createState() => _CompanyAnalyticsScreenState();
}

class _CompanyAnalyticsScreenState extends State<CompanyAnalyticsScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  Object? _error;
  CompanyAnalytics? _data;

  /// Which posting the pipeline is narrowed to, or null for all of them.
  int? _pipelineFilter;

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
      final data = await _service.fetchAnalytics(internshipId: _pipelineFilter);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  /// Refetches only to re-run the pipeline query, so the rest of the screen
  /// keeps showing its numbers instead of blanking to a spinner.
  Future<void> _applyPipelineFilter(int? internshipId) async {
    setState(() => _pipelineFilter = internshipId);
    try {
      final data = await _service.fetchAnalytics(internshipId: internshipId);
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CompanySidebar(current: CompanySidebarItem.analytics),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompanyScreenHeader(
            title: 'Dashboard and analytics',
            subtitle: 'Recruitment performance, matching, and activity',
            showMenuButton: true,
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _data == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your analytics.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final data = _data!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // The same five headline cards the web page leads with, in the same
        // order, each going where its web counterpart links.
        _MetricCard(
          label: 'Total applications',
          value: '${data.totalApplicants}',
          caption: '${data.pendingApps} pending review',
          icon: Icons.description_outlined,
          tint: AppColors.primary,
          onTap: () => _open(const CompanyApplicationsScreen()),
        ),
        _MetricCard(
          label: 'Open postings',
          value: '${data.openPostings}',
          caption: '${data.openSlots} open slots left',
          icon: Icons.work_outline,
          tint: const Color(0xFF16A34A),
          onTap: () => _open(const CompanyPostingsScreen()),
        ),
        _MetricCard(
          label: 'Average match score',
          value: '${data.avgMatchScore}%',
          caption: '${data.highMatchCount} high-match candidates',
          icon: Icons.bolt_outlined,
          tint: const Color(0xFF7E22CE),
          onTap: () => _open(const BrowseCandidatesScreen()),
        ),
        _MetricCard(
          label: 'Quizzes taken',
          value: '${data.quizzesTaken}',
          caption: 'Avg quiz score: ${data.avgQuizScore}%',
          icon: Icons.fact_check_outlined,
          tint: const Color(0xFFB45309),
        ),
        _MetricCard(
          label: 'Active interns',
          value: '${data.activePlacements}',
          caption: 'Total placements: ${data.totalPlacements}',
          icon: Icons.how_to_reg_outlined,
          tint: const Color(0xFF059669),
          onTap: () => _open(const CompanyPlacementsScreen()),
        ),

        const SizedBox(height: 8),
        _Panel(
          title: 'Applicant pipeline breakdown',
          icon: Icons.equalizer_outlined,
          trailing: _PostingFilter(
            options: data.postingOptions,
            selected: _pipelineFilter,
            onChanged: _applyPipelineFilter,
          ),
          child: data.pipelineTotal == 0
              ? const _EmptyRow('No applications to break down yet.')
              : Column(
                  children: [
                    for (final stage in data.pipelineStages)
                      _PipelineRow(stage: stage),
                  ],
                ),
        ),

        _Panel(
          title: 'Posting capacity',
          icon: Icons.work_history_outlined,
          child: Column(
            children: [
              _StatRow(label: 'Total postings', value: '${data.totalPostings}'),
              _StatRow(label: 'Open', value: '${data.openPostings}'),
              _StatRow(label: 'Closed', value: '${data.closedPostings}'),
              _StatRow(label: 'Slots still open', value: '${data.openSlots}'),
              _StatRow(label: 'Slots filled', value: '${data.slotsFilled}', isLast: true),
            ],
          ),
        ),

        _Panel(
          title: 'Assessment quiz participation',
          icon: Icons.quiz_outlined,
          child: data.assessmentRows.isEmpty
              ? const _EmptyRow('No assessments created yet.')
              : Column(
                  children: [
                    for (var i = 0; i < data.assessmentRows.length; i++)
                      _AssessmentRowTile(
                        row: data.assessmentRows[i],
                        submissions: data.quizzesTaken,
                        isLast: i == data.assessmentRows.length - 1,
                      ),
                  ],
                ),
        ),

        _Panel(
          title: 'Recruitment activity summary',
          icon: Icons.schedule_outlined,
          child: data.recentActivity.isEmpty
              ? const _EmptyRow('No recruitment activity logged yet.')
              : Column(
                  children: [
                    for (var i = 0; i < data.recentActivity.length; i++)
                      _ActivityTile(
                        row: data.recentActivity[i],
                        isLast: i == data.recentActivity.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One headline figure. Tapping goes to the screen that figure is about,
/// which is what the web's metric cards do too — [onTap] is null only for a
/// metric whose screen the app doesn't have yet.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
    this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tint, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: tint,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white card with a titled header — the phone equivalent of the web's
/// `.analytics-panel`.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// The web page's "All postings" dropdown, as a dropdown here too.
class _PostingFilter extends StatelessWidget {
  const _PostingFilter({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PostingOption> options;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All postings')),
        for (final option in options)
          DropdownMenuItem<int?>(
            value: option.id,
            child: Text(option.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// One pipeline stage: its status pill, count, and share of the total, drawn
/// as a bar so the split is readable at a glance rather than as a table of
/// percentages the phone would have to squeeze.
class _PipelineRow extends StatelessWidget {
  const _PipelineRow({required this.stage});

  final PipelineStage stage;

  @override
  Widget build(BuildContext context) {
    final colors = applicationStatusColors(stage.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stage.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${stage.count}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  '${stage.percentage}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stage.percentage / 100,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentRowTile extends StatelessWidget {
  const _AssessmentRowTile({
    required this.row,
    required this.submissions,
    required this.isLast,
  });

  final AssessmentRow row;
  final int submissions;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.questionsCount} question${row.questionsCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$submissions submission${submissions == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row, required this.isLast});

  final ActivityRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = applicationStatusColors(row.status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.studentName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            row.internshipTitle ?? 'N/A',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            'Assessment: ${row.assignedAssessment ?? 'None'} · ${row.updatedAtHuman}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      ),
    );
  }
}
