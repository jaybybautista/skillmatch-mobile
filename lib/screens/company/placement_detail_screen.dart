import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_placement.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';

/// One placement in full — the phone's version of the website's
/// company.placements.show page: the student's particulars, the posting they
/// were placed into, the timeline, hours logged, and the assigned
/// coordinator.
class PlacementDetailScreen extends StatefulWidget {
  const PlacementDetailScreen({
    super.key,
    required this.placementId,
    this.initialName,
    this.service,
  });

  final int placementId;

  /// Shown in the header while the detail loads, so the screen doesn't open
  /// on an anonymous "Placement".
  final String? initialName;

  final CompanyService? service;

  @override
  State<PlacementDetailScreen> createState() => _PlacementDetailScreenState();
}

class _PlacementDetailScreenState extends State<PlacementDetailScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  Object? _error;
  CompanyPlacementDetail? _detail;

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
      final detail = await _service.fetchPlacement(widget.placementId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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
    final title = _detail?.placement.studentName ?? widget.initialName ?? 'Placement';

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyScreenHeader(
            title: title,
            subtitle: _detail?.placement.internshipTitle,
            onBack: () => Navigator.of(context).pop(),
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

    if (_error != null || _detail == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load this placement.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final detail = _detail!;
    final placement = detail.placement;
    final colors = placementStatusColors(placement.status);
    final internship = detail.internship;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Card(
          title: 'Student',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      placement.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow('Email', placement.studentEmail),
              _InfoRow('Student number', placement.studentNumber),
              _InfoRow('Course', detail.course),
              _InfoRow(
                'Year level',
                detail.yearLevel == null ? null : 'Year ${detail.yearLevel}',
              ),
              _InfoRow('Campus', detail.campus),
              _InfoRow('Contact', detail.contactNumber),
              _InfoRow('Address', detail.address, isLast: true),
            ],
          ),
        ),

        _Card(
          title: 'Hours rendered',
          icon: Icons.timer_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${detail.hoursRendered} of ${detail.requiredHours} hours',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: detail.hoursProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              if (detail.evaluationScore != null) ...[
                const SizedBox(height: 10),
                _InfoRow('Evaluation score', '${detail.evaluationScore}', isLast: true),
              ],
              if (detail.remarks != null && detail.remarks!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detail.remarks!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (internship != null)
          _Card(
            title: 'Internship position',
            icon: Icons.work_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  internship.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (internship.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          internship.location!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                if (internship.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _Subheading('Required skills'),
                  _Chips(internship.skills),
                ],
                if (internship.responsibilities.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _Subheading('Responsibilities'),
                  for (final item in internship.responsibilities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

        _Card(
          title: 'Timeline',
          icon: Icons.event_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Placement created', placement.createdAtHuman),
              _InfoRow('Start date', placement.startDate),
              _InfoRow('End date', placement.endDate),
              _InfoRow('Last updated', placement.updatedAtHuman, isLast: true),
            ],
          ),
        ),

        _Card(
          title: 'Assigned coordinator',
          icon: Icons.school_outlined,
          child: detail.coordinatorName == null
              ? const Text(
                  'No coordinator assigned.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.coordinatorName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (detail.coordinatorEmail != null)
                      Text(
                        detail.coordinatorEmail!,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                  ],
                ),
        ),

        if (detail.studentSkills.isNotEmpty)
          _Card(
            title: 'Student skills',
            icon: Icons.lightbulb_outline,
            child: _Chips(detail.studentSkills),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A label/value pair. Renders nothing when the value is missing, which is
/// what the web page's `@if` guards do around every one of these rows.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
