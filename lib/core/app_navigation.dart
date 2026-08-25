import 'package:flutter/material.dart';

import '../screens/student/applications/applications_screen.dart';
import '../screens/student/requirements/requirements_screen.dart';
import '../screens/student/resume/resume_list_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Shared handler for [AppBottomNav] taps across every top-level screen.
///
/// Profile is deliberately not here — it's reached from the button in the
/// Home header instead.
///
/// Each tab unwinds to the launch gate and then pushes, rather than
/// replacing the current route. That keeps exactly one screen above the
/// gate, which is what `pushReplacement` used to achieve — except that when
/// the tap came from the gate's *own* route, `pushReplacement` replaced the
/// gate itself. The session then had nothing left watching it: logging out
/// cleared the account but left the last tab on screen, and Home rendered
/// with no user at all ("Good Evening, Student", "Unauthenticated.").
void handleAppNavTap(BuildContext context, int index) {
  // Captured before popping: the context that triggered this belongs to a
  // route that is about to go away.
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (index < 0 || index >= appNavItems.length) return;

  if (index > 3) {
    messenger.showSnackBar(
      SnackBar(content: Text('${appNavItems[index].label} is coming soon.')),
    );
    return;
  }

  navigator.popUntil((route) => route.isFirst);

  switch (index) {
    // Home is the gate's own screen, so unwinding to it is the whole job.
    case 0:
      return;
    case 1:
      navigator.push(
        MaterialPageRoute(builder: (_) => const ApplicationsScreen()),
      );
    case 2:
      navigator.push(
        MaterialPageRoute(builder: (_) => const ResumeListScreen()),
      );
    case 3:
      navigator.push(
        MaterialPageRoute(builder: (_) => const RequirementsScreen()),
      );
  }
}
