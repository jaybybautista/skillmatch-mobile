import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/applications/applications_screen.dart';
import '../screens/bookmarks/bookmarks_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/matches/internship_search_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/requirements/requirements_screen.dart';
import '../screens/resume/resume_list_screen.dart';
import '../screens/roadmap/skill_roadmap_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../services/notification_service.dart';

/// Which sidebar entry the current screen is, so it can be highlighted.
enum SidebarItem { home, notifications, applications, bookmarks, profile, resumeBuilder, roadmap, requirements, settings, none }

/// The navigation drawer, mirroring the web sidebar: the same entries in the
/// same order, the same ACCOUNT grouping, and the same destinations.
class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key, this.current = SidebarItem.none});

  final SidebarItem current;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _notifications = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notifications.startPolling();
  }

  @override
  void dispose() {
    _notifications.stopPolling();
    super.dispose();
  }

  /// Replaces the current screen rather than stacking another copy on top,
  /// so the drawer can't build a pile of half-visited pages behind it.
  void _go(SidebarItem item, Widget Function() build) {
    Navigator.of(context).pop();
    if (item == widget.current) return;

    if (item == SidebarItem.home) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => build()));
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InternshipSearchScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 19, color: AppColors.textMuted),
                      SizedBox(width: 10),
                      Text('Search', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _SidebarTile(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    isActive: widget.current == SidebarItem.home,
                    onTap: () => _go(SidebarItem.home, HomeScreen.new),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _notifications.unreadCount,
                    builder: (context, unread, _) => _SidebarTile(
                      icon: Icons.notifications_none,
                      label: 'Notifications',
                      badge: unread,
                      isActive: widget.current == SidebarItem.notifications,
                      onTap: () => _go(SidebarItem.notifications, NotificationsScreen.new),
                    ),
                  ),
                  _SidebarTile(
                    icon: Icons.description_outlined,
                    label: 'Applications',
                    isActive: widget.current == SidebarItem.applications,
                    onTap: () => _go(SidebarItem.applications, ApplicationsScreen.new),
                  ),
                  _SidebarTile(
                    icon: Icons.bookmark_border,
                    label: 'Bookmarks',
                    isActive: widget.current == SidebarItem.bookmarks,
                    onTap: () => _go(SidebarItem.bookmarks, BookmarksScreen.new),
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
                  _SidebarTile(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isActive: widget.current == SidebarItem.profile,
                    onTap: () => _go(SidebarItem.profile, ProfileScreen.new),
                  ),
                  _SidebarTile(
                    icon: Icons.article_outlined,
                    label: 'Resume Builder',
                    isActive: widget.current == SidebarItem.resumeBuilder,
                    onTap: () => _go(SidebarItem.resumeBuilder, ResumeListScreen.new),
                  ),
                  _SidebarTile(
                    icon: Icons.bolt_outlined,
                    label: 'Skill Roadmap',
                    isActive: widget.current == SidebarItem.roadmap,
                    onTap: () => _go(SidebarItem.roadmap, SkillRoadmapScreen.new),
                  ),
                  _SidebarTile(
                    icon: Icons.apartment_outlined,
                    label: 'Requirements',
                    isActive: widget.current == SidebarItem.requirements,
                    onTap: () => _go(SidebarItem.requirements, RequirementsScreen.new),
                  ),
                  _SidebarTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: widget.current == SidebarItem.settings,
                    onTap: () => _go(SidebarItem.settings, SettingsScreen.new),
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

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.primaryDark;

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
                  style: TextStyle(
                    fontSize: 15.5,
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
