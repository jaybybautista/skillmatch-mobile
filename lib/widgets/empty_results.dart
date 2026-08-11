import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The shared "nothing matched" state: a soft circular badge with a
/// search-off glyph, a bold title, and a muted hint underneath.
///
/// Used wherever a search comes back empty so the app says "no results" the
/// same way everywhere, rather than each screen inventing its own wording.
class EmptyResults extends StatelessWidget {
  const EmptyResults({
    super.key,
    required this.title,
    required this.hint,
    this.icon = Icons.search_off,
    this.padding = const EdgeInsets.symmetric(vertical: 56),
  });

  final String title;
  final String hint;
  final IconData icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // The width is forced to the full available space. Without it the column
    // shrink-wraps wherever the parent passes loose constraints (a Scaffold
    // body, a plain Column) and the whole block drifts to the left edge —
    // centring only looked right inside a ListView, which stretches its
    // children for free.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFEAF1FD), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
