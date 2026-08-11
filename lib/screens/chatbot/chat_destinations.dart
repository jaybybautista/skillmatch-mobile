import 'package:flutter/material.dart';

import '../applications/applications_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../home/home_screen.dart';
import '../matches/internship_search_screen.dart';
import '../matches/matches_list_screen.dart';
import '../placement/placement_screen.dart';
import '../profile/profile_screen.dart';
import '../resume/resume_list_screen.dart';
import '../settings/settings_screen.dart';

/// Turns a chatbot card's `screen` key into actual navigation.
///
/// The keys come from ChatbotNavigationService, which the web uses to build
/// URLs — so Matcha points at the same place on both platforms, and adding a
/// capability on the server only needs an entry here to work in the app.
///
/// Returns null for destinations the app doesn't have yet (the roadmap,
/// notifications, requirements, and every company screen), letting the caller
/// say so honestly rather than navigating somewhere wrong.
typedef ChatDestination = void Function(BuildContext context);

ChatDestination? chatDestinationFor(String screen) => _destinations[screen];

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

final Map<String, ChatDestination> _destinations = {
  'home': (context) => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      ),
  'internship_search': (context) => _push(context, const InternshipSearchScreen()),
  'top_matches': (context) => _push(context, const MatchesListScreen()),
  'bookmarks': (context) => _push(context, const BookmarksScreen()),
  'applications': (context) => _push(context, const ApplicationsScreen()),
  'placement': (context) => _push(context, const PlacementScreen()),
  'resume_builder': (context) => _push(context, const ResumeListScreen()),
  'profile': (context) => _push(context, const ProfileScreen()),
  'settings': (context) => _push(context, const SettingsScreen()),
};
