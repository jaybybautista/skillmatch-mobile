import 'package:flutter/material.dart';

import '../screens/company/assessment_library_screen.dart';
import '../screens/company/browse_candidates_screen.dart';
import '../screens/company/company_home_screen.dart';
import '../screens/company/company_postings_screen.dart';
import '../widgets/company_bottom_nav.dart';

/// Shared handler for [CompanyBottomNav] taps across company screens.
///
/// Every tab leads somewhere real. Bookmark reuses the candidates screen in
/// its bookmarks-only mode, which is the same list the sidebar's Bookmarks
/// entry opens.
void handleCompanyNavTap(BuildContext context, int index) {
  switch (index) {
    case 0:
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompanyHomeScreen()),
      );
    case 1:
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompanyPostingsScreen()),
      );
    case 2:
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AssessmentLibraryScreen()),
      );
    case 3:
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const BrowseCandidatesScreen(bookmarksOnly: true),
        ),
      );
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${companyNavItems[index].label} is coming soon.'),
        ),
      );
  }
}
