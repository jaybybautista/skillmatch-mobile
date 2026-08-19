import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/student_profile.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/status_badge.dart';
import '../placement/placement_screen.dart';
import '../settings/settings_screen.dart';
import 'image_viewer_screen.dart';
import 'profile_photo_picker.dart';

/// Profile screen — pulls real data from GET /api/student/profile (course,
/// campus, contact info, resume, skills, education, certifications,
/// experience), the same tables the web app's Profile page and Resume
/// Builder populate.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  late Future<StudentProfile> _future = _service.fetchStudentProfile();

  void _refresh() => setState(() => _future = _service.fetchStudentProfile());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: FutureBuilder<StudentProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                    Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white),
                      onPressed: () => setState(() => _future = _service.fetchStudentProfile()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _ProfileBody(
            profile: snapshot.data!,
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlacementScreen())),
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
                          errorBuilder: (context, error, stackTrace) => _initial(),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        placement.companyName.isNotEmpty ? placement.companyName[0].toUpperCase() : 'C',
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
      );
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.profile, required this.onBack, required this.onRefresh});

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(20, _avatarSize - _avatarOverlap + 22, 20, 32),
                  children: [
                    if (profile.placement != null) ...[
                      _CurrentPlacementCard(placement: profile.placement!),
                      const SizedBox(height: 16),
                    ],
                    _ContactCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Resume'),
                    const SizedBox(height: 10),
                    _ResumeCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Professional Summary'),
                    const SizedBox(height: 10),
                    _SummaryCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Skills'),
                    const SizedBox(height: 10),
                    _SkillsCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Education'),
                    const SizedBox(height: 10),
                    _EducationCard(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionTitle('Certification'),
                    const SizedBox(height: 10),
                    if (profile.certifications.isEmpty)
                      const _EmptyStateCard(text: 'No certifications added yet.')
                    else
                      for (final cert in profile.certifications) ...[
                        _CertificationCard(certification: cert),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 12),
                    const _SectionTitle('Experience'),
                    const SizedBox(height: 10),
                    if (profile.experiences.isEmpty)
                      const _EmptyStateCard(text: 'No experience added yet.')
                    else
                      for (final exp in profile.experiences) ...[
                        _ExperienceCard(experience: exp),
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
                    _Avatar(profile: profile, size: _avatarSize, onPhotoChanged: widget.onRefresh),
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
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
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
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            widget.onRefresh();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
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
  const _Avatar({required this.profile, required this.size, required this.onPhotoChanged});

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _initials())
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
                  builder: (_) => ImageViewerScreen(imageUrl: url, heroTag: _heroTag, title: profile.name),
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
                child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 14),
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
        : trimmed.split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      color: AppColors.chipBackground,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 26),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppFonts.title(fontSize: 17));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Text(text, style: const TextStyle(color: AppColors.textMuted)));
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
      rows.add(_ContactRow(icon: Icons.phone_outlined, value: profile.contactNumber!));
    }
    if (profile.location != null && profile.location!.isNotEmpty) {
      rows.add(_ContactRow(icon: Icons.location_on_outlined, value: profile.location!));
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
          decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 14))),
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
            decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Text('Uploaded Resume', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
    return _Card(child: Text(summary, style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.5)));
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
              decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(20)),
              child: Text(skill, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
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
          _LabelValueRow(label: 'School Address', value: education.schoolAddress),
          _LabelValueRow(label: 'Program', value: education.program),
          _LabelValueRow(label: 'Major', value: education.major),
        ],
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({required this.certification});

  final CertificationInfo certification;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _LabelValueRow(label: 'Certificate', value: certification.title),
          _LabelValueRow(label: 'Organization', value: certification.issuingOrganization),
          _LabelValueRow(label: 'Issued', value: certification.issueDate),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.experience});

  final ExperienceInfo experience;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.work_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(experience.position ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (experience.organization != null)
                  Text(experience.organization!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${experience.startDate ?? ''}${experience.startDate != null ? ' - ' : ''}${experience.endDate ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
