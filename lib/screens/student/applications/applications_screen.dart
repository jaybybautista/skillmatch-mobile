import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_navigation.dart';
import '../../../core/app_theme.dart';
import '../../../models/application.dart';
import '../../../models/meeting.dart';
import '../../../services/application_service.dart';
import '../../../services/meeting_service.dart';
import '../../../widgets/meeting_card.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../widgets/empty_results.dart';
import '../../../widgets/moa_tag.dart';
import '../assessments/assessment_intro_screen.dart';
import '../../../widgets/app_sidebar.dart';

/// Applications — GET /api/student/applications, the same rows and the same
/// status/assessment rules as the web app's Applications page.
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

/// How often the list checks for changes made elsewhere — the same 15 seconds
/// the web layout polls on.
const _pollInterval = Duration(seconds: 15);

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with WidgetsBindingObserver {
  final _service = ApplicationService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _poll;

  bool _isLoading = true;
  Object? _error;
  ApplicationsResult? _result;

  /// Last seen state per application, so a tick can tell what actually changed.
  Map<int, ApplicationStatusEntry> _lastSnapshot = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _poll = Timer.periodic(_pollInterval, (_) => _pollStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _poll?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background is the likeliest moment to be stale, and
    // there's no point polling while the app isn't visible.
    if (state == AppLifecycleState.resumed) {
      _pollStatus();
    }
  }

  /// Compares a fresh snapshot against the last one and, when something moved,
  /// tells the student and reloads the list underneath them.
  Future<void> _pollStatus() async {
    if (_isLoading) return;

    try {
      final snapshot = await _service.fetchStatusSnapshot();
      if (!mounted) return;

      final previous = _lastSnapshot;
      _lastSnapshot = snapshot.statuses;

      // First tick just seeds the baseline — announcing everything at startup
      // would be noise, not news.
      if (previous.isEmpty) return;

      final messages = <String>[];

      for (final entry in snapshot.statuses.values) {
        final before = previous[entry.id];
        if (before == null) continue;

        if (before.status != entry.status) {
          messages.add(_statusChangeMessage(entry));
        } else if (!before.isReassignment && entry.isReassignment) {
          messages.add(
            '"${entry.internshipTitle}" assessment was reassigned. You can answer it again.',
          );
        } else if (!before.hasPendingAssessment && entry.hasPendingAssessment) {
          messages.add(
            'A competency assessment was assigned for "${entry.internshipTitle}".',
          );
        }
      }

      if (messages.isEmpty) return;

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(messages.first),
            duration: const Duration(seconds: 5),
          ),
        );
    } catch (_) {
      // Offline or a blip — the next tick tries again.
    }
  }

  static String _statusChangeMessage(ApplicationStatusEntry entry) {
    final title = entry.internshipTitle;
    switch (entry.status) {
      case 'accepted':
        return "You've been accepted for \"$title\"!";
      case 'rejected':
        return 'Your application for "$title" was not selected.';
      case 'interview':
        return 'You have been invited to an interview for "$title"!';
      case 'under_review':
        return '"$title" is now under review.';
      default:
        return 'Application status updated for "$title".';
    }
  }

  final _meetings = MeetingService();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Accept or decline the company's offer, like the web's offer box.
  Future<void> _respondToOffer(ApplicationSummary application, bool accept) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Accept the offer?' : 'Decline this offer?'),
        content: Text(accept
            ? 'Accept the offer for ${application.internshipTitle}? Your coordinator will then set up your placement.'
            : 'Declining cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: accept ? const Color(0xFF16A34A) : AppColors.danger),
            child: Text(accept ? 'Accept offer' : 'Decline'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _toast(await _meetings.respondToOffer(application.id, accept: accept));
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  /// Confirm, or ask for another time (with a date and an optional note).
  Future<void> _respondToMeeting(ApplicationSummary application, Meeting meeting, String action) async {
    DateTime? proposedAt;
    String? note;

    if (action == 'reschedule') {
      final picked = await pickDateTime(context);
      if (picked == null || !mounted) return;
      proposedAt = picked;
      final noteController = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ask to reschedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are available on ${formatPickedDateTime(picked)}.', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Note (optional), e.g. I have a class at that time', counterText: ''),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(noteController.text.trim()), child: const Text('Send request')),
          ],
        ),
      );
      if (note == null || !mounted) return;
    }

    try {
      final (updated, message) = await _meetings.respond(meeting.id, action: action, proposedAt: proposedAt, note: note);
      if (!mounted) return;
      setState(() => _result = _result?.replacing(application.withMeeting(updated)));
      _toast(message);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _joinMeeting(Meeting meeting) async {
    if (await _meetings.joinWithFeedback(context, meeting.id)) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchApplications(
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
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

  /// Opens the competency test. The flow reports back when an attempt was
  /// submitted so the card can flip to "Assessment Completed" straight away.
  Future<void> _takeAssessment(ApplicationSummary application) async {
    final assessmentId = application.assessmentId;
    if (assessmentId == null) return;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssessmentIntroScreen(assessmentId: assessmentId),
      ),
    );

    if (submitted == true && mounted) await _load();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(current: SidebarItem.applications),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  // Builder so openDrawer() sees the Scaffold above it.
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: Scaffold.of(context).openDrawer,
                      tooltip: 'Menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Applications',
                      style: AppFonts.title(color: Colors.white, fontSize: 24),
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
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onSelect: (i) => handleAppNavTap(context, i),
      ),
    );
  }

  Widget _buildBody() {
    final result = _result;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _SearchField(
          controller: _searchController,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _Message(
            text: _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your applications.',
            onRetry: _load,
          )
        else if (result == null || result.applications.isEmpty)
          _searchController.text.trim().isEmpty
              ? const EmptyResults(
                  icon: Icons.description_outlined,
                  title: 'No applications yet',
                  hint: "Internships you apply to will show up here.",
                )
              : const EmptyResults(
                  title: 'No applications found',
                  hint: 'Try a different keyword.',
                )
        else ...[
          // Green reassignment banner wins over the blue "new test" one, the
          // same precedence the web view applies.
          if (result.hasReassignment) ...[
            const _ReassignmentBanner(),
            const SizedBox(height: 16),
          ] else if (result.hasNewAssessment) ...[
            const _NewAssessmentBanner(),
            const SizedBox(height: 16),
          ],
          for (final application in result.applications) ...[
            _ApplicationCard(
              application: application,
              pipeline: result.pipeline,
              onTakeAssessment: () => _takeAssessment(application),
              onOffer: (accept) => _respondToOffer(application, accept),
              onMeetingRespond: (m, action) => _respondToMeeting(application, m, action),
              onJoinMeeting: (m) => _joinMeeting(m),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search internships...',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, color: AppColors.primary, size: 20),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// The web's `.test-assigned-banner`, shown once when any application still
/// has an assessment waiting.
class _NewAssessmentBanner extends StatelessWidget {
  const _NewAssessmentBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_none, color: Color(0xFF3D6EF5), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New competency test assigned',
              style: TextStyle(
                color: Color(0xFF3D6EF5),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the blue banner once a completed assessment has been
/// reassigned — the web's green `.test-assigned-banner` variant.
class _ReassignmentBanner extends StatelessWidget {
  const _ReassignmentBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _retakeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.refresh, color: _retakeText, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Competency assessment reassigned. You can answer it again.',
              style: TextStyle(
                color: _retakeText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green palette from the web's reassignment badge and retake button.
const _retakeSurface = Color(0xFFF0FDF4);
const _retakeText = Color(0xFF15803D);
const _retakeBorder = Color(0xFFBBF7D0);
const _retakeButton = Color(0xFF16A34A);

/// The web's `.reassignment-badge`, sitting directly above the retake button.
class _ReassignmentBadge extends StatelessWidget {
  const _ReassignmentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: _retakeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _retakeBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 14, color: _retakeText),
          SizedBox(width: 6),
          Text(
            'Assessment Reassigned',
            style: TextStyle(
              color: _retakeText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.pipeline,
    required this.onTakeAssessment,
    required this.onOffer,
    required this.onMeetingRespond,
    required this.onJoinMeeting,
  });

  final ApplicationSummary application;
  final List<PipelineStep> pipeline;
  final VoidCallback onTakeAssessment;
  final void Function(bool accept) onOffer;
  final void Function(Meeting meeting, String action) onMeetingRespond;
  final void Function(Meeting meeting) onJoinMeeting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CompanyLogo(
                logoUrl: application.companyLogoUrl,
                initial: application.companyInitial,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.internshipTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Ang tanda, nasa tabi ng pangalan, kaparehong-kapareho
                    // ng nakita niya noong nagba-browse pa lang siya.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            application.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (application.companyHasMoa) ...[
                          const SizedBox(width: 6),
                          const MoaTag(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (application.hasPendingAssessment) ...[
            if (application.isReassignment) const _ReassignmentBadge(),
            ElevatedButton(
              onPressed: onTakeAssessment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: application.isReassignment
                    ? _retakeButton
                    : null,
              ),
              child: Text(
                application.isReassignment
                    ? 'Retake Assessment'
                    : 'Take Assessment',
              ),
            ),
          ] else ...[
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: application.statusBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                application.statusLabel,
                style: TextStyle(
                  color: application.statusTextColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // The web's stepper: how far along pending -> accepted this is.
            if (pipeline.isNotEmpty && application.pipelineIndex != null) ...[
              const SizedBox(height: 12),
              _PipelineStepper(steps: pipeline, current: application.pipelineIndex!),
            ],
            if (application.statusHint != null) ...[
              const SizedBox(height: 8),
              Text(
                application.statusHint!,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ],
          if (application.offerPending) ...[
            const SizedBox(height: 12),
            _OfferBox(companyName: application.companyName, onOffer: onOffer),
          ],
          if (application.meetings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MeetingsSection(
              meetings: application.meetings,
              onRespond: onMeetingRespond,
              onJoin: onJoinMeeting,
            ),
          ],
        ],
      ),
    );
  }
}

/// pending -> under review -> shortlisted -> assessment -> interview ->
/// offered -> accepted, with the reached steps filled in.
class _PipelineStepper extends StatelessWidget {
  const _PipelineStepper({required this.steps, required this.current});

  final List<PipelineStep> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.primary : Colors.white,
                  border: Border.all(color: i <= current ? AppColors.primary : AppColors.border, width: 2),
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(height: 2, color: i < current ? AppColors.primary : AppColors.border),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(steps.first.label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            Text(
              'Step ${current + 1} of ${steps.length}: ${steps[current].label}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            Text(steps.last.label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

/// "You have an offer!" with Accept / Decline, like the web's offer box.
class _OfferBox extends StatelessWidget {
  const _OfferBox({required this.companyName, required this.onOffer});

  final String companyName;
  final void Function(bool accept) onOffer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBCFE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You have an offer!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9D174D))),
          const SizedBox(height: 4),
          Text(
            '$companyName offered you this internship. Accept to move forward - your coordinator will set up the placement - or decline if you are going elsewhere.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF831843), height: 1.45),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => onOffer(true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  child: const Text('Accept offer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onOffer(false),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9F1239), side: const BorderSide(color: Color(0xFFFECDD3))),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The application's online meetings: open ones with their actions, then
/// up to two past ones, as the web lists them.
class _MeetingsSection extends StatelessWidget {
  const _MeetingsSection({required this.meetings, required this.onRespond, required this.onJoin});

  final List<Meeting> meetings;
  final void Function(Meeting meeting, String action) onRespond;
  final void Function(Meeting meeting) onJoin;

  @override
  Widget build(BuildContext context) {
    final open = meetings.where((m) => m.isOpen).toList();
    final past = meetings.where((m) => !m.isOpen).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Online meeting${meetings.length > 1 ? 's' : ''}'.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.textMuted),
        ),
        for (final m in open)
          MeetingCard(
            meeting: m,
            actions: [
              if (m.isJoinable)
                FilledButton.icon(
                  onPressed: () => onJoin(m),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), visualDensity: VisualDensity.compact),
                  icon: Icon(m.isVideo ? Icons.videocam : Icons.call, size: 16),
                  label: const Text('Join meeting'),
                )
              else if (m.isMissed)
                const Text('The time has passed. Ask the company for a new schedule.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))
              else
                Text('Room opens on ${m.opensLabel}.', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              if (m.status == 'scheduled' && !m.isMissed)
                TextButton(onPressed: () => onRespond(m, 'confirm'), child: const Text('Confirm')),
              if (m.status == 'scheduled' || m.status == 'confirmed')
                TextButton(
                  onPressed: () => onRespond(m, 'reschedule'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                  child: const Text('Ask to reschedule'),
                ),
            ],
          ),
        for (final m in past) MeetingCard(meeting: m, compact: true),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                width: 46,
                height: 46,
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
      fontSize: 18,
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
