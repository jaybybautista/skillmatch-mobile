import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../models/company_application.dart' show applicationStatusColors;
import '../../models/company_placement.dart' show placementStatusColors;
import '../../models/company_record.dart';
import '../../services/company_records_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';

/// Which report is on screen. The website splits these across four pages;
/// on a phone they are tabs over one list, which keeps the filters and the
/// search box in one place.
enum _RecordTab {
  applications('Applications'),
  assessments('Assessments'),
  placements('Placements');

  const _RecordTab(this.label);

  final String label;
}

/// Records and reports — the read-only history behind this company's
/// postings, backed by /api/company/records.
///
/// Those are the same rows the website's Records pages list, queried by the
/// shared CompanyRecordsService, so a filter that matches here matches there.
class CompanyRecordsScreen extends StatefulWidget {
  const CompanyRecordsScreen({super.key, this.service});

  final CompanyRecordsService? service;

  @override
  State<CompanyRecordsScreen> createState() => _CompanyRecordsScreenState();
}

class _CompanyRecordsScreenState extends State<CompanyRecordsScreen> {
  late final CompanyRecordsService _service =
      widget.service ?? CompanyRecordsService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  Object? _error;

  RecordsOverview? _overview;
  List<ApplicationRecord> _applications = const [];
  List<AssessmentRecord> _assessments = const [];
  List<PlacementRecord> _placements = const [];

  _RecordTab _tab = _RecordTab.applications;
  int? _postingFilter;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // The overview is only fetched once — its counters do not depend on the
      // filters, and refetching it on every keystroke would be wasteful.
      final overview = _overview ?? await _service.fetchOverview();
      await _loadTab(overview);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTab(RecordsOverview overview) async {
    final query = _searchController.text;

    switch (_tab) {
      case _RecordTab.applications:
        final rows = await _service.fetchApplications(
          status: _statusFilter,
          internshipId: _postingFilter,
          query: query,
        );
        if (!mounted) return;
        setState(() => _applications = rows);
      case _RecordTab.assessments:
        final rows = await _service.fetchAssessments(
          internshipId: _postingFilter,
          query: query,
        );
        if (!mounted) return;
        setState(() => _assessments = rows);
      case _RecordTab.placements:
        final rows = await _service.fetchPlacements(
          status: _statusFilter,
          query: query,
        );
        if (!mounted) return;
        setState(() => _placements = rows);
    }

    if (!mounted) return;
    setState(() {
      _overview = overview;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _switchTab(_RecordTab tab) {
    setState(() {
      _tab = tab;
      // The filters mean different things per tab, so they reset rather than
      // carrying a status that this report doesn't have.
      _statusFilter = '';
      _postingFilter = null;
    });
    _load();
  }

  /// The status values each report can be narrowed by. Assessments have none:
  /// every row there is a completed attempt.
  List<({String key, String label})> get _statusOptions => switch (_tab) {
    _RecordTab.applications => const [
      (key: '', label: 'All'),
      (key: 'pending', label: 'Pending'),
      (key: 'under_review', label: 'Under review'),
      (key: 'interview', label: 'Interview'),
      (key: 'accepted', label: 'Accepted'),
      (key: 'rejected', label: 'Rejected'),
    ],
    _RecordTab.placements => [
      const (key: '', label: 'All'),
      for (final status in _overview?.placementStatuses ?? const <String>[])
        (key: status, label: status[0].toUpperCase() + status.substring(1)),
    ],
    _RecordTab.assessments => const [],
  };

  int get _visibleCount => switch (_tab) {
    _RecordTab.applications => _applications.length,
    _RecordTab.assessments => _assessments.length,
    _RecordTab.placements => _placements.length,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Every top-level company screen carries the bar, so navigation
      // doesn't change shape depending on how you arrived. This screen is
      // not one of its four tabs, hence no highlight.
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: -1,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
      drawer: const CompanySidebar(current: CompanySidebarItem.records),
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompanyScreenHeader(
                title: 'Records and reports',
                subtitle: 'Everything that has happened around your postings',
                showMenuButton: true,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
          // Same launcher the web keeps on every page.
          const MatchaLauncher(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _overview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your records. Check your connection and try again.',
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

    final overview = _overview!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // The same four counters the website's records landing page leads
        // with, two to a row so they stay readable on a phone.
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Applications',
                value: overview.totalApplications,
                icon: Icons.description_outlined,
                tint: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Placements',
                value: overview.totalPlacements,
                icon: Icons.how_to_reg_outlined,
                tint: const Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Assessments',
                value: overview.totalAssessments,
                icon: Icons.fact_check_outlined,
                tint: const Color(0xFF7E22CE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Attempts completed',
                value: overview.totalCompleted,
                icon: Icons.task_alt,
                tint: const Color(0xFFB45309),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        SegmentedButton<_RecordTab>(
          segments: [
            for (final tab in _RecordTab.values)
              ButtonSegment(value: tab, label: Text(tab.label)),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _switchTab(selection.first),
        ),

        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search by student name...',
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
          ),
        ),

        if (_statusOptions.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final option in _statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: _statusFilter == option.key,
                      onSelected: (_) {
                        setState(() => _statusFilter = option.key);
                        _load();
                      },
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: _statusFilter == option.key
                            ? Colors.white
                            : AppColors.textDark,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Placements hang off the company, not a posting, so narrowing them
        // by posting would be meaningless.
        if (_tab != _RecordTab.placements &&
            overview.postingOptions.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            key: ValueKey<int?>(_postingFilter),
            initialValue: _postingFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All postings'),
              ),
              for (final option in overview.postingOptions)
                DropdownMenuItem<int?>(
                  value: option.id,
                  child: Text(option.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              setState(() => _postingFilter = value);
              _load();
            },
          ),
        ],

        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${_tab.label} record${_visibleCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            if (_isLoading)
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                '$_visibleCount',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        ..._buildRows(),
      ],
    );
  }

  List<Widget> _buildRows() {
    if (_visibleCount == 0) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 36,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No ${_tab.label.toLowerCase()} on record yet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Records appear here as students apply, take assessments, '
                'and get placed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ];
    }

    return switch (_tab) {
      _RecordTab.applications => [
        for (final row in _applications)
          _RecordCard(
            name: row.studentName,
            avatarUrl: row.avatarUrl,
            subtitle: [row.course, row.campus].whereType<String>().join(' · '),
            detail: row.internshipTitle ?? 'No posting on record',
            trailing: row.appliedAt ?? '',
            pillLabel: row.status.replaceAll('_', ' '),
            pillColors: applicationStatusColors(row.status),
          ),
      ],
      _RecordTab.assessments => [
        for (final row in _assessments)
          _RecordCard(
            name: row.studentName,
            avatarUrl: row.avatarUrl,
            subtitle: row.course ?? '',
            detail:
                '${row.assessmentTitle ?? 'Assessment'} · '
                '${row.score}/${row.totalPoints} (${row.percentage}%)',
            trailing: row.submittedAt ?? '',
            pillLabel: row.timedOut
                ? 'Timed out'
                : row.passed
                ? 'Passed'
                : 'Failed',
            pillColors: row.timedOut
                ? (
                    background: AppColors.warningBackground,
                    text: AppColors.warning,
                  )
                : row.passed
                ? (
                    background: const Color(0xFFEAFAF1),
                    text: const Color(0xFF1A7F4B),
                  )
                : (background: const Color(0xFFFFF1F1), text: AppColors.danger),
          ),
      ],
      _RecordTab.placements => [
        for (final row in _placements)
          _RecordCard(
            name: row.studentName,
            avatarUrl: row.avatarUrl,
            subtitle: [
              row.campus,
              row.coordinatorName,
            ].whereType<String>().join(' · '),
            detail: row.internshipTitle ?? 'No posting on record',
            trailing: '${row.startDate ?? '—'} → ${row.endDate ?? 'ongoing'}',
            pillLabel: row.status[0].toUpperCase() + row.status.substring(1),
            pillColors: placementStatusColors(row.status),
          ),
      ],
    };
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: tint,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of any of the three reports — they carry the same shape (who,
/// what, when, and an outcome), so they share a card rather than three
/// near-identical ones.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.name,
    required this.avatarUrl,
    required this.subtitle,
    required this.detail,
    required this.trailing,
    required this.pillLabel,
    required this.pillColors,
  });

  final String name;
  final String? avatarUrl;
  final String subtitle;
  final String detail;
  final String trailing;
  final String pillLabel;
  final ({Color background, Color text}) pillColors;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pillColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
