import 'package:flutter/material.dart';

import '../screens/company/assessment_library_screen.dart';
import '../screens/company/browse_candidates_screen.dart';
import '../screens/company/company_postings_screen.dart';
import '../widgets/company_bottom_nav.dart';

/// Shared handler for [CompanyBottomNav] taps across company screens.
///
/// Every tab leads somewhere real. Bookmark reuses the candidates screen in
/// its bookmarks-only mode, which is the same list the sidebar's Bookmarks
/// entry opens.
///
/// Like the student side, each tab unwinds to the launch gate and then
/// pushes. `pushReplacement` looked equivalent but replaced the gate itself
/// whenever the tap came from the gate's own route, which left logging out
/// with nothing watching the session.
void handleCompanyNavTap(BuildContext context, int index) {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (index < 0 || index >= companyNavItems.length) return;

  if (index > 3) {
    messenger.showSnackBar(
      SnackBar(content: Text('${companyNavItems[index].label} is coming soon.')),
    );
    return;
  }

  navigator.popUntil((route) => route.isFirst);

  switch (index) {
    // The gate is already showing the company's home underneath.
    case 0:
      return;
    case 1:
      navigator.push(
        MaterialPageRoute(builder: (_) => const CompanyPostingsScreen()),
      );
    case 2:
      navigator.push(
        MaterialPageRoute(builder: (_) => const AssessmentLibraryScreen()),
      );
    case 3:
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const BrowseCandidatesScreen(bookmarksOnly: true),
        ),
      );
  }
}
