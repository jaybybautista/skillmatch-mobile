import 'package:flutter/material.dart';

import '../core/app_theme.dart';

const List<({IconData icon, String label})> appNavItems = [
  (icon: Icons.home_rounded, label: 'Home'),
  (icon: Icons.assignment_outlined, label: 'Applications'),
  (icon: Icons.description_outlined, label: 'Resume Builder'),
  (icon: Icons.fact_check_outlined, label: 'Requirements'),
];

/// Shared bottom navigation bar used by every top-level screen. [currentIndex]
/// highlights the active tab; [onSelect] is only called for a *different*
/// tab than the one currently shown.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onSelect});

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
              for (var i = 0; i < appNavItems.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: i == currentIndex ? null : () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          appNavItems[i].icon,
                          color: i == currentIndex ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appNavItems[i].label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == currentIndex ? AppColors.primary : AppColors.textMuted,
                            fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.normal,
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
