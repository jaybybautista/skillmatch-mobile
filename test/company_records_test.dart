import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/core/company_navigation.dart';
import 'package:skillmatch/models/company_record.dart';
import 'package:skillmatch/screens/company/browse_candidates_screen.dart';
import 'package:skillmatch/screens/company/company_records_screen.dart';
import 'package:skillmatch/services/company_records_service.dart';

class _FakeRecordsService extends CompanyRecordsService {
  _FakeRecordsService({
    this.applications = const [],
    this.assessments = const [],
    this.placements = const [],
    this.error,
  });

  /// Set directly by a test that needs a different overview to the default.
  RecordsOverview? overview;
  List<ApplicationRecord> applications;
  List<AssessmentRecord> assessments;
  List<PlacementRecord> placements;
  final Object? error;

  final calls = <String>[];

  @override
  Future<RecordsOverview> fetchOverview() async {
    calls.add('overview');
    if (error != null) throw error!;
    return overview ?? RecordsOverview.fromJson(_overviewJson());
  }

  @override
  Future<List<ApplicationRecord>> fetchApplications({
    String status = '',
    int? internshipId,
    String query = '',
  }) async {
    calls.add('applications:$status:${internshipId ?? "-"}:$query');
    if (error != null) throw error!;
    return applications;
  }

  @override
  Future<List<AssessmentRecord>> fetchAssessments({
    int? internshipId,
    String query = '',
  }) async {
    calls.add('assessments:${internshipId ?? "-"}:$query');
    if (error != null) throw error!;
    return assessments;
  }

  @override
  Future<List<PlacementRecord>> fetchPlacements({
    String status = '',
    String query = '',
  }) async {
    calls.add('placements:$status:$query');
    if (error != null) throw error!;
    return placements;
  }
}

Map<String, dynamic> _overviewJson() => {
      'stats': {
        'total_applications': 5,
        'total_placements': 1,
        'total_assessments': 1,
        'total_completed': 4,
      },
      'posting_options': [
        {'id': 5, 'title': 'Laravel Developer'},
        {'id': 2, 'title': 'Product Design Intern'},
      ],
      'placement_statuses': ['ongoing', 'completed', 'terminated'],
    };

ApplicationRecord _applicationRecord({String name = 'Jaymar Bautista'}) =>
    ApplicationRecord.fromJson({
      'id': 12,
      'student_id': 21,
      'student_name': name,
      'avatar_url': null,
      'course': 'BSIT',
      'campus': 'Urdaneta City Campus',
      'internship_title': 'Laravel Developer',
      'status': 'under_review',
      'applied_at': 'Aug 14, 2026',
      'updated_at_human': '2 days ago',
    });

AssessmentRecord _assessmentRecord({bool timedOut = false, bool passed = true}) =>
    AssessmentRecord.fromJson({
      'id': 18,
      'student_id': 3,
      'student_name': 'jabyy',
      'avatar_url': null,
      'course': 'BSIT',
      'assessment_title': 'Design Intern',
      'internship_title': 'Product Design Intern',
      'score': 1,
      'total_points': 1,
      'percentage': 100,
      'passed': passed,
      'timed_out': timedOut,
      'submitted_at': 'Aug 13, 2026',
    });

PlacementRecord _placementRecord() => PlacementRecord.fromJson({
      'id': 1,
      'student_id': 2,
      'student_name': 'Jayby Bautista',
      'avatar_url': null,
      'campus': 'Urdaneta City Campus',
      'internship_title': 'Product Design Intern',
      'coordinator_name': 'Dr. Maria Santos',
      'status': 'ongoing',
      'start_date': 'Aug 08, 2026',
      'end_date': null,
    });


/// Scrolls the report list until [finder] is built.
///
/// The screen carries four counters, the tab switcher, a search box, filter
/// chips and now the bottom navigation bar, so the first record row starts
/// below the 800x600 test viewport.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('record models', () {
    test('the overview reads its counters and filter options', () {
      final overview = RecordsOverview.fromJson(_overviewJson());

      expect(overview.totalApplications, 5);
      expect(overview.totalPlacements, 1);
      expect(overview.totalAssessments, 1);
      expect(overview.totalCompleted, 4);
      expect(overview.postingOptions.first.title, 'Laravel Developer');
      expect(overview.placementStatuses, ['ongoing', 'completed', 'terminated']);
    });

    test('an empty payload parses to zeroes rather than throwing', () {
      final overview = RecordsOverview.fromJson(const {});

      expect(overview.totalApplications, 0);
      expect(overview.postingOptions, isEmpty);
      expect(overview.placementStatuses, isEmpty);
    });

    test('each record row reads its own fields', () {
      expect(_applicationRecord().campus, 'Urdaneta City Campus');
      expect(_assessmentRecord().percentage, 100);
      expect(_placementRecord().coordinatorName, 'Dr. Maria Santos');
      // An open-ended placement has no end date, and that is not an error.
      expect(_placementRecord().endDate, isNull);
    });
  });

  group('CompanyRecordsScreen', () {
    testWidgets('shows the four counters and the applications report',
        (tester) async {
      final service = _FakeRecordsService(applications: [_applicationRecord()]);

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Applications'), findsWidgets);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Attempts completed'), findsOneWidget);

      await _scrollTo(tester, find.text('Jaymar Bautista'));
      expect(find.text('Jaymar Bautista'), findsOneWidget);
      expect(find.text('BSIT · Urdaneta City Campus'), findsOneWidget);
    });

    testWidgets('switching to Assessments queries that report', (tester) async {
      final service = _FakeRecordsService(
        applications: [_applicationRecord()],
        assessments: [_assessmentRecord()],
      );

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assessments').last);
      await tester.pumpAndSettle();

      expect(service.calls, contains('assessments:-:'));

      await _scrollTo(tester, find.text('jabyy'));
      expect(find.text('jabyy'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
    });

    testWidgets('a timed-out attempt reads as timed out, not passed',
        (tester) async {
      final service = _FakeRecordsService(
        assessments: [_assessmentRecord(timedOut: true, passed: false)],
      );

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assessments').last);
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Timed out'));
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Passed'), findsNothing);
    });

    testWidgets('switching to Placements queries that report', (tester) async {
      final service = _FakeRecordsService(placements: [_placementRecord()]);

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Placements').last);
      await tester.pumpAndSettle();

      expect(service.calls, contains('placements::'));

      await _scrollTo(tester, find.text('Jayby Bautista'));
      expect(find.text('Jayby Bautista'), findsOneWidget);
      // The coordinator only appears on a placement row, so it is the
      // unambiguous signal that this report rendered — 'Ongoing' is also a
      // filter chip on this tab.
      expect(find.textContaining('Dr. Maria Santos'), findsOneWidget);
      expect(find.text('Ongoing'), findsNWidgets(2));
    });

    testWidgets('a status chip narrows the applications report', (tester) async {
      final service = _FakeRecordsService(applications: [_applicationRecord()]);

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      final chip = find.widgetWithText(ChoiceChip, 'Interview');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(service.calls, contains('applications:interview:-:'));
    });

    testWidgets('searching re-queries with the term', (tester) async {
      final service = _FakeRecordsService(applications: [_applicationRecord()]);

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(service.calls, contains('applications::-:Ana'));
    });

    testWidgets('switching tabs clears a status that the new report has not',
        (tester) async {
      final service = _FakeRecordsService(
        applications: [_applicationRecord()],
        placements: [_placementRecord()],
      );

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      final chip = find.widgetWithText(ChoiceChip, 'Interview');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Placements').last);
      await tester.pumpAndSettle();

      // 'interview' is meaningless for placements, so it is not carried over.
      expect(service.calls.last, 'placements::');
    });

    testWidgets('an empty report says so', (tester) async {
      final service = _FakeRecordsService();

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('No applications on record yet'));
      expect(find.text('No applications on record yet'), findsOneWidget);
    });

    testWidgets('a load failure is retryable', (tester) async {
      final service = _FakeRecordsService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(home: CompanyRecordsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load your records'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('company bottom navigation', () {
    testWidgets('the Bookmark tab opens the bookmarked candidates',
        (tester) async {
      // Used to fall through to a "coming soon" message.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => handleCompanyNavTap(context, 3),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BrowseCandidatesScreen), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);
    });
  });
}
