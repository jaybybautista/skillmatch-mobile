import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The flat navy header shared by every top-level company screen ("My
/// Postings", "Assessment Library", "Create Post", "Create Assessment") — a
/// fixed-height gradient bar with the title, an optional leading back
/// button, and an optional trailing action, all anchored to its bottom edge.
///
/// Pulled out as a shared widget so screens can't drift out of sync with
/// each other again (they previously each duplicated this markup and ended
/// up with different heights, title sizes, and even solid-vs-gradient
/// backgrounds).
class CompanyScreenHeader extends StatelessWidget {
  const CompanyScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showMenuButton = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Shows the hamburger that opens [CompanySidebar]. Only the top-level
  /// screens set this — a pushed screen keeps its back arrow instead, the
  /// same rule the student side follows.
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.companyHeader),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              (onBack == null && !showMenuButton) ? 24 : 12,
              0,
              trailing == null ? 24 : 12,
              12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showMenuButton) ...[
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
                      const SizedBox(width: 8),
                    ],
                    if (onBack != null) ...[
                      InkWell(
                        onTap: onBack,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.6),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.title(
                              fontSize: subtitle == null ? 22 : 19,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
