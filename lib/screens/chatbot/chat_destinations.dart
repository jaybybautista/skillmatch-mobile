import 'package:flutter/material.dart';

import '../applications/applications_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../home/home_screen.dart';
import '../internship/internship_detail_screen.dart';
import '../matches/internship_search_screen.dart';
import '../matches/matches_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../placement/placement_screen.dart';
import '../profile/profile_screen.dart';
import '../resume/resume_list_screen.dart';
import '../reviews/review_replies_screen.dart';
import '../settings/settings_screen.dart';

/// Turns a platform-neutral `screen` key into actual navigation.
///
/// The keys come from the backend — ChatbotNavigationService for Matcha's
/// cards, NotificationRouter for notifications — and the web turns the same
/// capability into a URL. So both platforms point at the same place, and
/// adding a destination on the server only needs an entry here to work in the
/// app.
typedef ChatDestination = void Function(BuildContext context);

/// A destination the app genuinely doesn't have, with the reason to show
/// instead of navigating somewhere wrong.
const Map<String, String> unavailableDestinations = {
  'roadmap': 'Skill Roadmap is only on the SkillMatch website for now.',
  'requirements': 'Requirements is only on the SkillMatch website for now.',
};

ChatDestination? chatDestinationFor(String screen, [Map<String, dynamic> params = const {}]) {
  final builder = _destinations[screen];
  if (builder == null) return null;
  return (context) => builder(context, params);
}

/// Why [screen] can't be opened, or null when it can (or is simply unknown).
String? unavailableReasonFor(String screen) => unavailableDestinations[screen];

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

int? _intParam(Map<String, dynamic> params, String key) {
  final value = params[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

typedef _DestinationBuilder = void Function(BuildContext context, Map<String, dynamic> params);

final Map<String, _DestinationBuilder> _destinations = {
  'home': (context, _) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      ),
  'internship_search': (context, _) => _push(context, const InternshipSearchScreen()),
  'top_matches': (context, _) => _push(context, const MatchesListScreen()),
  'bookmarks': (context, _) => _push(context, const BookmarksScreen()),
  'applications': (context, _) => _push(context, const ApplicationsScreen()),
  'placement': (context, _) => _push(context, const PlacementScreen()),
  'resume_builder': (context, _) => _push(context, const ResumeListScreen()),
  'profile': (context, _) => _push(context, const ProfileScreen()),
  'settings': (context, _) => _push(context, const SettingsScreen()),
  'notifications': (context, _) => _push(context, const NotificationsScreen()),

  // Notification destinations that carry an id.
  'internship_detail': (context, params) {
    final id = _intParam(params, 'internship_id');
    if (id == null) return;
    _push(context, InternshipDetailScreen(internshipId: id));
  },
  'review_thread': (context, params) {
    final id = _intParam(params, 'review_id');
    if (id == null) return;
    _push(context, ReviewRepliesScreen(rootReviewId: id));
  },
};
