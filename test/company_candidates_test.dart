import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/company_application.dart';
import 'package:skillmatch/screens/company/browse_candidates_screen.dart';
import 'package:skillmatch/screens/company/company_applications_screen.dart';
import 'package:skillmatch/services/company_service.dart';

class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({
    this.candidates = const [],
    this.bookmarked = const [],
    this.applications = const [],
    this.counts = const {},
    this.error,
  });

  List<Candidate> candidates;
  List<Candidate> bookmarked;
  List<CompanyApplication> applications;
  Map<String, dynamic> counts;
  final Object? error;

  final calls = <String>[];
  bool nextBookmarkResult = true;

  @override
  Future<List<Candidate>> fetchCandidates({
    String query = '',
    String sort = 'match_score',
    int? minScore,
  }) async {
    calls.add('fetchCandidates:$sort:$query');
    if (error != null) throw error!;
    return candidates;
  }

  @override
  Future<List<Candidate>> fetchBookmarkedCandidates() async {
    calls.add('fetchBookmarks');
    if (error != null) throw error!;
    return bookmarked;
  }

  @override
  Future<bool> toggleCandidateBookmark(int studentId) async {
    calls.add('bookmark:$studentId');
    return nextBookmarkResult;
  }

  @override
  Future<({List<CompanyApplication> applications, ApplicationCounts counts})>
      fetchApplications({String status = '', String query = ''}) async {
    calls.add('fetchApplications:$status:$query');
    if (error != null) throw error!;
    return (applications: applications, counts: ApplicationCounts.fromJson(counts));
  }

  @override
  Future<CompanyApplication> updateApplicationStatus({
    required int id,
    required String status,
    String? rejectionReason,
  }) async {
    calls.add('status:$id:$status:${rejectionReason ?? "-"}');
    return _application(id: id, status: status);
  }

  @override
  Future<CompanyApplication> undoApplicationStatus(int id) async {
    calls.add('undo:$id');
    return _application(id: id, status: 'under_review');
  }
}

Candidate _candidate({
  int id = 1,
  String name = 'Ana Cruz',
  int matchScore = 82,
  bool bookmarked = false,
  int? assessment,
}) {
  return Candidate.fromJson({
    'id': id,
    'name': name,
    'email': 'ana@psu.test',
    'course': 'BSIT',
    'year_level': 4,
    'campus': 'Urdaneta City Campus',
    'initials': 'A',
    'skills': ['Laravel', 'Flutter'],
    'matched_skills': ['Laravel'],
    'match_score': matchScore,
    'assessment_score': assessment,
    'is_bookmarked': bookmarked,
    'is_on_ojt': false,
  });
}

CompanyApplication _application({
  int id = 1,
  String status = 'pending',
  String student = 'Ana Cruz',
  bool canUndo = false,
  String? rejectionReason,
}) {
  return CompanyApplication.fromJson({
    'id': id,
    'status': status,
    'status_label': status == 'under_review'
        ? 'Under review'
        : status[0].toUpperCase() + status.substring(1),
    'rejection_reason': rejectionReason,
    'can_undo': canUndo,
    'previous_status': canUndo ? 'pending' : null,
    'applied_at_human': '2 days ago',
    'internship_id': 5,
    'internship_title': 'Laravel Developer',
    'student': {
      'id': 9,
      'name': student,
      'email': 'ana@psu.test',
      'course': 'BSIT',
      'year_level': 4,
      'campus': 'Urdaneta City Campus',
      'initials': 'A',
    },
  });
}

void main() {
  group('models', () {
    test('Candidate parses match data and bookmark state', () {
      final candidate = _candidate(matchScore: 91, bookmarked: true, assessment: 78);

      expect(candidate.id, 1);
      expect(candidate.summary.name, 'Ana Cruz');
      expect(candidate.matchScore, 91);
      expect(candidate.matchedSkills, ['Laravel']);
      expect(candidate.assessmentScore, 78);
      expect(candidate.isBookmarked, isTrue);
    });

    test('CompanyApplication carries undo state', () {
      final application = _application(status: 'interview', canUndo: true);

      expect(application.status, 'interview');
      expect(application.canUndo, isTrue);
      expect(application.previousStatus, 'pending');
      expect(application.internshipTitle, 'Laravel Developer');
      expect(application.student.name, 'Ana Cruz');
    });

    test('ApplicationCounts defaults missing buckets to zero', () {
      final counts = ApplicationCounts.fromJson({'all': 5, 'accepted': 2});

      expect(counts['all'], 5);
      expect(counts['accepted'], 2);
      expect(counts['rejected'], 0);
    });

    test('every status has its own colour, and unknown falls back', () {
      expect(applicationStatusColors('accepted').text,
          isNot(applicationStatusColors('rejected').text));
      expect(applicationStatusColors('nonsense').text,
          applicationStatusColors('withdrawn').text);
    });
  });

  group('BrowseCandidatesScreen', () {
    testWidgets('lists candidates with their match score', (tester) async {
      final service = _FakeCompanyService(candidates: [
        _candidate(id: 1, name: 'Ana Cruz', matchScore: 82),
        _candidate(id: 2, name: 'Ben Santos', matchScore: 61),
      ]);

      await tester.pumpWidget(MaterialApp(home: BrowseCandidatesScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('82% match'), findsOneWidget);
      expect(find.text('61% match'), findsOneWidget);
    });

    testWidgets('changing the sort re-queries with it', (tester) async {
      final service = _FakeCompanyService(candidates: [_candidate()]);

      await tester.pumpWidget(MaterialApp(home: BrowseCandidatesScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('fetchCandidates:name:'));
    });

    testWidgets('tapping the bookmark toggles it', (tester) async {
      final service = _FakeCompanyService(candidates: [_candidate(id: 7, bookmarked: false)]);

      await tester.pumpWidget(MaterialApp(home: BrowseCandidatesScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(service.calls, contains('bookmark:7'));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('the bookmarks view uses the bookmarks endpoint and hides the sort row',
        (tester) async {
      final service = _FakeCompanyService(bookmarked: [_candidate(bookmarked: true)]);

      await tester.pumpWidget(
        MaterialApp(home: BrowseCandidatesScreen(service: service, bookmarksOnly: true)),
      );
      await tester.pumpAndSettle();

      expect(service.calls, contains('fetchBookmarks'));
      expect(find.text('Best match'), findsNothing);
      expect(find.text('Bookmarks'), findsOneWidget);
    });

    testWidgets('un-bookmarking in the bookmarks view removes the row', (tester) async {
      final service = _FakeCompanyService(bookmarked: [_candidate(id: 3, bookmarked: true)])
        ..nextBookmarkResult = false;

      await tester.pumpWidget(
        MaterialApp(home: BrowseCandidatesScreen(service: service, bookmarksOnly: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsNothing);
      expect(find.text('No bookmarked candidates'), findsOneWidget);
    });

    testWidgets('an empty browse list suggests what to change', (tester) async {
      final service = _FakeCompanyService(candidates: const []);

      await tester.pumpWidget(MaterialApp(home: BrowseCandidatesScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('No candidates found'), findsOneWidget);
      expect(find.textContaining('match threshold'), findsOneWidget);
    });

    testWidgets('a load failure is retryable', (tester) async {
      final service = _FakeCompanyService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(home: BrowseCandidatesScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CompanyApplicationsScreen', () {
    testWidgets('lists applications with their status', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application(id: 1, status: 'interview')],
        counts: const {'all': 1, 'interview': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('Laravel Developer'), findsOneWidget);
      expect(find.text('Interview'), findsOneWidget);
    });

    testWidgets('the filter chips carry per-status counts and re-query', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application()],
        counts: const {'all': 4, 'accepted': 2},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Accepted (2)'), findsOneWidget);

      await tester.ensureVisible(find.text('Accepted (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepted (2)'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('fetchApplications:accepted:'));
    });

    testWidgets('accepting an application calls through with that status', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application(id: 12, status: 'under_review')],
        counts: const {'all': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ana Cruz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('status:12:accepted:-'));
    });

    testWidgets('rejecting asks for a reason and passes it along', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application(id: 12, status: 'under_review')],
        counts: const {'all': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ana Cruz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject application?'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Not enough Laravel experience');
      await tester.tap(find.widgetWithText(TextButton, 'Reject'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('status:12:rejected:Not enough Laravel experience'));
    });

    testWidgets('cancelling the rejection dialog changes nothing', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application(id: 12, status: 'under_review')],
        counts: const {'all': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ana Cruz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls.where((c) => c.startsWith('status:')), isEmpty);
    });

    testWidgets('an undoable application offers Undo', (tester) async {
      final service = _FakeCompanyService(
        applications: [_application(id: 12, status: 'interview', canUndo: true)],
        counts: const {'all': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ana Cruz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo last change'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('undo:12'));
    });

    testWidgets('a rejection reason is shown on the card', (tester) async {
      final service = _FakeCompanyService(
        applications: [
          _application(id: 1, status: 'rejected', rejectionReason: 'Needs more experience'),
        ],
        counts: const {'all': 1},
      );

      await tester.pumpWidget(MaterialApp(home: CompanyApplicationsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Needs more experience'), findsOneWidget);
    });
  });
}
