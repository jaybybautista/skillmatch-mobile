import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../core/error_message.dart';
import '../../models/company_application.dart';
import '../../services/company_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import '../student/profile/student_public_profile_screen.dart';
import 'assign_assessment_screen.dart';

/// The status filters the web Applications page offers, in the same order.
const _statusFilters = <({String key, String label})>[
  (key: '', label: 'All'),
  (key: 'pending', label: 'Pending'),
  (key: 'under_review', label: 'Under review'),
  (key: 'interview', label: 'Interview'),
  (key: 'accepted', label: 'Accepted'),
  (key: 'rejected', label: 'Rejected'),
];

/// Applications — every student who applied to one of this company's
/// postings. Backed by /api/company/applications, the same `applications`
/// rows the website manages, so a decision made here shows up there and the
/// student is notified either way.
class CompanyApplicationsScreen extends StatefulWidget {
  const CompanyApplicationsScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyApplicationsScreen> createState() =>
      _CompanyApplicationsScreenState();
}

class _CompanyApplicationsScreenState extends State<CompanyApplicationsScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  Object? _error;
  List<CompanyApplication> _applications = const [];
  ApplicationCounts _counts = const ApplicationCounts({});
  String _status = '';

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
      final result = await _service.fetchApplications(
        status: _status,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _applications = result.applications;
        _counts = result.counts;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStatus(CompanyApplication application, String status) async {
    // Rejecting asks for an optional reason, which the student sees — the
    // same field the web form offers.
    String? reason;
    if (status == 'rejected') {
      reason = await _askRejectionReason(application);
      if (reason == null) return; // cancelled
    }

    try {
      await _service.updateApplicationStatus(
        id: application.id,
        status: status,
        rejectionReason: reason?.trim().isEmpty ?? true ? null : reason!.trim(),
      );
      _notify('${application.student.name} moved to ${_labelFor(status)}.');
      await _load();
    } catch (e) {
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  Future<String?> _askRejectionReason(CompanyApplication application) {
    return showDialog<String?>(
      context: context,
      builder: (_) => _RejectionDialog(application: application),
    );
  }

  /// Opens the applicant's profile — the course, campus, skills, education,
  /// certifications and experience the website's application detail page
  /// shows about them, read from the same /students/{id}/profile endpoint.
  void _viewProfile(CompanyApplication application) {
    final studentId = application.student.id;
    if (studentId == null) {
      // Nothing to open: the application has no student record behind it.
      _notify('This applicant has no profile on record.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentPublicProfileScreen(studentId: studentId),
      ),
    );
  }

  /// Opens the assessment picker. Assigning notifies the student and can
  /// move a pending application to Under review, so the list is reloaded
  /// afterwards rather than patched locally.
  Future<void> _assignAssessment(CompanyApplication application) async {
    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssignAssessmentScreen(
          application: application,
          service: widget.service,
        ),
      ),
    );
    if (assigned == true) await _load();
  }

  Future<void> _undo(CompanyApplication application) async {
    try {
      final updated = await _service.undoApplicationStatus(application.id);
      _notify('Reverted to ${updated.statusLabel}.');
      await _load();
    } catch (e) {
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  static String _labelFor(String status) {
    return _statusFilters
        .firstWhere(
          (f) => f.key == status,
          orElse: () => (key: status, label: status),
        )
        .label;
  }

  Future<void> _showActions(CompanyApplication application) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                child: Text(
                  application.student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  application.internshipTitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              // First in the sheet: looking at who someone is comes before
              // deciding what to do about them.
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.textDark,
                ),
                title: const Text('View profile'),
                subtitle: const Text('Skills, education, and experience'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _viewProfile(application);
                },
              ),
              const Divider(height: 1),
              for (final option in const [
                (
                  key: 'under_review',
                  label: 'Move to Under review',
                  icon: Icons.visibility_outlined,
                ),
                (
                  key: 'interview',
                  label: 'Invite to Interview',
                  icon: Icons.event_outlined,
                ),
                (
                  key: 'accepted',
                  label: 'Accept',
                  icon: Icons.check_circle_outline,
                ),
              ])
                if (application.status != option.key)
                  ListTile(
                    leading: Icon(option.icon, color: AppColors.textDark),
                    title: Text(option.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _setStatus(application, option.key);
                    },
                  ),
              ListTile(
                leading: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.textDark,
                ),
                title: Text(
                  application.assignedAssessmentId == null
                      ? 'Assign assessment'
                      : 'Reassign assessment',
                ),
                subtitle: application.assignedAssessmentTitle == null
                    ? null
                    : Text('Currently: ${application.assignedAssessmentTitle}'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _assignAssessment(application);
                },
              ),
              if (application.status != 'rejected')
                ListTile(
                  leading: const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Reject',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _setStatus(application, 'rejected');
                  },
                ),
              if (application.canUndo)
                ListTile(
                  leading: const Icon(Icons.undo, color: AppColors.primary),
                  title: const Text('Undo last change'),
                  subtitle: Text(
                    'Back to ${_labelFor(application.previousStatus ?? '')}',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _undo(application);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
      drawer: const CompanySidebar(current: CompanySidebarItem.applications),
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompanyScreenHeader(
                title: 'Applications',
                showMenuButton: true,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search applicants...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          children: [
                            for (final filter in _statusFilters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    filter.key.isEmpty
                                        ? '${filter.label} (${_counts['all']})'
                                        : '${filter.label} (${_counts[filter.key]})',
                                  ),
                                  selected: _status == filter.key,
                                  onSelected: (_) {
                                    setState(() => _status = filter.key);
                                    _load();
                                  },
                                  labelStyle: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _status == filter.key
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _status == filter.key
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  showCheckmark: false,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: _buildBody(),
                        ),
                      ),
                    ],
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
                : 'Could not load your applications.',
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

    if (_applications.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(32, 60, 32, 0),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 14),
                Text(
                  'No applications here yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Students who apply to your postings will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _applications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final application = _applications[index];
        return _ApplicationCard(
          application: application,
          onActions: () => _showActions(application),
        );
      },
    );
  }
}

/// Asks for an optional rejection reason.
///
/// A StatefulWidget so the dialog owns its controller and disposes it only
/// once the route is gone — disposing it as soon as `showDialog` returns tears
/// the field down while the close animation is still running.
class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog({required this.application});

  final CompanyApplication application;

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject application?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.application.student.name} will be told their application for '
            '"${widget.application.internshipTitle}" was not successful.',
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text(
            'Reject',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onActions});

  final CompanyApplication application;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final colors = applicationStatusColors(application.status);
    final student = application.student;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onActions,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.chipBackground,
                    backgroundImage: student.avatarUrl != null
                        ? NetworkImage(student.avatarUrl!)
                        : null,
                    child: student.avatarUrl == null
                        ? Text(
                            student.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          application.internshipTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (application.appliedAtHuman != null)
                          Text(
                            'Applied ${application.appliedAtHuman}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_vert, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      application.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                  if (application.canUndo) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.undo,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'undoable',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (application.rejectionReason != null &&
                  application.rejectionReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: ${application.rejectionReason}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
