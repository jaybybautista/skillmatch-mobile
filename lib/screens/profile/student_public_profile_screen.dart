import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/public_profile.dart';
import '../../services/public_profile_service.dart';
import '../../widgets/public_profile_header.dart';
import 'profile_screen.dart';

/// A read-only view of another student — the mobile twin of
/// Student\StudentPeerController::show / student.students.show.
///
/// If [studentId] turns out to be the viewer's own record, the API says so
/// and this redirects to [ProfileScreen] instead — the same self-redirect the
/// web controller does, so tapping your own name in a review or search
/// result never shows you a stripped-down copy of your own profile.
class StudentPublicProfileScreen extends StatefulWidget {
  const StudentPublicProfileScreen({super.key, required this.studentId, this.service});

  final int studentId;
  final PublicProfileService? service;

  @override
  State<StudentPublicProfileScreen> createState() => _StudentPublicProfileScreenState();
}

class _StudentPublicProfileScreenState extends State<StudentPublicProfileScreen> {
  late final PublicProfileService _service = widget.service ?? PublicProfileService();
  late Future<StudentPublicProfile> _future = _service.fetchStudent(widget.studentId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Student Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<StudentPublicProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load this profile. Please check your connection.';

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
              children: [
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _future = _service.fetchStudent(widget.studentId)),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final profile = snapshot.data!;

          if (profile.isSelf) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }

          return _buildProfile(profile);
        },
      ),
    );
  }

  Widget _buildProfile(StudentPublicProfile profile) {
    final name = profile.name ?? 'Student';
    final initials = _initialsFor(name);
    final tagline = [
      profile.course ?? 'Student',
      if (profile.yearLevel != null) 'Year ${profile.yearLevel}',
    ].join(' · ');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PublicProfileHeader(
          name: name,
          initials: initials,
          avatarUrl: profile.avatarUrl,
          coverUrl: profile.coverUrl,
          subtitle: tagline,
          chips: [
            if (profile.campus != null)
              ProfileMetaChip(icon: Icons.apartment_outlined, label: profile.campus!),
            if (profile.isOnOjt)
              ProfileMetaChip(
                icon: Icons.check_circle_outline,
                label: 'On OJT${profile.placementCompany != null ? ' at ${profile.placementCompany}' : ''}',
                color: const Color(0xFF16A34A),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSectionCard(
                icon: Icons.psychology_outlined,
                title: 'Skills',
                child: profile.skills.isEmpty
                    ? const NoDataText('No skills listed yet.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final skill in profile.skills)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.chipBackground,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(skill, style: const TextStyle(fontSize: 12.5, color: AppColors.primary)),
                            ),
                        ],
                      ),
              ),
              ProfileSectionCard(
                icon: Icons.school_outlined,
                title: 'Education',
                child: profile.education.isEmpty
                    ? const NoDataText('No education history added yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final edu in profile.education)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(edu.institution ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  Text(
                                    [edu.degree, edu.fieldOfStudy].whereType<String>().join(', '),
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                  ),
                                  if (edu.startYear != null)
                                    Text(
                                      '${edu.startYear} to ${edu.endYear ?? 'Present'}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              if (profile.certifications.isNotEmpty)
                ProfileSectionCard(
                  icon: Icons.verified_outlined,
                  title: 'Certifications',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cert in profile.certifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cert.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              Text(cert.issuingOrganization ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (profile.experiences.isNotEmpty)
                ProfileSectionCard(
                  icon: Icons.work_outline,
                  title: 'Experience',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final exp in profile.experiences)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.position ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              Text(exp.organization ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                              if (exp.description != null && exp.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(exp.description!, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ProfileSectionCard(
                icon: Icons.info_outline,
                title: 'Overview',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileInfoRow(label: 'Course', value: profile.course),
                    ProfileInfoRow(label: 'Year Level', value: profile.yearLevel != null ? 'Year ${profile.yearLevel}' : null),
                    ProfileInfoRow(label: 'Campus', value: profile.campus),
                    ProfileInfoRow(label: 'Status', value: profile.isOnOjt ? 'On OJT' : 'Available'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
