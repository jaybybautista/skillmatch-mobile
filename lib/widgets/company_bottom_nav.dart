import 'package:flutter/material.dart';

import '../core/app_theme.dart';

const List<({IconData icon, String label})> companyNavItems = [
  (icon: Icons.home_rounded, label: 'Home'),
  (icon: Icons.work_outline_rounded, label: 'Internship'),
  (icon: Icons.description_outlined, label: 'Assessment'),
  (icon: Icons.bookmark_border_rounded, label: 'Bookmark'),
];

/// Bottom navigation bar for the company side of the app. Same visual shape
/// as [AppBottomNav] (student side), but with the company's own tab set —
/// the two never share a bar because a signed-in account is one role or the
/// other, never both.
class CompanyBottomNav extends StatelessWidget {
  const CompanyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < companyNavItems.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: i == currentIndex ? null : () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          companyNavItems[i].icon,
                          color: i == currentIndex
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          companyNavItems[i].label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == currentIndex
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
