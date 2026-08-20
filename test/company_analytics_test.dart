import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/company_analytics.dart';
import 'package:skillmatch/models/company_placement.dart';
import 'package:skillmatch/models/review.dart';
import 'package:skillmatch/screens/company/company_analytics_screen.dart';
import 'package:skillmatch/screens/company/company_placements_screen.dart';
import 'package:skillmatch/screens/company/placement_detail_screen.dart';
import 'package:skillmatch/services/company_service.dart';

/// A stand-in for the real service, so the screens can be driven without a
/// backend. Records what it was asked for, which is how the filter tests
/// assert that a chip or dropdown actually re-queried.
class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({
    this.analytics,
    this.placements = const [],
    this.counts = PlacementCounts.empty,
    this.detail,
    this.error,
    this.filteredAnalytics = false,
    this.delay = Duration.zero,
    this.failAfterFirst,
  });

  CompanyAnalytics? analytics;
  List<CompanyPlacement> placements;
  PlacementCounts counts;
  CompanyPlacementDetail? detail;
  final Object? error;

  /// Answers with a narrowed pipeline when a posting filter is passed, so a
  /// test can tell whether the screen re-rendered the filtered numbers.
  final bool filteredAnalytics;

  final Duration delay;

  /// Thrown by every call after the first — mimics the filter request failing
  /// once the user starts changing the dropdown.
  final Object? failAfterFirst;

  final calls = <String>[];

  @override
  Future<CompanyAnalytics> fetchAnalytics({int? internshipId}) async {
    calls.add('analytics:${internshipId ?? "all"}');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    if (failAfterFirst != null && calls.length > 1) throw failAfterFirst!;
    if (filteredAnalytics) {
      return CompanyAnalytics.fromJson(_analyticsJson(narrowed: internshipId != null));
    }
    return analytics ?? CompanyAnalytics.fromJson(const {});
  }

  @override
  Future<({List<CompanyPlacement> placements, PlacementCounts counts})> fetchPlacements({
    String status = '',
    String query = '',
  }) async {
    calls.add('placements:$status:$query');
    if (error != null) throw error!;
    return (placements: placements, counts: counts);
  }

  @override
  Future<CompanyPlacementDetail> fetchPlacement(int id) async {
    calls.add('placement:$id');
    if (error != null) throw error!;
    return detail!;
  }
}

Map<String, dynamic> _analyticsJson({
  int pipelineTotal = 5,
  int? filter,
  bool narrowed = false,
}) =>
    {
      'postings': {'total': 2, 'open': 2, 'closed': 0, 'open_slots': 14, 'slots_filled': 1},
      'applicants': {
        'total': 5,
        'pending': 0,
        'under_review': 1,
        'interview': 3,
        'accepted': 1,
        'rejected': 0,
      },
      'matching': {'average_score': 63, 'high_match_count': 2},
      'assessments': {'total': 1, 'quizzes_taken': 4, 'average_score': 71},
      'placements': {'total': 1, 'active': 1},
      'pipeline': {
        'total': narrowed ? 3 : pipelineTotal,
        'stages': [
          {'status': 'pending', 'label': 'Pending', 'count': 0, 'percentage': 0},
          {
            'status': 'under_review',
            'label': 'Under review',
            'count': 1,
            'percentage': narrowed ? 33 : 20,
          },
          {
            'status': 'interview',
            'label': 'Interview',
            'count': narrowed ? 2 : 3,
            'percentage': narrowed ? 67 : 60,
          },
          {
            'status': 'accepted',
            'label': 'Accepted',
            'count': narrowed ? 0 : 1,
            'percentage': 20,
          },
          {'status': 'rejected', 'label': 'Rejected', 'count': 0, 'percentage': 0},
        ],
      },
      'pipeline_filter': filter,
      'posting_options': [
        {'id': 5, 'title': 'Laravel Developer'},
        {'id': 2, 'title': 'Product Design Intern'},
      ],
      'assessment_rows': [
        {'id': 1, 'title': 'Design Intern', 'questions_count': 3},
      ],
      'recent_activity': [
        {
          'id': 12,
          'student_name': 'Jaymar Bautista',
          'internship_title': 'Laravel Developer',
          'status': 'under_review',
          'assigned_assessment': null,
          'updated_at_human': '28 minutes ago',
        },
      ],
    };

Map<String, dynamic> _placementJson({
  int id = 1,
  String status = 'ongoing',
  String name = 'Jayby Bautista',
}) =>
    {
      'id': id,
      'status': status,
      'status_label': status[0].toUpperCase() + status.substring(1),
      'student_id': 2,
      'student_name': name,
      'student_email': 'jayby@example.test',
      'student_avatar_url': null,
      'student_number': '23-UR-0629',
      'internship_title': 'Product Design Intern',
      'start_date': '2026-08-08',
      'end_date': null,
      'created_at_human': '1 week ago',
      'updated_at_human': '3 days ago',
    };

/// Scrolls the screen's list until [finder] is built.
///
/// The test viewport is 800x600, and both of these screens are long scrolling
/// pages — everything below the first couple of cards starts off-screen and
/// simply is not in the tree until it is scrolled to.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 220, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
}

/// Opens the pipeline's posting dropdown and picks [label].
Future<void> _pick(WidgetTester tester, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<int?>);
  await _scrollTo(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('CompanyAnalytics parsing', () {
    test('reads every section of the analytics payload', () {
      final data = CompanyAnalytics.fromJson(_analyticsJson());

      expect(data.totalPostings, 2);
      expect(data.openSlots, 14);
      expect(data.slotsFilled, 1);
      expect(data.totalApplicants, 5);
      expect(data.pendingApps, 0);
      expect(data.applicantCounts['interview'], 3);
      expect(data.avgMatchScore, 63);
      expect(data.highMatchCount, 2);
      expect(data.quizzesTaken, 4);
      expect(data.avgQuizScore, 71);
      expect(data.activePlacements, 1);
      expect(data.pipelineStages, hasLength(5));
      expect(data.pipelineStages[2].label, 'Interview');
      expect(data.pipelineStages[2].percentage, 60);
      expect(data.postingOptions.first.title, 'Laravel Developer');
      expect(data.assessmentRows.single.questionsCount, 3);
      expect(data.recentActivity.single.studentName, 'Jaymar Bautista');
    });

    test('an empty payload parses to zeroes rather than throwing', () {
      final data = CompanyAnalytics.fromJson(const {});

      expect(data.totalApplicants, 0);
      expect(data.pipelineStages, isEmpty);
      expect(data.postingOptions, isEmpty);
    });

    test('CompanyDashboard reads the greeting, stats and recent lists', () {
      final dashboard = CompanyDashboard.fromJson(const {
        'greeting': 'Good Afternoon',
        'stats': {'total_applicants': 5, 'active_placements': 1},
        'recent_postings': [
          {
            'id': 5,
            'title': 'Laravel Developer',
            'status': 'open',
            'slots_available': 10,
            'applications_count': 3,
            'created_at_human': '1 week ago',
          },
        ],
        'recent_applications': [
          {'id': 12, 'status': 'under_review', 'student_name': 'Jaymar'},
        ],
        'top_candidates': [
          {'student_id': 3, 'student_name': 'Ana', 'match_score': 88},
        ],
      });

      expect(dashboard.greeting, 'Good Afternoon');
      expect(dashboard.stats.totalApplicants, 5);
      expect(dashboard.stats.activePlacements, 1);
      expect(dashboard.recentPostings.single.isOpen, isTrue);
      expect(dashboard.recentApplications.single.studentName, 'Jaymar');
      expect(dashboard.topCandidates.single.matchScore, 88);
    });
  });

  group('CompanyAnalyticsScreen', () {
    testWidgets('renders the headline metrics and the pipeline', (tester) async {
      final service = _FakeCompanyService(
        analytics: CompanyAnalytics.fromJson(_analyticsJson()),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total applications'), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('2 high-match candidates'), findsOneWidget);
      expect(find.text('Avg quiz score: 71%'), findsOneWidget);

      await _scrollTo(tester, find.text('Applicant pipeline breakdown'));
      expect(find.text('Applicant pipeline breakdown'), findsOneWidget);
      expect(find.text('Interview'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('choosing a posting re-renders the pipeline with its numbers',
        (tester) async {
      final service = _FakeCompanyService(filteredAnalytics: true);

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byType(DropdownButtonFormField<int?>));
      expect(find.text('60%'), findsOneWidget, reason: 'unfiltered interview share');

      await _pick(tester, 'Laravel Developer');

      expect(service.calls, ['analytics:all', 'analytics:5']);
      await _scrollTo(tester, find.text('Interview'));
      expect(find.text('67%'), findsOneWidget, reason: 'narrowed share is on screen');
      expect(find.text('60%'), findsNothing, reason: 'the old share is gone');
    });

    testWidgets('switching back to All postings restores the full numbers',
        (tester) async {
      final service = _FakeCompanyService(filteredAnalytics: true);

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _pick(tester, 'Laravel Developer');
      await _pick(tester, 'All postings');

      expect(service.calls, ['analytics:all', 'analytics:5', 'analytics:all']);
      await _scrollTo(tester, find.text('Interview'));
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('the chosen posting survives scrolling the panel out of view',
        (tester) async {
      final service = _FakeCompanyService(filteredAnalytics: true);

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _pick(tester, 'Laravel Developer');

      await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byType(DropdownButtonFormField<int?>));

      expect(find.text('Laravel Developer'), findsOneWidget);
    });

    testWidgets('a failed filter says so instead of silently doing nothing',
        (tester) async {
      // A bare error rather than an ApiException — which is what a timeout or
      // a decode failure surfaces as. These used to escape uncaught, leaving
      // the screen unchanged and the user with no idea anything had happened.
      final service = _FakeCompanyService(
        filteredAnalytics: true,
        failAfterFirst: Exception('boom'),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _pick(tester, 'Laravel Developer');

      expect(find.textContaining('Could not filter the pipeline'), findsOneWidget);
    });

    testWidgets('a slow filter shows the panel is working', (tester) async {
      final service = _FakeCompanyService(
        filteredAnalytics: true,
        delay: const Duration(milliseconds: 600),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<int?>);
      await _scrollTo(tester, dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laravel Developer').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final service = _FakeCompanyService(error: Exception('offline'));

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load your analytics.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('empty analytics still render, with empty-state copy', (tester) async {
      final service = _FakeCompanyService(
        analytics: CompanyAnalytics.fromJson(_analyticsJson(pipelineTotal: 0)),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyAnalyticsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('No applications to break down yet.'));
      expect(find.text('No applications to break down yet.'), findsOneWidget);
    });
  });

  group('CompanyPlacementsScreen', () {
    testWidgets('lists placements with their status and counts', (tester) async {
      final service = _FakeCompanyService(
        placements: [
          CompanyPlacement.fromJson(_placementJson()),
          CompanyPlacement.fromJson(
            _placementJson(id: 2, status: 'completed', name: 'Ana Cruz'),
          ),
        ],
        counts: const PlacementCounts(
          total: 2,
          ongoing: 1,
          completed: 1,
          terminated: 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyPlacementsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jayby Bautista'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);
    });

    testWidgets('a status chip re-queries with that status', (tester) async {
      final service = _FakeCompanyService(
        placements: [CompanyPlacement.fromJson(_placementJson())],
        counts: const PlacementCounts(total: 1, ongoing: 1, completed: 0, terminated: 0),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyPlacementsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      // The chip row scrolls horizontally, so it has to be brought into the
      // hit-testable area before tapping it.
      final chip = find.widgetWithText(ChoiceChip, 'Completed (0)');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(service.calls, ['placements::', 'placements:completed:']);
    });

    testWidgets('the empty state explains that coordinators create placements',
        (tester) async {
      final service = _FakeCompanyService();

      await tester.pumpWidget(
        MaterialApp(home: CompanyPlacementsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No placements found'), findsOneWidget);
      expect(
        find.textContaining('once a coordinator creates their placement record'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a placement opens its detail screen', (tester) async {
      final service = _FakeCompanyService(
        placements: [CompanyPlacement.fromJson(_placementJson())],
        counts: const PlacementCounts(total: 1, ongoing: 1, completed: 0, terminated: 0),
        detail: CompanyPlacementDetail.fromJson({
          ..._placementJson(),
          'course': 'BSIT',
          'year_level': 4,
          'campus': 'Urdaneta City Campus',
          'student_skills': ['Flutter', 'Laravel'],
          'internship': {
            'id': 2,
            'title': 'Product Design Intern',
            'location': 'Urdaneta',
            'skills': ['Figma'],
            'responsibilities': ['Design screens'],
          },
          'coordinator_name': 'Dr. Maria Santos',
          'coordinator_email': 'coordinator@example.test',
          'hours_rendered': 250,
          'required_hours': 500,
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CompanyPlacementsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jayby Bautista'));
      await tester.pumpAndSettle();

      expect(find.byType(PlacementDetailScreen), findsOneWidget);
      expect(find.text('BSIT'), findsOneWidget);

      // Hours rendered is deliberately not shown on this screen.
      expect(find.textContaining('hours'), findsNothing);
      expect(find.text('Hours rendered'), findsNothing);

      await _scrollTo(tester, find.text('Dr. Maria Santos'));
      expect(find.text('Dr. Maria Santos'), findsOneWidget);
    });
  });

  group('Review reviewable context', () {
    test('carries the "On internship" badge through from the API', () {
      final review = Review.fromJson(const {
        'id': 8,
        'content': 'Good exposure to real product work.',
        'rating': 5,
        'reviewable_context': 'On internship: Laravel Developer',
      });

      expect(review.reviewableContext, 'On internship: Laravel Developer');
    });

    test('is null for feedback left on the company itself', () {
      final review = Review.fromJson(const {'id': 1, 'content': 'Great team.'});

      expect(review.reviewableContext, isNull);
    });
  });

  group('placementStatusColors', () {
    test('gives each of the three statuses its own pair', () {
      expect(
        placementStatusColors('completed').text,
        isNot(placementStatusColors('terminated').text),
      );
      expect(
        placementStatusColors('ongoing').text,
        isNot(placementStatusColors('completed').text),
      );
      // An unrecognised status falls back to the ongoing pair rather than
      // rendering an invisible pill.
      expect(
        placementStatusColors('something_else').text,
        placementStatusColors('ongoing').text,
      );
    });
  });
}
