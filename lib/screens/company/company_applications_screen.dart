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
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';
import '../../widgets/meeting_card.dart';

/// The status tabs the web Applications page offers, in the same order
/// (ApplicationStatusService::LABELS).
const _statusFilters = <({String key, String label})>[
  (key: '', label: 'All'),
  (key: 'pending', label: 'Pending'),
  (key: 'under_review', label: 'Under review'),
  (key: 'shortlisted', label: 'Shortlisted'),
  (key: 'assessment', label: 'Assessment'),
  (key: 'interview', label: 'Interview'),
  (key: 'offered', label: 'Offered'),
  (key: 'accepted', label: 'Accepted'),
  (key: 'rejected', label: 'Rejected'),
  (key: 'withdrawn', label: 'Withdrawn'),
  (key: 'on_hold', label: 'On hold'),
  (key: 'declined', label: 'Offer declined'),
];

/// Icons for the transition buttons the web shows per status.
const _statusIcons = <String, IconData>{
  'under_review': Icons.visibility_outlined,
  'shortlisted': Icons.star_outline,
  'assessment': Icons.fact_check_outlined,
  'interview': Icons.event_outlined,
  'offered': Icons.local_offer_outlined,
  'accepted': Icons.check_circle_outline,
  'on_hold': Icons.pause_circle_outline,
  'rejected': Icons.cancel_outlined,
};

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

  /// "Preferred only": applicants who fit the posting's preferred
  /// program / year level / campus.
  bool _preferredOnly = false;
  final _meetings = MeetingService();

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
        preferredOnly: _preferredOnly,
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

  /// "Move to Under review", "Invite to Interview", "Send an offer"...
  static String _transitionLabel(StatusOption option) {
    return switch (option.key) {
      'interview' => 'Invite to Interview',
      'offered' => 'Send an offer',
      'accepted' => 'Accept',
      'on_hold' => 'Put on hold',
      'assessment' => 'Move to Assessment',
      _ => 'Move to ${option.label}',
    };
  }

  /* ── Online meetings ─────────────────────────────────────────────── */

  Future<void> _scheduleMeeting(CompanyApplication application) async {
    final input = await showModalBottomSheet<_MeetingInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MeetingSheet(application: application),
    );
    if (input == null) return;

    try {
      final (meeting, message) = await _meetings.schedule(
        application.id,
        title: input.title,
        agenda: input.agenda,
        type: input.type,
        startNow: input.startNow,
        scheduledAt: input.scheduledAt,
        durationMinutes: input.durationMinutes,
      );
      _notify(message);
      await _load();
      // "Start now": open the room straight away, like the web.
      if (input.startNow && mounted) await _meetings.joinWithFeedback(context, meeting.id);
      if (mounted) _load();
    } catch (e) {
      _notify(messageForError(e, 'Could not set up the meeting. Check your connection and try again.'));
    }
  }

  Future<void> _rescheduleMeeting(Meeting meeting) async {
    final picked = await pickDateTime(context, initial: meeting.proposedAt ?? meeting.scheduledAt);
    if (picked == null) return;
    try {
      final (_, message) = await _meetings.reschedule(meeting.id, scheduledAt: picked);
      _notify(message);
      await _load();
    } catch (e) {
      _notify(messageForError(e, 'Could not move the meeting.'));
    }
  }

  Future<void> _cancelMeeting(Meeting meeting) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this meeting?'),
        content: const Text('The student will be told it is cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel meeting', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final (_, message) = await _meetings.cancel(meeting.id);
      _notify(message);
      await _load();
    } catch (e) {
      _notify(messageForError(e, 'Could not cancel the meeting.'));
    }
  }

  Future<void> _completeMeeting(Meeting meeting) async {
    try {
      final (_, message) = await _meetings.complete(meeting.id);
      _notify(message);
      await _load();
    } catch (e) {
      _notify(messageForError(e, 'Could not update the meeting.'));
    }
  }

  Future<void> _joinMeeting(Meeting meeting) async {
    if (await _meetings.joinWithFeedback(context, meeting.id)) _load();
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
              // The moves allowed from the current status, exactly as the
              // web's action buttons (ApplicationStatusService::TRANSITIONS).
              for (final option in application.transitions)
                if (option.key != 'rejected')
                  ListTile(
                    leading: Icon(_statusIcons[option.key] ?? Icons.arrow_forward, color: AppColors.textDark),
                    title: Text(_transitionLabel(option)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _setStatus(application, option.key);
                    },
                  ),
              if (!application.isClosed)
                ListTile(
                  leading: const Icon(Icons.video_call_outlined, color: AppColors.textDark),
                  title: const Text('Set up a meeting'),
                  subtitle: const Text('Online interview, scheduled or right now'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _scheduleMeeting(application);
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
              if (application.transitions.any((t) => t.key == 'rejected'))
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _preferredOnly,
                                activeColor: AppColors.primary,
                                onChanged: (v) {
                                  setState(() => _preferredOnly = v ?? false);
                                  _load();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Preferred only (fits the posting\'s program, year level and campus)',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
          onJoinMeeting: _joinMeeting,
          onRescheduleMeeting: _rescheduleMeeting,
          onCancelMeeting: _cancelMeeting,
          onCompleteMeeting: _completeMeeting,
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
  const _ApplicationCard({
    required this.application,
    required this.onActions,
    required this.onJoinMeeting,
    required this.onRescheduleMeeting,
    required this.onCancelMeeting,
    required this.onCompleteMeeting,
  });

  final CompanyApplication application;
  final VoidCallback onActions;
  final void Function(Meeting) onJoinMeeting;
  final void Function(Meeting) onRescheduleMeeting;
  final void Function(Meeting) onCancelMeeting;
  final void Function(Meeting) onCompleteMeeting;

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
                  // Preferred / Outside preferred, like the web's badge.
                  if (application.preferredFit != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: application.preferredSummary ?? '',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: application.preferredFit! ? const Color(0xFFEAFAF1) : const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          application.preferredFit! ? 'Preferred' : 'Outside preferred',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: application.preferredFit! ? const Color(0xFF1A7F4B) : const Color(0xFFB87700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (application.meetings.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final m in application.meetings.where((m) => m.isOpen))
                  MeetingCard(
                    meeting: m,
                    actions: [
                      if (m.isJoinable)
                        FilledButton.icon(
                          onPressed: () => onJoinMeeting(m),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), visualDensity: VisualDensity.compact),
                          icon: Icon(m.isVideo ? Icons.videocam : Icons.call, size: 16),
                          label: const Text('Join'),
                        )
                      else if (!m.isMissed)
                        Text('Room opens on ${m.opensLabel}.', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      TextButton(
                        onPressed: () => onRescheduleMeeting(m),
                        child: Text(m.status == 'reschedule_requested' ? 'Set new time' : 'Reschedule'),
                      ),
                      TextButton(
                        onPressed: () => onCompleteMeeting(m),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A7F4B)),
                        child: const Text('Mark as completed'),
                      ),
                      TextButton(
                        onPressed: () => onCancelMeeting(m),
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                for (final m in application.meetings.where((m) => !m.isOpen).take(2))
                  MeetingCard(meeting: m, compact: true),
              ],
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


/// What the "Set up a meeting" sheet hands back.
class _MeetingInput {
  const _MeetingInput({
    required this.title,
    required this.agenda,
    required this.type,
    required this.startNow,
    required this.scheduledAt,
    required this.durationMinutes,
  });

  final String title;
  final String? agenda;
  final String type;
  final bool startNow;
  final DateTime? scheduledAt;
  final int durationMinutes;
}

/// The web's "Set up a meeting" form: title, schedule for later or start
/// now, duration, video or audio, and an agenda.
class _MeetingSheet extends StatefulWidget {
  const _MeetingSheet({required this.application});

  final CompanyApplication application;

  @override
  State<_MeetingSheet> createState() => _MeetingSheetState();
}

class _MeetingSheetState extends State<_MeetingSheet> {
  late final _title = TextEditingController(text: 'Interview - ${widget.application.internshipTitle}');
  final _agenda = TextEditingController();
  String _type = 'video';
  bool _startNow = false;
  DateTime? _when;
  int _duration = 30;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final picked = await pickDateTime(context, initial: _when);
    if (picked != null) setState(() => _when = picked);
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the meeting a title.');
      return;
    }
    if (!_startNow && _when == null) {
      setState(() => _error = 'Pick a date and time, or choose "Start now".');
      return;
    }
    Navigator.of(context).pop(_MeetingInput(
      title: _title.text.trim(),
      agenda: _agenda.text.trim().isEmpty ? null : _agenda.text.trim(),
      type: _type,
      startNow: _startNow,
      scheduledAt: _startNow ? null : _when,
      durationMinutes: _duration,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Set up a meeting', style: AppFonts.title(fontSize: 18)),
            Text(
              'With ${widget.application.student.name} for ${widget.application.internshipTitle}. The student is notified and can confirm or ask for another time.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Title', counterText: ''),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Schedule for later'), icon: Icon(Icons.event_outlined)),
                ButtonSegment(value: true, label: Text('Start now'), icon: Icon(Icons.play_arrow_outlined)),
              ],
              selected: {_startNow},
              onSelectionChanged: (v) => setState(() => _startNow = v.first),
            ),
            if (!_startNow) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickWhen,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_when == null ? 'Pick date and time' : formatPickedDateTime(_when!)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _duration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: const [15, 30, 45, 60, 90, 120]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                        .toList(),
                    onChanged: (v) => setState(() => _duration = v ?? 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agenda,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Agenda (optional)', alignLabelWithHint: true, counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_startNow ? 'Start meeting now' : 'Schedule meeting'),
            ),
          ],
        ),
      ),
    );
  }
}
