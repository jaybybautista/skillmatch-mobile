import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/draggable_chatbot_button.dart';
import '../chatbot/matcha_chat_screen.dart';
import 'company_posting.dart';
import 'company_postings_screen.dart';
import 'company_profile_screen.dart';
import 'create_assessment_screen.dart';
import 'posting_applicants_screen.dart';

/// Home dashboard shown to a company account, mirroring the student
/// [HomeScreen]'s layout (header + search, rounded white body, floating
/// chatbot) with company-specific content: active postings and a shortcut
/// into creating an assessment.
class CompanyHomeScreen extends StatelessWidget {
  const CompanyHomeScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');

    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppGradients.companyHeader,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$greeting,',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    // TODO: read the signed-in company's name instead
                                    // once a company profile endpoint exists.
                                    'Creatix Studio',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.title(
                                      color: Colors.white,
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _HeaderIconButton(
                              icon: Icons.person,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CompanyProfileScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SearchBar(
                          onTap: () =>
                              _comingSoon(context, 'Internship search'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 0, 110),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: _CompanyPromoBanner(),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Postings',
                                  style: AppFonts.title(
                                    fontSize: 19,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'See Top Matches For You',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CompanyPostingsScreen(),
                                ),
                              ),
                              child: const Text(
                                'View All',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        // Same right-edge margin as `_CompanyPromoBanner`'s
                        // wrapping Padding, so each posting card lines up
                        // with the banner above it instead of using an
                        // arbitrary fixed width that crops badly on
                        // narrower screens.
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth - 20;
                          return SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: placeholderCompanyPostings.length,
                              itemBuilder: (context, index) {
                                final posting =
                                    placeholderCompanyPostings[index];
                                final isLast =
                                    index ==
                                    placeholderCompanyPostings.length - 1;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: isLast ? 20 : 14,
                                  ),
                                  child: _PostingCard(
                                    posting: posting,
                                    width: cardWidth,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PostingApplicantsScreen(
                                          posting: posting,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Assessment',
                              style: AppFonts.title(
                                fontSize: 19,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _NewAssessmentCard(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CreateAssessmentScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          DraggableChatbotButton(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const MatchaChatScreen(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: 0,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Search field styled as a plain tap target rather than a real [TextField]
/// — it only ever navigates elsewhere (there's no company search screen to
/// type into yet), so a decorative caret and a suffix search button copy the
/// reference design exactly instead of fighting [InputDecoration]'s built-in
/// icon slots.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(width: 2, height: 22, color: AppColors.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Search internships...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blue call-to-action banner inviting the company to post OJT slots.
/// Same rounded-rect + gradient shape language as the student home's promo
/// banner, with its own copy and a graduation-cap/checkmark graphic in place
/// of an illustration asset.
class _CompanyPromoBanner extends StatelessWidget {
  const _CompanyPromoBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.87, -0.5),
            end: Alignment(0.87, 0.5),
            colors: [Color(0xFF2E62B8), Color(0xFF1E3799), Color(0xFF091244)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post OJT slots &\nfind your next intern.',
                      style: AppFonts.title(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect with qualified students ready to contribute to your team.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _PromoBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  const _PromoBadge();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/banner_company.png',
        width: 104,
        height: 104,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PostingCard extends StatelessWidget {
  const _PostingCard({
    required this.posting,
    required this.width,
    required this.onTap,
  });

  final CompanyPosting posting;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 30,
              child: Text(
                posting.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.title(fontSize: 17),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    posting.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PostingStatTile(
                    label: 'APPLICANTS',
                    value: posting.applicants,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PostingStatTile(
                    label: 'OPEN SLOTS',
                    value: posting.openSlots,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewAssessmentCard extends StatelessWidget {
  const _NewAssessmentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New assessment',
                    style: AppFonts.title(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add questions and assign candidates',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
