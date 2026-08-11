import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_navigation.dart';
import '../../core/app_theme.dart';
import '../../models/internship.dart';
import '../../services/auth_service.dart';
import '../../services/internship_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/draggable_chatbot_button.dart';
import '../../widgets/match_card.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../chatbot/matcha_chat_screen.dart';
import '../matches/internship_search_screen.dart';
import '../matches/matches_list_screen.dart';
import '../profile/profile_screen.dart';

/// Home screen — "Top Matches For You" pulls real internship postings and
/// real AI match scores from Api\InternshipController::recommendations().
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _internshipService = InternshipService();
  late Future<List<Internship>> _recommendationsFuture = _internshipService.fetchRecommendations(limit: 5);

  Future<void> _refresh() async {
    final future = _internshipService.fetchRecommendations(limit: 5);
    setState(() => _recommendationsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
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
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                Text(
                                  user?.name ?? 'Student',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderIconButton(
                            icon: Icons.bookmark,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HeaderIconButton(
                            icon: Icons.person,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        readOnly: true,
                        // Tapping opens a dedicated search screen rather than
                        // typing into the dashboard.
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InternshipSearchScreen()),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search internships...',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
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
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                      children: [
                        const _PromoBanner(),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Top Matches For You',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MatchesListScreen()),
                              ),
                              child: const Text('View All', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Internship>>(
                          future: _recommendationsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            if (snapshot.hasError || !snapshot.hasData) {
                              final message = snapshot.error is ApiException
                                  ? (snapshot.error as ApiException).message
                                  : 'Could not load internship matches.';
                              return _InlineMessage(text: message, onRetry: _refresh);
                            }

                            final items = snapshot.data!;
                            if (items.isEmpty) {
                              return const _InlineMessage(text: 'No internship postings yet. Check back soon!');
                            }

                            return Column(
                              children: [
                                for (final internship in items) ...[
                                  MatchCard(internship: internship),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
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
      bottomNavigationBar: AppBottomNav(currentIndex: 0, onSelect: (i) => handleAppNavTap(context, i)),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
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
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Mirrors the web dashboard's `.hero-banner` (student/dashboard.blade.php):
/// same 16px radius, the same three-stop 120deg gradient, and the same 36px
/// grid overlay drawn in white at 7% opacity. Text sizes are scaled down for
/// phone widths; everything else is the web's values.
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_bannerRadius),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          // CSS `linear-gradient(120deg, ...)`: 120° clockwise from "to top"
          // gives a direction vector of (sin120, cos60) — right and downward.
          gradient: LinearGradient(
            begin: Alignment(-0.87, -0.5),
            end: Alignment(0.87, 0.5),
            colors: [Color(0xFF1E3799), Color(0xFF0D1A5E), Color(0xFF091244)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: const _BannerGridPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start your OJT journey\nthe right way!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Find the right internship for your career',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset('assets/banner-picture.png', height: 96, fit: BoxFit.contain),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const double _bannerRadius = 16;

/// The web's `.hero-banner::before` overlay: 1px white lines at 7% opacity on
/// a 36x36 grid.
class _BannerGridPainter extends CustomPainter {
  const _BannerGridPainter();

  /// `background-size: 36px 36px` in the web stylesheet.
  static const _cell = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BannerGridPainter oldDelegate) => false;
}
