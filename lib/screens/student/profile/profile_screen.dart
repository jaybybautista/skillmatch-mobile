import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/resume_updates.dart';
import '../../../models/student_profile.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/status_badge.dart';
import '../placement/placement_screen.dart';
import '../settings/settings_screen.dart';
import 'image_viewer_screen.dart';
import 'profile_photo_picker.dart';
import 'entry_detail_sheet.dart';
import 'profile_section_editor.dart';

/// Profile screen — pulls real data from GET /api/student/profile (course,
/// campus, contact info, resume, skills, education, certifications,
/// experience), the same tables the web app's Profile page and Resume
/// Builder populate.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.service});

  /// Injectable for tests; defaults to the real service.
  final ProfileService? service;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with ResumeUpdateListener {
  late final ProfileService _service = widget.service ?? ProfileService();
  late Future<StudentProfile> _future = _service.fetchStudentProfile();

  void _refresh() {
    setState(() {
      _future = _service.fetchStudentProfile();
    });
  }

  /// Importing a resume auto-fills this page's skills, education and
  /// experience from what the parser read, so a resume change is a profile
  /// change — the profile has to hear about it too.
  @override
  void onResumeChanged() => _refresh();



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: FutureBuilder<StudentProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load your profile. Please check your connection.';

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setState(
                        () => _future = _service.fetchStudentProfile(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _ProfileBody(
            profile: snapshot.data!,
            service: _service,
            onBack: () => Navigator.of(context).pop(),
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

/// "Currently doing OJT at ..." banner — tapping it opens the full My
/// Placement tracker. Only rendered when the student actually has a
/// placement row.
class _CurrentPlacementCard extends StatelessWidget {
  const _CurrentPlacementCard({required this.placement});

  final PlacementIndicator placement;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PlacementScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: placement.companyLogoUrl != null
                      ? Image.network(
                          placement.companyLogoUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _initial(),
                        )
                      : _initial(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'CURRENTLY AT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: placement.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      placement.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.title(fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      placement.roleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initial() => Text(
    placement.companyName.isNotEmpty
        ? placement.companyName[0].toUpperCase()
        : 'C',
    style: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
  );
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({
    required this.profile,
    required this.onBack,
    required this.onRefresh,
    required this.service,
  });

  final ProfileService service;
  final StudentProfile profile;
  final VoidCallback onBack;

  /// Called after returning from Settings (or changing the photo), so edits
  /// show up without needing to leave the tab.
  final VoidCallback onRefresh;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  // The avatar straddles the blue gap / white sheet boundary. Both the gap
  // and the avatar live inside the Expanded Stack, which clips at its top
  // edge — so as the list scrolls the avatar rides up with it and is cut off
  // cleanly at the header row instead of sliding over the menu and title.
  static const double _avatarSize = 92;
  static const double _avatarOverlap = 42;
  static const double _blueGap = 48;

  final _scrollController = ScrollController();
  double _scrollOffset = 0;

  StudentProfile get profile => widget.profile;

  ProfileService get _service => widget.service;

  /// Runs a save or delete, then reloads so the screen shows what the server
  /// actually stored rather than what the phone hoped it stored.
  Future<void> _afterChange(bool changed, String message) async {
    if (!changed || !mounted) return;

    widget.onRefresh();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeEntry({
    required String what,
    required Future<void> Function() remove,
  }) async {
    if (!await confirmSectionDelete(context, what)) return;

    try {
      await remove();
      if (!mounted) return;
      await _afterChange(true, 'Entry removed.');
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not remove that entry.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editSummary(StudentProfile profile) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: 'Professional summary',
      saveLabel: 'Save summary',
      fields: [
        EditorField(
          key: 'summary',
          label: 'About you',
          initial: profile.professionalSummary,
          type: EditorFieldType.multiline,
          hint: 'A few sentences about who you are and the work you want.',
        ),
      ],
      onSave: (values) => _service.updateSummary(values['summary'] ?? ''),
    );

    await _afterChange(saved, 'Professional summary saved.');
  }

  Future<void> _editSkills(StudentProfile profile) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: 'Skills',
      saveLabel: 'Save skills',
      fields: [
        EditorField(
          key: 'skills',
          label: 'Skills',
          initial: profile.skills.join(', '),
          type: EditorFieldType.multiline,
          hint: 'Separate each one with a comma.',
        ),
      ],
      onSave: (values) => _service.updateSkills(
        (values['skills'] ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      ),
    );

    await _afterChange(saved, 'Skills saved.');
  }

  Future<void> _editEducation([EducationEntry? entry]) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: entry == null ? 'Add education' : 'Edit education',
      fields: [
        EditorField(
          key: 'institution',
          label: 'Institution',
          initial: entry?.institution,
          required: true,
        ),
        EditorField(key: 'degree', label: 'Degree', initial: entry?.degree),
        EditorField(
          key: 'field_of_study',
          label: 'Field of study',
          initial: entry?.fieldOfStudy,
        ),
        EditorField(
          key: 'start_year',
          label: 'Start year',
          initial: entry?.startYear?.toString(),
          type: EditorFieldType.year,
        ),
        EditorField(
          key: 'end_year',
          label: 'End year (blank if ongoing)',
          initial: entry?.endYear?.toString(),
          type: EditorFieldType.year,
        ),
      ],
      onSave: (values) => _service.saveEducation(
        id: entry?.id,
        institution: values['institution'] ?? '',
        degree: values['degree'],
        fieldOfStudy: values['field_of_study'],
        startYear: int.tryParse(values['start_year'] ?? ''),
        endYear: int.tryParse(values['end_year'] ?? ''),
      ),
    );

    await _afterChange(saved, entry == null ? 'Education added.' : 'Education updated.');
  }

  Future<void> _editCertification([CertificationInfo? entry]) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: entry == null ? 'Add certification' : 'Edit certification',
      fields: [
        EditorField(
          key: 'title',
          label: 'Title',
          initial: entry?.title,
          required: true,
        ),
        EditorField(
          key: 'issuing_organization',
          label: 'Issuing organization',
          initial: entry?.issuingOrganization,
        ),
        EditorField(
          key: 'issue_date',
          label: 'Issue date',
          initial: entry?.issueDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'expiry_date',
          label: 'Expiry date (optional)',
          initial: entry?.expiryDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'credential_url',
          label: 'Credential link (optional)',
          initial: entry?.credentialUrl,
          type: EditorFieldType.url,
        ),
      ],
      onSave: (values) => _service.saveCertification(
        id: entry?.id,
        title: values['title'] ?? '',
        issuingOrganization: values['issuing_organization'],
        issueDate: values['issue_date'],
        expiryDate: values['expiry_date'],
        credentialUrl: values['credential_url'],
      ),
    );

    await _afterChange(
      saved,
      entry == null ? 'Certification added.' : 'Certification updated.',
    );
  }

  Future<void> _editExperience([ExperienceInfo? entry]) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: entry == null ? 'Add experience' : 'Edit experience',
      fields: [
        EditorField(
          key: 'position',
          label: 'Position',
          initial: entry?.position,
          required: true,
        ),
        EditorField(
          key: 'organization',
          label: 'Organization',
          initial: entry?.organization,
          required: true,
        ),
        EditorField(
          key: 'type',
          label: 'Type',
          initial: entry?.type ?? 'work',
          type: EditorFieldType.choice,
          required: true,
          choices: const [
            (value: 'work', label: 'Work experience'),
            (value: 'extracurricular', label: 'Extracurricular'),
          ],
        ),
        EditorField(
          key: 'start_date',
          label: 'Start date',
          initial: entry?.startDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'end_date',
          label: 'End date (blank if ongoing)',
          initial: entry?.endDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'description',
          label: 'Description',
          initial: entry?.description,
          type: EditorFieldType.multiline,
        ),
      ],
      onSave: (values) => _service.saveExperience(
        id: entry?.id,
        position: values['position'] ?? '',
        organization: values['organization'] ?? '',
        type: values['type'] ?? 'work',
        startDate: values['start_date'],
        endDate: values['end_date'],
        description: values['description'],
      ),
    );

    await _afterChange(
      saved,
      entry == null ? 'Experience added.' : 'Experience updated.',
    );
  }

  Future<void> _editProject([ProjectInfo? entry]) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: entry == null ? 'Add project' : 'Edit project',
      fields: [
        EditorField(
          key: 'title',
          label: 'Title',
          initial: entry?.title,
          required: true,
        ),
        EditorField(
          key: 'role',
          label: 'Your role (optional)',
          initial: entry?.role,
        ),
        EditorField(
          key: 'start_date',
          label: 'Start date',
          initial: entry?.startDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'end_date',
          label: 'End date (blank if ongoing)',
          initial: entry?.endDateRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'link',
          label: 'Link (optional)',
          initial: entry?.link,
          type: EditorFieldType.url,
        ),
        EditorField(
          key: 'description',
          label: 'Description',
          initial: entry?.description,
          type: EditorFieldType.multiline,
        ),
      ],
      onSave: (values) => _service.saveProject(
        id: entry?.id,
        title: values['title'] ?? '',
        role: values['role'],
        description: values['description'],
        link: values['link'],
        startDate: values['start_date'],
        endDate: values['end_date'],
      ),
    );

    await _afterChange(saved, entry == null ? 'Project added.' : 'Project updated.');
  }

  Future<void> _editAchievement([AchievementInfo? entry]) async {
    final saved = await showProfileSectionEditor(
      context: context,
      title: entry == null ? 'Add achievement' : 'Edit achievement',
      fields: [
        EditorField(
          key: 'title',
          label: 'Title',
          initial: entry?.title,
          required: true,
        ),
        EditorField(
          key: 'issuer',
          label: 'Awarded by (optional)',
          initial: entry?.issuer,
        ),
        EditorField(
          key: 'date_awarded',
          label: 'Date awarded',
          initial: entry?.dateAwardedRaw,
          type: EditorFieldType.date,
        ),
        EditorField(
          key: 'description',
          label: 'Description (optional)',
          initial: entry?.description,
          type: EditorFieldType.multiline,
        ),
      ],
      onSave: (values) => _service.saveAchievement(
        id: entry?.id,
        title: values['title'] ?? '',
        issuer: values['issuer'],
        dateAwarded: values['date_awarded'],
        description: values['description'],
      ),
    );

    await _afterChange(
      saved,
      entry == null ? 'Achievement added.' : 'Achievement updated.',
    );
  }


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    // Clamped so an overscroll bounce doesn't push the avatar back down.
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    if ((offset - _scrollOffset).abs() < 0.5) return;
    setState(() => _scrollOffset = offset);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: _header(context),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _blueGap),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      _avatarSize - _avatarOverlap + 22,
                      20,
                      32,
                    ),
                    children: [
                      if (profile.placement != null) ...[
                        _CurrentPlacementCard(placement: profile.placement!),
                        const SizedBox(height: 16),
                      ],
                      _ContactCard(profile: profile),
                      const SizedBox(height: 24),
                      // Sumusunod agad ito sa personal na detalye, gaya ng
                      // pagkakasunod ng tab sa web. Ito ang unang binabasa ng
                      // kompanyang tumitingin sa kanya, kaya malapit din ito
                      // sa umpisa habang inaayos niya.
                      _SectionTitle(
                        'Professional Summary',
                        actionIcon: Icons.edit_outlined,
                        actionLabel: 'Edit',
                        onAction: () => _editSummary(profile),
                      ),
                      const SizedBox(height: 10),
                      _SummaryCard(profile: profile),
                      const SizedBox(height: 24),
                      const _SectionTitle('Resume'),
                      const SizedBox(height: 10),
                      _ResumeCard(profile: profile),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        'Skills',
                        actionIcon: Icons.edit_outlined,
                        actionLabel: 'Edit',
                        onAction: () => _editSkills(profile),
                      ),
                      const SizedBox(height: 10),
                      _SkillsCard(profile: profile),
                      const SizedBox(height: 24),
                      const _SectionTitle('Campus'),
                      const SizedBox(height: 10),
                      _EducationCard(profile: profile),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        'Education',
                        onAction: () => _editEducation(),
                      ),
                      const SizedBox(height: 10),
                      if (profile.educationHistory.isEmpty)
                        const _EmptyStateCard(
                          text: 'No education added yet.',
                        )
                      else
                        for (final entry in profile.educationHistory) ...[
                          _EducationEntryCard(
                            entry: entry,
                            onEdit: () => _editEducation(entry),
                            onRemove: entry.id == null
                                ? null
                                : () => _removeEntry(
                                    what: entry.institution ?? 'this entry',
                                    remove: () =>
                                        _service.deleteEducation(entry.id!),
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 12),
                      _SectionTitle(
                        'Certification',
                        onAction: () => _editCertification(),
                      ),
                      const SizedBox(height: 10),
                      if (profile.certifications.isEmpty)
                        const _EmptyStateCard(
                          text: 'No certifications added yet.',
                        )
                      else
                        for (final cert in profile.certifications) ...[
                          _CertificationCard(
                            certification: cert,
                            onEdit: () => _editCertification(cert),
                            onRemove: cert.id == null
                                ? null
                                : () => _removeEntry(
                                    what: cert.title ?? 'this entry',
                                    remove: () =>
                                        _service.deleteCertification(cert.id!),
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 12),
                      _SectionTitle(
                        'Experience',
                        onAction: () => _editExperience(),
                      ),
                      const SizedBox(height: 10),
                      if (profile.experiences.isEmpty)
                        const _EmptyStateCard(text: 'No experience added yet.')
                      else
                        for (final exp in profile.experiences) ...[
                          _ExperienceCard(
                            experience: exp,
                            onEdit: () => _editExperience(exp),
                            onRemove: exp.id == null
                                ? null
                                : () => _removeEntry(
                                    what: exp.position ?? 'this entry',
                                    remove: () =>
                                        _service.deleteExperience(exp.id!),
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 12),
                      _SectionTitle(
                        'Projects',
                        onAction: () => _editProject(),
                      ),
                      const SizedBox(height: 10),
                      if (profile.projects.isEmpty)
                        const _EmptyStateCard(text: 'No projects added yet.')
                      else
                        for (final project in profile.projects) ...[
                          _ProjectCard(
                            project: project,
                            onEdit: () => _editProject(project),
                            onRemove: project.id == null
                                ? null
                                : () => _removeEntry(
                                    what: project.title ?? 'this entry',
                                    remove: () =>
                                        _service.deleteProject(project.id!),
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 12),
                      _SectionTitle(
                        'Achievements',
                        onAction: () => _editAchievement(),
                      ),
                      const SizedBox(height: 10),
                      if (profile.achievements.isEmpty)
                        const _EmptyStateCard(text: 'No achievements added yet.')
                      else
                        for (final award in profile.achievements) ...[
                          _AchievementCard(
                            achievement: award,
                            onEdit: () => _editAchievement(award),
                            onRemove: award.id == null
                                ? null
                                : () => _removeEntry(
                                    what: award.title ?? 'this entry',
                                    remove: () =>
                                        _service.deleteAchievement(award.id!),
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: _blueGap - _avatarOverlap - _scrollOffset,
                left: 20,
                right: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Avatar(
                      profile: profile,
                      size: _avatarSize,
                      onPhotoChanged: widget.onRefresh,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.title(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.education?.major ?? profile.course ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: widget.onBack,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Profile',
            style: AppFonts.title(fontSize: 26, color: Colors.white),
          ),
        ),
        InkWell(
          onTap: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            widget.onRefresh();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded-square profile photo with a camera badge. Tapping the photo opens
/// the full-screen viewer (which also offers "Change Photo"); tapping the
/// badge — or the placeholder, when there's no photo yet — goes straight to
/// picking a new one.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.profile,
    required this.size,
    required this.onPhotoChanged,
  });

  final StudentProfile profile;
  final double size;
  final VoidCallback onPhotoChanged;

  static const _heroTag = 'profile-photo';

  @override
  Widget build(BuildContext context) {
    final url = profile.profilePictureUrl;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initials(),
              )
            : _initials(),
      ),
    );

    if (url != null) avatar = Hero(tag: _heroTag, child: avatar);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () async {
              if (url == null) {
                final changed = await pickAndUploadProfilePhoto(context);
                if (changed) onPhotoChanged();
                return;
              }
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrl: url,
                    heroTag: _heroTag,
                    title: profile.name,
                  ),
                ),
              );
              if (changed == true) onPhotoChanged();
            },
            child: avatar,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: () async {
                final changed = await pickAndUploadProfilePhoto(context);
                if (changed) onPhotoChanged();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    final trimmed = profile.name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
              .split(RegExp(r'\s+'))
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    return Container(
      color: AppColors.chipBackground,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 26,
        ),
      ),
    );
  }
}

/// A section heading, with the button that adds to it or edits it.
///
/// The one-off sections (summary, skills) pass an edit icon; the list
/// sections leave it as the default plus, because there the button adds a new
/// row rather than editing the existing one.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
    this.title, {
    this.onAction,
    this.actionIcon = Icons.add,
    this.actionLabel = 'Add',
  });

  final String title;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    if (onAction == null) {
      return Text(title, style: AppFonts.title(fontSize: 17));
    }

    return Row(
      children: [
        Expanded(child: Text(title, style: AppFonts.title(fontSize: 17))),
        TextButton.icon(
          onPressed: onAction,
          icon: Icon(actionIcon, size: 17),
          label: Text(actionLabel),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    );
  }
}

/// The edit and remove menu on a single row.
///
/// Only shown where the row can actually be changed, so a row with no id (a
/// card built by a test, say) simply does not get one.
class _RowMenu extends StatelessWidget {
  const _RowMenu({this.onEdit, this.onRemove});

  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onRemove == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      tooltip: 'Options',
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'remove') onRemove?.call();
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (onRemove != null)
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
      ],
    );
  }
}

/// One school the student attended.
class _EducationEntryCard extends StatelessWidget {
  const _EducationEntryCard({required this.entry, this.onEdit, this.onRemove});

  final EducationEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: () => showEntryDetails(
        context,
        title: entry.institution ?? 'Education',
        icon: Icons.school_outlined,
        details: [
          EntryDetail('Institution', entry.institution),
          EntryDetail('Degree', entry.degree),
          EntryDetail('Field of study', entry.fieldOfStudy),
          EntryDetail('Start year', entry.startYear?.toString()),
          EntryDetail('End year', entry.endYear?.toString() ?? 'Ongoing'),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.institution ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if ((entry.degree ?? '').isNotEmpty)
                  Text(
                    entry.degree!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                if ((entry.fieldOfStudy ?? '').isNotEmpty)
                  Text(
                    entry.fieldOfStudy!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                Text(
                  entry.period,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _RowMenu(onEdit: onEdit, onRemove: onRemove),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;

  /// Pag may nito, bumubukas ang kahon ng detalye kapag pinindot ito. Yung
  /// tatlong tuldok, sarili niyang pindutan, kaya hindi sila nagkakabanggaan.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
    }

    // Material ang puting likod, hindi Container.
    //
    // Dito nagmumukhang mabagal dati. Nakabalot noon ang InkWell sa isang
    // Container na puti at makapal - at sa Material na nasa likod nun
    // ipinipinta ang alon ng pindot, kaya natatabunan ito at walang
    // lumalabas. Walang tugon ang tile sa daliri, tapos saka pa lang aahon
    // ang kahon - kaya parang may hinihintay pa bago ito bumukas.
    //
    // Pag Material na ang mismong likod, sa ibabaw na nito ipinipinta ang
    // alon, kaya may nakikita sila agad sa mismong sandali ng pindot.
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
          child: child,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _ContactRow(icon: Icons.email_outlined, value: profile.email),
    ];
    if (profile.contactNumber != null && profile.contactNumber!.isNotEmpty) {
      rows.add(
        _ContactRow(icon: Icons.phone_outlined, value: profile.contactNumber!),
      );
    }
    if (profile.location != null && profile.location!.isNotEmpty) {
      rows.add(
        _ContactRow(icon: Icons.location_on_outlined, value: profile.location!),
      );
    }

    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textDark, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.resume == null) {
      return const _EmptyStateCard(text: 'No resume uploaded yet.');
    }

    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.resume!.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Uploaded Resume',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final summary = profile.professionalSummary;
    if (summary == null || summary.isEmpty) {
      return const _EmptyStateCard(text: 'No professional summary added yet.');
    }
    return _Card(
      child: Text(
        summary,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.skills.isEmpty) {
      return const _EmptyStateCard(text: 'No skills added yet.');
    }

    return _Card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final skill in profile.skills)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                skill,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final education = profile.education;
    if (education == null) {
      return const _EmptyStateCard(text: 'No education info added yet.');
    }

    return _Card(
      child: Column(
        children: [
          _LabelValueRow(label: 'School', value: education.school),
          _LabelValueRow(
            label: 'School Address',
            value: education.schoolAddress,
          ),
          _LabelValueRow(label: 'Program', value: education.program),
          _LabelValueRow(label: 'Major', value: education.major),
        ],
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({required this.certification, this.onEdit, this.onRemove});

  final CertificationInfo certification;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: () => showEntryDetails(
        context,
        title: certification.title ?? 'Certification',
        icon: Icons.verified_outlined,
        details: [
          EntryDetail('Certification', certification.title),
          EntryDetail('Issuing organization', certification.issuingOrganization),
          EntryDetail('Issued', certification.issueDate),
          EntryDetail('Credential URL', certification.credentialUrl),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _LabelValueRow(
                  label: 'Certificate',
                  value: certification.title,
                ),
                _LabelValueRow(
                  label: 'Organization',
                  value: certification.issuingOrganization,
                ),
                _LabelValueRow(label: 'Issued', value: certification.issueDate),
              ],
            ),
          ),
          _RowMenu(onEdit: onEdit, onRemove: onRemove),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.experience, this.onEdit, this.onRemove});

  final ExperienceInfo experience;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: () => showEntryDetails(
        context,
        title: experience.position ?? 'Experience',
        icon: Icons.work_outline,
        details: [
          EntryDetail('Position', experience.position),
          EntryDetail('Organization', experience.organization),
          EntryDetail('Type', experience.type),
          EntryDetail('Started', experience.startDate),
          EntryDetail('Ended', experience.endDate ?? 'Present'),
          EntryDetail('Description', experience.description),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experience.position ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (experience.organization != null)
                  Text(
                    experience.organization!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${experience.startDate ?? ''}${experience.startDate != null ? ' - ' : ''}${experience.endDate ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _RowMenu(onEdit: onEdit, onRemove: onRemove),
        ],
      ),
    );
  }
}

/// Isang proyekto sa profile. Kaparehong hugis ng _ExperienceCard para
/// magkatugma yung buong listahan.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, this.onEdit, this.onRemove});

  final ProjectInfo project;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final period = project.startDate == null
        ? null
        : '${project.startDate} to ${project.endDate ?? 'Present'}';

    return _Card(
      onTap: () => showEntryDetails(
        context,
        title: project.title ?? 'Project',
        icon: Icons.lightbulb_outline,
        details: [
          EntryDetail('Project', project.title),
          EntryDetail('Role', project.role),
          EntryDetail('Started', project.startDate),
          EntryDetail(
            'Ended',
            project.startDate == null ? null : (project.endDate ?? 'Present'),
          ),
          EntryDetail('Link', project.link),
          EntryDetail('Description', project.description),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.code, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if ((project.role ?? '').isNotEmpty)
                  Text(
                    project.role!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (period != null)
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if ((project.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    project.description!,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
                if ((project.link ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    project.link!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _RowMenu(onEdit: onEdit, onRemove: onRemove),
        ],
      ),
    );
  }
}

/// Isang parangal sa profile.
class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, this.onEdit, this.onRemove});

  final AchievementInfo achievement;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: () => showEntryDetails(
        context,
        title: achievement.title ?? 'Achievement',
        icon: Icons.emoji_events_outlined,
        details: [
          EntryDetail('Achievement', achievement.title),
          EntryDetail('Issuer', achievement.issuer),
          EntryDetail('Awarded', achievement.dateAwarded),
          EntryDetail('Description', achievement.description),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if ((achievement.issuer ?? '').isNotEmpty)
                  Text(
                    achievement.issuer!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                if ((achievement.dateAwarded ?? '').isNotEmpty)
                  Text(
                    achievement.dateAwarded!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if ((achievement.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    achievement.description!,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          _RowMenu(onEdit: onEdit, onRemove: onRemove),
        ],
      ),
    );
  }
}
