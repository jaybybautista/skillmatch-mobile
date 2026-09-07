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
  List<AssessmentGroup> _groups = const [];
  List<AssessmentPostingOption> _postings = const [];

  /// Papers with no posting yet. They get their own heading, because the rest
  /// of this screen is grouped by posting and they would otherwise be lost.
  List<CompanyAssessment> _unlinked = const [];

  /// Every paper once, however many postings use it — for the counts in the
  /// delete warning, which are about the paper rather than one posting.
  List<CompanyAssessment> _assessments = const [];

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
        _groups = library.groups;
        _assessments = library.assessments;
        _postings = library.postingOptions;
        _unlinked = library.unlinked;
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

  /// Opens the results for one paper, narrowed to the posting whose
  /// heading it was tapped under — the whole point of listing it under each
  /// one. Tapped from somewhere with no posting in mind, it shows all.
  void _viewSubmissions(CompanyAssessment assessment, AssessmentGroup? group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentSubmissionsScreen(
          assessment: assessment,
          internshipId: group?.internshipId,
          service: widget.service,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CompanyAssessment card) async {
    // The card under a heading counts one posting's applicants; deleting
    // takes every result with it, so the warning uses the paper's own total.
    final assessment = _assessments.firstWhere(
      (a) => a.id == card.id,
      orElse: () => card,
    );

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

    // Postings with nothing under them are noise here; the library is a
    // list of assessments, not of postings.
    final groups = _groups.where((g) => g.assessments.isNotEmpty).toList();

    if (groups.isEmpty && _unlinked.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        if (_unlinked.isNotEmpty) ...[
          const _UnlinkedHeading(),
          const SizedBox(height: 12),
          for (final assessment in _unlinked) ...[
            _AssessmentCard(
              assessment: assessment,
              onTap: () => _preview(assessment),
              onEdit: () => _edit(assessment),
              onDelete: () => _confirmDelete(assessment),
              // Walang posting, kaya walang sagutan pang matitingnan.
              onViewSubmissions: null,
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 10),
        ],
        for (final group in groups) ...[
          _PostingHeading(group: group),
          const SizedBox(height: 12),
          for (final assessment in group.assessments) ...[
            _AssessmentCard(
              assessment: assessment,
              onTap: () => _preview(assessment),
              onEdit: () => _edit(assessment),
              onDelete: () => _confirmDelete(assessment),
              onViewSubmissions: () => _viewSubmissions(assessment, group),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// The heading for papers that have no posting yet.
class _UnlinkedHeading extends StatelessWidget {
  const _UnlinkedHeading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        border: Border.all(color: const Color(0xFFF4DFBA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.link_off,
              size: 16,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not linked to a posting',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Waiting to be attached. Open a posting and use Link '
                  'existing when you are ready.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textMuted,
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

/// The posting a run of cards belongs to, the way the web page heads each
/// block. Without it, one paper listed under two postings looks duplicated.
class _PostingHeading extends StatelessWidget {
  const _PostingHeading({required this.group});

  final AssessmentGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.work_outline, size: 17, color: AppColors.textDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            group.internshipTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.title(fontSize: 15),
          ),
        ),
        const SizedBox(width: 8),
        _Pill(
          text: group.isOpen ? 'Open' : 'Closed',
          background: group.isOpen
              ? const Color(0xFFEAFAF1)
              : AppColors.border.withValues(alpha: 0.5),
          foreground: group.isOpen
              ? const Color(0xFF1A7F4B)
              : AppColors.textMuted,
        ),
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onViewSubmissions,
  });

  final CompanyAssessment assessment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// Null for a paper with no posting: there is nothing to look at yet, so
  /// the link is left off the card rather than shown doing nothing.
  final VoidCallback? onViewSubmissions;

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
              // The heading above already names the posting this block is
              // for. What the card adds is whether this same paper is also
              // doing the job elsewhere, because that changes what editing
              // it means.
              Row(
                  children: [
                    Expanded(
                      child: Text(
                        assessment.isShared
                            ? 'Also screens for '
                                  '${assessment.internships.length - 1} other '
                                  'posting'
                                  '${assessment.internships.length == 2 ? '' : 's'}'
                            : 'Only this posting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    // One paper, several postings — said out loud, because
                    // the alternative reading is that it was copied, and
                    // that changes what editing it means.
                    if (assessment.isShared) ...[
                      _Pill(
                        text: 'Shared × ${assessment.internships.length}',
                        background: const Color(0xFFE8F0FE),
                        foreground: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _Pill(
                      text: assessment.isPublished ? 'Published' : 'Draft',
                      background: statusColors.background,
                      foreground: statusColors.text,
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
              // Wrap ito, hindi Row. Kapag kasya ang lahat sa isang linya,
              // magkalayo sila gaya ng dati. Kapag hindi na kasya, bumababa
              // na lang ang link sa susunod na linya imbes na umapaw o
              // maputol ang teksto.
              //
              // Dating Row na may Spacer sa gitna. Nauubos ang Spacer kapag
              // masikip, tapos umaapaw na - kahit sa mahabang bilang ng
              // tanong o sa mahabang "View Submissions (128)".
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                children: [
                  // Nakabalot din sa Wrap ang dalawang bilang, para kayang
                  // maghiwalay kahit maliit ang telepono o pinalaki ng
                  // gumagamit ang sukat ng teksto sa settings niya.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                        ],
                      ),
                      if (assessment.timeLimitMinutes != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                        ),
                    ],
                  ),
                  if (onViewSubmissions != null)
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

/// The small rounded labels on a card: status, and whether the paper is
/// shared between postings.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: foreground,
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
