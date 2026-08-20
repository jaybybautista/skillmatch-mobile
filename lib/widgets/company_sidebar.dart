import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/company/assessment_library_screen.dart';
import '../screens/company/browse_candidates_screen.dart';
import '../screens/company/company_analytics_screen.dart';
import '../screens/company/company_applications_screen.dart';
import '../screens/company/company_home_screen.dart';
import '../screens/company/company_placements_screen.dart';
import '../screens/company/company_postings_screen.dart';
import '../screens/company/company_profile_screen.dart';
import '../screens/company/company_records_screen.dart';
import '../screens/company/company_settings_screen.dart';
import '../screens/student/notifications/notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

/// Which company sidebar entry the current screen is, so it can be
/// highlighted.
enum CompanySidebarItem {
  home,
  analytics,
  postings,
  applications,
  assessments,
  candidates,
  bookmarks,
  placements,
  records,
  notifications,
  profile,
  settings,
  none,
}

/// The company navigation drawer — the same entries, order, and ACCOUNT
/// grouping as the website's company sidebar, drawn in the student drawer's
/// style so both sides of the app look like one product.
///
/// Every entry the website has now leads to a real screen here too.
class CompanySidebar extends StatelessWidget {
  const CompanySidebar({super.key, this.current = CompanySidebarItem.none});

  final CompanySidebarItem current;

  /// Replaces the current screen rather than stacking another copy on top,
  /// so the drawer can't build a pile of half-visited pages behind it.
  void _go(
    BuildContext context,
    CompanySidebarItem item,
    Widget Function() build,
  ) {
    Navigator.of(context).pop();
    if (item == current) return;

    if (item == CompanySidebarItem.home) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CompanyHomeScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => build()));
  }

  /// Signs out and returns to the login screen, clearing the whole stack so
  /// Back can't walk into a company screen with no session behind it. Same
  /// confirm-then-logout flow the student side's Settings uses.
  Future<void> _confirmSignOut(BuildContext context) async {
    // The drawer deliberately stays open behind the dialog: closing it first
    // disposes this widget's context, and a disposed context can neither host
    // the dialog nor push the route afterwards. On confirm the stack is
    // replaced wholesale, which takes the drawer with it; on cancel the
    // drawer is simply still there, which is where the user was anyway.
    final navigator = Navigator.of(context, rootNavigator: true);
    final auth = context.read<AuthService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to manage your postings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await auth.logout();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 34),
                  const SizedBox(width: 10),
                  Image.asset('assets/letter-skillmatch.png', height: 20),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _CompanySidebarTile(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    isActive: current == CompanySidebarItem.home,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.home,
                      CompanyHomeScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.insert_chart_outlined,
                    label: 'Dashboard and analytics',
                    isActive: current == CompanySidebarItem.analytics,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.analytics,
                      CompanyAnalyticsScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.work_outline,
                    label: 'My postings',
                    isActive: current == CompanySidebarItem.postings,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.postings,
                      CompanyPostingsScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.description_outlined,
                    label: 'Applications',
                    isActive: current == CompanySidebarItem.applications,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.applications,
                      CompanyApplicationsScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Assessments',
                    isActive: current == CompanySidebarItem.assessments,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.assessments,
                      AssessmentLibraryScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.groups_outlined,
                    label: 'Browse candidates',
                    isActive: current == CompanySidebarItem.candidates,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.candidates,
                      BrowseCandidatesScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.bookmark_border,
                    label: 'Bookmarks',
                    isActive: current == CompanySidebarItem.bookmarks,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.bookmarks,
                      () => const BrowseCandidatesScreen(bookmarksOnly: true),
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Placements',
                    isActive: current == CompanySidebarItem.placements,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.placements,
                      CompanyPlacementsScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.archive_outlined,
                    label: 'Records and reports',
                    isActive: current == CompanySidebarItem.records,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.records,
                      CompanyRecordsScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    isActive: current == CompanySidebarItem.notifications,
                    // The count comes from the shared 15-second poll, so it
                    // moves whether the notification arrived here or on the
                    // website.
                    badge: NotificationService.instance.unreadCount,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.notifications,
                      NotificationsScreen.new,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(
                      'ACCOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.apartment_outlined,
                    label: 'Company profile',
                    isActive: current == CompanySidebarItem.profile,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.profile,
                      CompanyProfileScreen.new,
                    ),
                  ),
                  _CompanySidebarTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: current == CompanySidebarItem.settings,
                    onTap: () => _go(
                      context,
                      CompanySidebarItem.settings,
                      CompanySettingsScreen.new,
                    ),
                  ),
                  const Divider(
                    height: 20,
                    indent: 20,
                    endIndent: 20,
                    color: AppColors.border,
                  ),
                  _CompanySidebarTile(
                    icon: Icons.logout,
                    label: 'Log Out',
                    tint: AppColors.danger,
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanySidebarTile extends StatelessWidget {
  const _CompanySidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.tint,
    this.badge,
  });

  /// A live count shown as a pill on the right of the row. Listened to rather
  /// than passed as a number so the badge updates without the drawer being
  /// rebuilt by its parent.
  final ValueListenable<int>? badge;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  /// Overrides the usual colour, for an entry that needs to read differently
  /// from ordinary navigation (Log Out).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color =
        tint ?? (isActive ? AppColors.primary : AppColors.primaryDark);

    return Material(
      color: isActive ? AppColors.chipBackground : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                ValueListenableBuilder<int>(
                  valueListenable: badge!,
                  builder: (context, count, _) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
