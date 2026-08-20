import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../models/company_assessment.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import '../../widgets/empty_results.dart';
import 'assessment_preview_screen.dart';
import 'assessment_submissions_screen.dart';
import 'create_assessment_screen.dart';

/// The company's Assessment Library — every assessment this company has
/// written, backed by /api/company/assessments.
///
/// Those are the same `assessments` rows the website's library page lists,
/// written through the shared CompanyAssessmentService, so creating, editing
/// or deleting here is exactly what doing it on the web would be.
class AssessmentLibraryScreen extends StatefulWidget {
  const AssessmentLibraryScreen({super.key, this.service});

  final CompanyAssessmentService? service;

  @override
  State<AssessmentLibraryScreen> createState() =>
      _AssessmentLibraryScreenState();
}

class _AssessmentLibraryScreenState extends State<AssessmentLibraryScreen> {
  late final CompanyAssessmentService _service =
      widget.service ?? CompanyAssessmentService();

  bool _isLoading = true;
  Object? _error;
  List<CompanyAssessment> _assessments = const [];
  List<AssessmentPostingOption> _postings = const [];

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
      final library = await _service.fetchLibrary();
      if (!mounted) return;
      setState(() {
        _assessments = library.assessments;
        _postings = library.postingOptions;
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAssessment() async {
    if (_postings.isEmpty) {
      // The backend requires a posting, and only open ones are offered — the
      // same rule the web's dropdown enforces.
      _notify('Open a posting first — an assessment always screens for one.');
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateAssessmentScreen(
          postings: _postings,
          service: widget.service,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _edit(CompanyAssessment assessment) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateAssessmentScreen(
          postings: _postings,
          existing: assessment,
          service: widget.service,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  void _preview(CompanyAssessment assessment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentPreviewScreen(
          assessmentId: assessment.id,
          initialTitle: assessment.title,
          service: widget.service,
        ),
      ),
    );
  }

  void _viewSubmissions(CompanyAssessment assessment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentSubmissionsScreen(
          assessment: assessment,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CompanyAssessment assessment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete assessment?'),
        content: Text(
          assessment.submissionCount > 0
              // Deleting cascades to the results, so a company about to lose
              // real attempts should be told before it happens.
              ? '"${assessment.title}" has ${assessment.submissionCount} '
                    'submission${assessment.submissionCount == 1 ? '' : 's'}. '
                    'Deleting it removes those results too.'
              : '"${assessment.title}" will be removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAssessment(assessment.id);
      _notify('"${assessment.title}" has been deleted.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CompanySidebar(current: CompanySidebarItem.assessments),
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyScreenHeader(
                title: 'Assessment Library',
                showMenuButton: true,
                trailing: IconButton(
                  onPressed: _createAssessment,
                  icon: const Icon(Icons.add, color: Colors.white, size: 26),
                  tooltip: 'New assessment',
                ),
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
      // Kept alongside the drawer: this screen is also the bottom bar's third
      // tab, so removing the bar would strand anyone who arrived that way.
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: 2,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your assessments.',
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

    if (_assessments.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          EmptyResults(
            title: 'No assessments yet',
            hint: 'Tap the + button above to create your first assessment.',
            icon: Icons.quiz_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: _assessments.length,
      itemBuilder: (_, index) {
        final assessment = _assessments[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _assessments.length - 1 ? 0 : 16,
          ),
          child: _AssessmentCard(
            assessment: assessment,
            onTap: () => _preview(assessment),
            onEdit: () => _edit(assessment),
            onDelete: () => _confirmDelete(assessment),
            onViewSubmissions: () => _viewSubmissions(assessment),
          ),
        );
      },
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onViewSubmissions,
  });

  final CompanyAssessment assessment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewSubmissions;

  @override
  Widget build(BuildContext context) {
    final statusColors = assessmentStatusColors(assessment.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      assessment.title,
                      style: AppFonts.title(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconAction(
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 8),
                  _IconAction(
                    icon: Icons.delete_outline,
                    onTap: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // The posting an assessment screens for is part of what it is,
              // so it sits right under the title as the web page has it.
              if (assessment.internshipTitle != null)
                Row(
                  children: [
                    const Icon(
                      Icons.work_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        assessment.internshipTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        assessment.isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: statusColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              if (assessment.description != null &&
                  assessment.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  assessment.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.quiz_outlined,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${assessment.questionCount} '
                    'Question${assessment.questionCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (assessment.timeLimitMinutes != null) ...[
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 17,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${assessment.timeLimitMinutes} Mins',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: onViewSubmissions,
                    child: Text(
                      assessment.submissionCount > 0
                          ? 'View Submissions (${assessment.submissionCount})'
                          : 'View Submissions',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: AppColors.textDark),
        ),
      ),
    );
  }
}
