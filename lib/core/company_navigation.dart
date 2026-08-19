import 'package:flutter/material.dart';

import '../screens/company/assessment_library_screen.dart';
import '../screens/company/company_home_screen.dart';
import '../screens/company/company_postings_screen.dart';
import '../widgets/company_bottom_nav.dart';

/// Shared handler for [CompanyBottomNav] taps across company screens.
///
/// Home, Internship, and Assessment are built so far — Bookmark has no
/// screen yet, so it surfaces a "coming soon" message like the student side
/// does for its own unbuilt tabs (see `handleAppNavTap`).
void handleCompanyNavTap(BuildContext context, int index) {
  switch (index) {
    case 0:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CompanyHomeScreen()));
    case 1:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CompanyPostingsScreen()));
    case 2:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AssessmentLibraryScreen()));
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${companyNavItems[index].label} is coming soon.')),
      );
  }
}
