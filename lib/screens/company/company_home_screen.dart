import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../models/company_profile.dart';
import '../../services/company_service.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_sidebar.dart';
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
///
/// The greeting and the postings carousel both read the signed-in company's
/// own data from /api/company/*, the same rows the website shows.
class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  CompanyProfile? _profile;
  List<CompanyPosting> _postings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The header and carousel each degrade to a neutral state on failure, so a
  /// blip offline leaves the dashboard usable rather than blocking it behind
  /// an error page.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchProfile(),
        _service.fetchPostings(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as CompanyProfile;
        _postings = results[1] as List<CompanyPosting>;
      });
    } catch (_) {
      // Leave whatever is already on screen; pull-to-refresh can retry.
    }
  }

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
      drawer: const CompanySidebar(current: CompanySidebarItem.home),
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
                            const SizedBox(width: 10),
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
                                    _profile?.companyName ?? 'Your company',
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

                          if (_postings.isEmpty) {
                            return const SizedBox(
                              height: 180,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(0, 40, 20, 0),
                                child: Text(
                                  'No active postings yet. Create one from the '
                                  'Internship tab and it will show up here.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _postings.length,
                              itemBuilder: (context, index) {
                                final posting = _postings[index];
                                final isLast = index == _postings.length - 1;
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
