import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../company/assessment_library_screen.dart';
import '../company/browse_candidates_screen.dart';
import '../company/company_analytics_screen.dart';
import '../company/company_applications_screen.dart';
import '../company/company_home_screen.dart';
import '../company/company_placements_screen.dart';
import '../company/company_postings_screen.dart';
import '../company/company_profile_screen.dart';
import '../company/company_records_screen.dart';
import '../company/company_settings_screen.dart';
import '../company/create_post_screen.dart';
import '../student/applications/applications_screen.dart';
import '../student/bookmarks/bookmarks_screen.dart';
import '../student/home/home_screen.dart';
import '../student/internship/internship_detail_screen.dart';
import '../student/matches/internship_search_screen.dart';
import '../student/matches/matches_list_screen.dart';
import '../student/notifications/notifications_screen.dart';
import '../student/placement/placement_screen.dart';
import '../student/profile/company_public_profile_screen.dart';
import '../student/profile/coordinator_public_profile_screen.dart';
import '../student/profile/profile_screen.dart';
import '../student/profile/student_public_profile_screen.dart';
import '../student/requirements/requirements_screen.dart';
import '../student/resume/resume_list_screen.dart';
import '../student/reviews/review_replies_screen.dart';
import '../student/roadmap/skill_roadmap_screen.dart';
import '../student/settings/settings_screen.dart';

/// Turns a platform-neutral `screen` key into actual navigation.
///
/// The keys come from the backend — ChatbotNavigationService for Matcha's
/// cards, NotificationRouter for notifications — and the web turns the same
/// capability into a URL. So both platforms point at the same place, and
/// adding a destination on the server only needs an entry here to work in the
/// app.
typedef ChatDestination = void Function(BuildContext context);

/// A destination the app genuinely doesn't have, with the reason to show
/// instead of navigating somewhere wrong. Empty for now — every screen the
/// web has, the app has too.
const Map<String, String> unavailableDestinations = {};

ChatDestination? chatDestinationFor(
  String screen, [
  Map<String, dynamic> params = const {},
]) {
  final builder = _destinations[screen];
  if (builder == null) return null;
  return (context) => builder(context, params);
}

/// Why [screen] can't be opened, or null when it can (or is simply unknown).
String? unavailableReasonFor(String screen) => unavailableDestinations[screen];

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// True when the signed-in account is a company.
///
/// A handful of destination ids mean different screens depending on who is
/// asking - the backend hands back one 'home' / 'profile' / 'settings' id for
/// both roles, because on the web those are one route each. Falls back to the
/// student side when there is no session to read (a widget test, say).
bool _isCompany(BuildContext context) {
  try {
    return context.read<AuthService>().currentUser?.role == 'company';
  } catch (_) {
    return false;
  }
}

void _replaceAll(BuildContext context, Widget screen) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => screen),
    (route) => false,
  );
}

int? _intParam(Map<String, dynamic> params, String key) {
  final value = params[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

typedef _DestinationBuilder =
    void Function(BuildContext context, Map<String, dynamic> params);

final Map<String, _DestinationBuilder> _destinations = {
  'home': (context, _) => _replaceAll(
    context,
    _isCompany(context) ? const CompanyHomeScreen() : const HomeScreen(),
  ),
  'internship_search': (context, _) =>
      _push(context, const InternshipSearchScreen()),
  'top_matches': (context, _) => _push(context, const MatchesListScreen()),
  'bookmarks': (context, _) => _push(context, const BookmarksScreen()),
  'applications': (context, _) => _push(context, const ApplicationsScreen()),
  'placement': (context, _) => _push(context, const PlacementScreen()),
  'resume_builder': (context, _) => _push(context, const ResumeListScreen()),
  'requirements': (context, _) => _push(context, const RequirementsScreen()),
  'roadmap': (context, _) => _push(context, const SkillRoadmapScreen()),
  'profile': (context, _) => _push(
    context,
    _isCompany(context) ? const CompanyProfileScreen() : const ProfileScreen(),
  ),
  'settings': (context, _) => _push(
    context,
    _isCompany(context)
        ? const CompanySettingsScreen()
        : const SettingsScreen(),
  ),
  'notifications': (context, _) => _push(context, const NotificationsScreen()),

  // The company side. Every id here comes from ChatbotNavigationService's
  // `company` capability list, so Matcha can take a company to the same
  // screens on the phone that its cards link to on the website.
  'company_internships': (context, _) =>
      _push(context, const CompanyPostingsScreen()),
  'company_internship_create': (context, _) =>
      _push(context, const CreatePostScreen()),
  'company_applications': (context, _) =>
      _push(context, const CompanyApplicationsScreen()),
  'company_candidates': (context, _) =>
      _push(context, const BrowseCandidatesScreen()),
  'company_bookmarks': (context, _) =>
      _push(context, const BrowseCandidatesScreen(bookmarksOnly: true)),
  'company_assessments': (context, _) =>
      _push(context, const AssessmentLibraryScreen()),
  'company_placements': (context, _) =>
      _push(context, const CompanyPlacementsScreen()),
  'company_records': (context, _) =>
      _push(context, const CompanyRecordsScreen()),
  'company_analytics': (context, _) =>
      _push(context, const CompanyAnalyticsScreen()),
  // The signed-in company's own profile, as opposed to 'company_profile'
  // below, which opens some other company's public one by id.
  'company_my_profile': (context, _) =>
      _push(context, const CompanyProfileScreen()),

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

  // Public profiles — reached from people search and from tapping a
  // reviewer's name or avatar. All three carry the subject's own row id
  // (student_id / company_id / coordinator_id), resolved server-side by
  // ProfileLinkService so search and reviews can never disagree on where an
  // account lives.
  'student_profile': (context, params) {
    final id = _intParam(params, 'student_id');
    if (id == null) return;
    _push(context, StudentPublicProfileScreen(studentId: id));
  },
  'company_profile': (context, params) {
    final id = _intParam(params, 'company_id');
    if (id == null) return;
    _push(context, CompanyPublicProfileScreen(companyId: id));
  },
  'coordinator_profile': (context, params) {
    final id = _intParam(params, 'coordinator_id');
    if (id == null) return;
    _push(context, CoordinatorPublicProfileScreen(coordinatorId: id));
  },
};
