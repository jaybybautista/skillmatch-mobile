import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../models/company_application.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/empty_results.dart';
import 'candidate_detail_screen.dart';
import 'company_posting.dart';

enum _ApplicantView {
  topMatches('Top Matches'),
  allApplicants('All Applicants');

  const _ApplicantView(this.label);

  final String label;
}

/// Everyone who applied to one posting — the real `applications` rows for it,
/// read from /api/company/applications?internship_id=…, the same rows the
/// Applications screen and the website manage.
///
/// "Top Matches" ranks them by the AI match score for this exact posting
/// (the same `internship_matches` rows Browse candidates sorts by); "All
/// Applicants" keeps them newest-first.
class PostingApplicantsScreen extends StatefulWidget {
  const PostingApplicantsScreen({
    super.key,
    required this.posting,
    this.service,
  });

  final CompanyPosting posting;
  final CompanyService? service;

  @override
  State<PostingApplicantsScreen> createState() =>
      _PostingApplicantsScreenState();
}

class _PostingApplicantsScreenState extends State<PostingApplicantsScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();
  final _searchController = TextEditingController();

  var _view = _ApplicantView.topMatches;
  bool _isLoading = true;
  Object? _error;
  List<CompanyApplication> _applications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
        internshipId: widget.posting.id,
      );
      if (!mounted) return;
      setState(() {
        _applications = result.applications;
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

  /// Filtered and ordered for the current view. Done locally: the list is one
  /// posting's applicants, so it is short enough that a round trip per
  /// keystroke would be the slower option.
  List<CompanyApplication> get _visible {
    final query = _searchController.text.trim().toLowerCase();

    final results = query.isEmpty
        ? List<CompanyApplication>.of(_applications)
        : _applications
              .where((a) => a.student.name.toLowerCase().contains(query))
              .toList();

    if (_view == _ApplicantView.topMatches) {
      // Applicants with no computed match sort last rather than as zero, so a
      // posting whose matches haven't run yet doesn't look like a wall of
      // bad candidates.
      results.sort(
        (a, b) => (b.matchScore ?? -1).compareTo(a.matchScore ?? -1),
      );
    }

    return results;
  }

  void _openCandidate(CompanyApplication application) {
    final studentId = application.student.id;
    if (studentId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(
          studentId: studentId,
          initialName: application.student.name,
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: widget.posting.title,
            subtitle: _isLoading
                ? 'Applicants'
                : '${_applications.length} '
                      'applicant${_applications.length == 1 ? '' : 's'}',
            onBack: () => Navigator.of(context).maybePop(),
            trailing: IconButton(
              tooltip: 'Switch view',
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: () => setState(
                () => _view = _view == _ApplicantView.topMatches
                    ? _ApplicantView.allApplicants
                    : _ApplicantView.topMatches,
              ),
            ),
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
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search applicants...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        for (final view in _ApplicantView.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(view.label),
                              selected: _view == view,
                              onSelected: (_) => setState(() => _view = view),
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                color: _view == view
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
            messageForError(_error!, 'Could not load the applicants.'),
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

    final applicants = _visible;

    if (applicants.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyResults(
            title: _searchController.text.trim().isEmpty
                ? 'No applicants yet'
                : 'No matching applicants',
            hint: _searchController.text.trim().isEmpty
                ? 'Students who apply to this posting will appear here.'
                : 'No one on this posting matches that name.',
            icon: Icons.people_outline,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: applicants.length,
      itemBuilder: (_, index) => Padding(
        padding: EdgeInsets.only(
          bottom: index == applicants.length - 1 ? 0 : 14,
        ),
        child: _ApplicantCard(
          application: applicants[index],
          onTap: () => _openCandidate(applicants[index]),
        ),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.application, required this.onTap});

  final CompanyApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final student = application.student;
    final statusColors = applicationStatusColors(application.status);
    final avatarUrl = student.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.chipBackground,
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: hasAvatar
                        ? null
                        : Text(
                            student.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                          style: AppFonts.title(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            student.course,
                            student.campus,
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      application.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              // Only shown once the matcher has actually run for this pair —
              // an absent score is not a zero score.
              if (application.matchScore != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${application.matchScore}% match',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: application.matchScore! / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (application.matchedSkills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in application.matchedSkills.take(6))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (application.appliedAtHuman != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Applied ${application.appliedAtHuman}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
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
