import 'package:flutter/material.dart';

import '../screens/applications/applications_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/requirements/requirements_screen.dart';
import '../screens/resume/resume_list_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Shared handler for [AppBottomNav] taps across every top-level screen.
///
/// Profile is deliberately not here — it's reached from the button in the
/// Home header instead.
void handleAppNavTap(BuildContext context, int index) {
  switch (index) {
    case 0:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    case 1:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ApplicationsScreen()));
    case 2:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResumeListScreen()));
    case 3:
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RequirementsScreen()));
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appNavItems[index].label} is coming soon.')),
      );
  }
}
