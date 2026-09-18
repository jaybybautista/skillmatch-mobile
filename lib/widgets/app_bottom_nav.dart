import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/messaging_service.dart';

const List<({IconData icon, String label})> appNavItems = [
  (icon: Icons.home_rounded, label: 'Home'),
  (icon: Icons.assignment_outlined, label: 'Applications'),
  (icon: Icons.description_outlined, label: 'Resume Builder'),
  (icon: Icons.fact_check_outlined, label: 'Requirements'),
  (icon: Icons.chat_bubble_outline, label: 'Messages'),
];

/// Shared bottom navigation bar used by every top-level screen. [currentIndex]
/// highlights the active tab; [onSelect] is only called for a *different*
/// tab than the one currently shown.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
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
              for (var i = 0; i < appNavItems.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: i == currentIndex ? null : () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NavIconWithBadge(
                          icon: appNavItems[i].icon,
                          active: i == currentIndex,
                          badge: appNavItems[i].label == 'Messages'
                              ? MessagingService.instance.unreadCount
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appNavItems[i].label,
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

/// A tab icon with an optional red count over it (the Messages badge).
class NavIconWithBadge extends StatelessWidget {
  const NavIconWithBadge({
    super.key,
    required this.icon,
    required this.active,
    this.badge,
  });

  final IconData icon;
  final bool active;
  final ValueListenable<int>? badge;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: active ? AppColors.primary : AppColors.textMuted,
    );
    final listenable = badge;
    if (listenable == null) return iconWidget;

    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          if (count > 0)
            Positioned(
              right: -8,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
