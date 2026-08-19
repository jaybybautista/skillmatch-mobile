import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/public_profile.dart';
import '../../../services/public_profile_service.dart';
import '../../../widgets/public_profile_header.dart';
import '../internship/internship_detail_screen.dart';
import '../reviews/reviews_section.dart';

/// A company's public profile — the mobile twin of
/// Student\StudentCompanyController::show / student.companies.show.
/// About, contact info, open postings, and the same reviews thread the
/// internship detail screen's Reviews tab uses.
class CompanyPublicProfileScreen extends StatefulWidget {
  const CompanyPublicProfileScreen({super.key, required this.companyId, this.service});

  final int companyId;
  final PublicProfileService? service;

  @override
  State<CompanyPublicProfileScreen> createState() => _CompanyPublicProfileScreenState();
}

class _CompanyPublicProfileScreenState extends State<CompanyPublicProfileScreen> {
  late final PublicProfileService _service = widget.service ?? PublicProfileService();
  late Future<CompanyPublicProfile> _future = _service.fetchCompany(widget.companyId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Company Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<CompanyPublicProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Could not load this company. Please check your connection.';

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
              children: [
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _future = _service.fetchCompany(widget.companyId)),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          return _buildProfile(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildProfile(CompanyPublicProfile company) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PublicProfileHeader(
          name: company.name,
          initials: company.name.isNotEmpty ? company.name.substring(0, company.name.length.clamp(0, 2)).toUpperCase() : 'C',
          avatarUrl: company.logoUrl,
          coverUrl: company.coverUrl,
          isSquareAvatar: true,
          subtitle: company.industry ?? 'Industry not specified',
          chips: [
            if ((company.city ?? '').isNotEmpty || (company.province ?? '').isNotEmpty)
              ProfileMetaChip(
                icon: Icons.place_outlined,
                label: [company.city, company.province].whereType<String>().where((s) => s.isNotEmpty).join(', '),
              ),
            if (company.isVerified)
              const ProfileMetaChip(icon: Icons.verified_outlined, label: 'Verified', color: Color(0xFF16A34A)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileSectionCard(
                icon: Icons.info_outline,
                title: 'About the Company',
                child: (company.description ?? '').isEmpty
                    ? const NoDataText('No company description added yet.')
                    : Text(company.description!, style: const TextStyle(fontSize: 13.5, height: 1.5)),
              ),
              ProfileSectionCard(
                icon: Icons.mail_outline,
                title: 'Contact Information',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileInfoRow(label: 'Address', value: company.address),
                    ProfileInfoRow(label: 'Contact Email', value: company.contactEmail),
                    ProfileInfoRow(label: 'Contact Number', value: company.contactNumber),
                  ],
                ),
              ),
              ProfileSectionCard(
                icon: Icons.work_outline,
                title: 'Available Internships (${company.openInternships.length})',
                child: company.openInternships.isEmpty
                    ? const NoDataText('This company has no open internship postings right now.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final job in company.openInternships)
                            _OpenJobCard(
                              job: job,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => InternshipDetailScreen(internshipId: job.id)),
                              ),
                            ),
                        ],
                      ),
              ),
              ProfileSectionCard(
                icon: Icons.dashboard_outlined,
                title: 'Overview',
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.work_outline,
                        color: AppColors.primary,
                        value: '${company.internshipCount}',
                        label: 'Total Postings',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF16A34A),
                        value: '${company.openInternships.length}',
                        label: 'Open Postings',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompanyReviewsScreen(companyId: company.id, companyName: company.name),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_outline, color: Color(0xFFF5A623)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Reviews & Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The company's review thread, given its own bounded screen — the same
/// [ReviewsSection] the internship detail page uses, just reached from the
/// company profile instead of an internship posting.
class CompanyReviewsScreen extends StatelessWidget {
  const CompanyReviewsScreen({super.key, required this.companyId, required this.companyName});

  final int companyId;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('$companyName · Reviews', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ReviewsSection(reviewableType: 'company', reviewableId: companyId),
    );
  }
}

class _OpenJobCard extends StatelessWidget {
  const _OpenJobCard({required this.job, required this.onTap});

  final OpenInternshipSummary job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${job.slotsAvailable} ${job.slotsAvailable == 1 ? 'slot' : 'slots'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if ((job.location ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(job.location!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              if (job.skills.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in job.skills)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(skill, style: const TextStyle(fontSize: 10.5, color: AppColors.primary)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
