import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/company_assessment.dart';
import 'package:skillmatch/screens/company/company_posting.dart';
import 'package:skillmatch/screens/company/posting_detail_screen.dart';
import 'package:skillmatch/services/company_assessment_service.dart';
import 'package:skillmatch/services/company_service.dart';

class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({
    this.counts = const PostingStatusCounts(),
    this.assessments = const [],
    this.error,
  });

  final PostingStatusCounts counts;
  final List<CompanyAssessment> assessments;
  final Object? error;

  final calls = <String>[];
  CompanyPosting posting = _posting();

  @override
  Future<
    ({
      CompanyPosting posting,
      PostingStatusCounts counts,
      List<CompanyAssessment> assessments,
    })
  >
  fetchPosting(int id) async {
    calls.add('fetch:$id');
    if (error != null) throw error!;
    return (posting: posting, counts: counts, assessments: assessments);
  }

  @override
  Future<CompanyPosting> togglePostingStatus(int id) async {
    calls.add('toggle:$id');
    posting = _posting(status: 'closed');
    return posting;
  }

  @override
  Future<void> deletePosting(int id) async {
    calls.add('delete:$id');
  }
}

/// Stands in for the assessment builder's service, so linking and
/// unlinking can be driven without a server.
class _FakeAssessmentService extends CompanyAssessmentService {
  _FakeAssessmentService({this.library, this.stored});

  AssessmentLibrary? library;

  /// What the server says the assessment is, as opposed to the summary the
  /// posting page is holding. Linking re-reads this before writing.
  CompanyAssessment? stored;

  final calls = <String>[];
  List<int>? lastInternshipIds;
  String? lastDescription;

  @override
  Future<CompanyAssessment> fetchAssessment(int id) async {
    calls.add('fetch:$id');
    return stored ?? _assessment(id: id);
  }

  @override
  Future<AssessmentLibrary> fetchLibrary() async {
    calls.add('library');
    return library ?? AssessmentLibrary.fromJson(const {});
  }

  @override
  Future<CompanyAssessment> updateAssessment({
    required int id,
    required List<int> internshipIds,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    calls.add('update:$id');
    lastInternshipIds = internshipIds;
    lastDescription = description;
    return _assessment(id: id, title: title);
  }
}

CompanyPosting _posting({
  int id = 4,
  String title = 'Laravel Developer',
  int slots = 10,
  int applicants = 3,
  String status = 'open',
  List<String> responsibilities = const ['Ship the API'],
  List<String> skills = const ['Laravel', 'php', 'mysql'],
}) {
  return CompanyPosting.fromJson({
    'id': id,
    'title': title,
    'location': 'Zone 4, Brgy. Alipangpang, Pozorrubio, Pangasinan',
    'application_count': applicants,
    'slots_available': slots,
    'slots_filled': 0,
    'status': status,
    'description': responsibilities.join('\n'),
    'responsibilities': responsibilities,
    'skills': skills,
    'posted_at_human': '1 week ago',
  });
}

CompanyAssessment _assessment({
  int id = 2,
  String title = 'PHP Fundamentals',
  int questions = 5,
  int? timeLimit = 20,
  String? description = 'Screens for the PHP basics.',
  List<Map<String, dynamic>> internships = const [
    {'id': 4, 'title': 'Laravel Developer'},
  ],
}) {
  return CompanyAssessment.fromJson({
    'id': id,
    'title': title,
    'description': description,
    'status': 'published',
    'time_limit': timeLimit,
    'question_count': questions,
    'internships': internships,
  });
}

/// Brings a row below the fold into view. The detail page is a long scroller
/// on an 800x600 test viewport, so most of it starts off-screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

/// Back to the top, where the action buttons live.
Future<void> _scrollBack(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
  }
}

Future<void> _pump(
  WidgetTester tester,
  CompanyService service, {
  CompanyAssessmentService? assessments,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PostingDetailScreen(
        postingId: 4,
        service: service,
        assessmentService: assessments,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the posting, its overview counts and its details', (
    tester,
  ) async {
    final service = _FakeCompanyService(
      counts: const PostingStatusCounts(
        pending: 0,
        reviewing: 1,
        shortlisted: 2,
        hired: 0,
        rejected: 0,
      ),
      assessments: [_assessment()],
    );

    await _pump(tester, service);

    expect(find.text('Laravel Developer'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Posted 1 week ago'), findsOneWidget);

    // The web's Overview grid, number for number.
    expect(find.text('Applicants'), findsWidgets);
    expect(find.text('Open slots'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget, reason: 'slots filled');

    // Responsibilities and skills.
    await _scrollTo(tester, find.text('Ship the API'));
    expect(find.text('Ship the API'), findsOneWidget);

    await _scrollTo(tester, find.text('mysql'));
    expect(find.text('Laravel'), findsOneWidget);
    expect(find.text('mysql'), findsOneWidget);

    // The linked assessment, with the same meta line the web shows.
    await _scrollTo(tester, find.text('PHP Fundamentals'));
    expect(find.text('PHP Fundamentals'), findsOneWidget);
    expect(find.text('5 questions • 20 min'), findsOneWidget);

    // All three editing actions.
    await _scrollBack(tester);
    expect(find.text('Edit posting'), findsOneWidget);
    expect(find.text('Close posting'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a closed posting offers to reopen instead', (tester) async {
    final service = _FakeCompanyService()..posting = _posting(status: 'closed');

    await _pump(tester, service);

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Reopen posting'), findsOneWidget);
    expect(find.text('Close posting'), findsNothing);
  });

  testWidgets('closing asks first, then calls the service', (tester) async {
    final service = _FakeCompanyService();
    await _pump(tester, service);

    await tester.tap(find.text('Close posting'));
    await tester.pumpAndSettle();

    expect(find.text('Close this posting?'), findsOneWidget);

    // Backing out must not change anything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.calls.where((c) => c.startsWith('toggle')), isEmpty);

    await tester.tap(find.text('Close posting'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Close posting'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('toggle:4'));
    expect(find.text('Reopen posting'), findsOneWidget);
  });

  testWidgets('deleting warns about the applicants it takes with it', (
    tester,
  ) async {
    final service = _FakeCompanyService(
      counts: const PostingStatusCounts(pending: 1, reviewing: 2),
    );
    await _pump(tester, service);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('has 3 applicants'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('delete:4'));
  });

  testWidgets('says so when the posting will not load', (tester) async {
    final service = _FakeCompanyService(error: Exception('offline'));
    await _pump(tester, service);

    expect(find.textContaining('Could not load this posting.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an empty posting says so rather than showing blank cards', (
    tester,
  ) async {
    final service = _FakeCompanyService()
      ..posting = _posting(
        applicants: 0,
        responsibilities: const [],
        skills: const [],
      );

    await _pump(tester, service);

    await _scrollTo(
      tester,
      find.text('No one has applied to this posting yet.'),
    );
    expect(
      find.text('No one has applied to this posting yet.'),
      findsOneWidget,
    );

    await _scrollTo(tester, find.text('No responsibilities listed yet.'));
    expect(find.text('No responsibilities listed yet.'), findsOneWidget);

    await _scrollTo(tester, find.text('No skills listed yet.'));
    expect(find.text('No skills listed yet.'), findsOneWidget);

    await _scrollTo(
      tester,
      find.textContaining('No assessments screen for this posting yet.'),
    );
    expect(
      find.textContaining('No assessments screen for this posting yet.'),
      findsOneWidget,
    );
  });

  testWidgets('an assessment already written can be reused here', (
    tester,
  ) async {
    final service = _FakeCompanyService(assessments: [_assessment()]);
    final assessments = _FakeAssessmentService(
      // What the server holds for the paper being reused: it is on posting 9
      // and has a description the posting page's summary never carried.
      stored: _assessment(
        id: 8,
        title: 'General Aptitude',
        description: 'Numeracy and reading.',
        internships: const [
          {'id': 9, 'title': 'QA Intern'},
        ],
      ),
      library: AssessmentLibrary.fromJson({
        'assessments': [
          // Already on this posting, so it must not be offered again.
          {
            'id': 2,
            'title': 'PHP Fundamentals',
            'question_count': 5,
            'internships': [
              {'id': 4, 'title': 'Laravel Developer'},
            ],
          },
          // Written for another posting — this is the one to reuse.
          {
            'id': 8,
            'title': 'General Aptitude',
            'question_count': 10,
            'internships': [
              {'id': 9, 'title': 'QA Intern'},
            ],
          },
        ],
      }),
    );

    await _pump(tester, service, assessments: assessments);

    await _scrollTo(tester, find.text('Use an existing assessment'));
    await tester.ensureVisible(find.text('Use an existing assessment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use an existing assessment'));
    await tester.pumpAndSettle();

    expect(find.text('General Aptitude'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'PHP Fundamentals'),
      findsNothing,
      reason: 'it already screens for this posting',
    );

    await tester.tap(find.text('General Aptitude'));
    await tester.pumpAndSettle();

    // The posting is added to what the paper already screens for, rather
    // than replacing it — reuse is a link, never a move.
    expect(assessments.calls, contains('update:8'));
    expect(assessments.lastInternshipIds, [9, 4]);

    // Update is a full replace, so it is read back first. Without that, the
    // summary this page holds would send a null description and wipe it.
    expect(assessments.calls.indexOf('fetch:8'), lessThan(
      assessments.calls.indexOf('update:8'),
    ));
    expect(assessments.lastDescription, 'Numeracy and reading.');
  });

  testWidgets('the last posting cannot be unlinked, and says why', (
    tester,
  ) async {
    final service = _FakeCompanyService(assessments: [_assessment()]);
    final assessments = _FakeAssessmentService();

    await _pump(tester, service, assessments: assessments);

    await _scrollTo(tester, find.byTooltip('Stop using this assessment here'));
    await tester.ensureVisible(find.byTooltip('Stop using this assessment here'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stop using this assessment here'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Nothing was written: an assessment linked to no posting at all cannot
    // be reached again, and the backend refuses it anyway.
    expect(assessments.calls, isNot(contains('update:2')));
    expect(assessments.lastInternshipIds, isNull);
    expect(find.textContaining('only posting using this'), findsOneWidget);
  });

  testWidgets('a shared assessment can be taken off just this posting', (
    tester,
  ) async {
    final onTwoPostings = _assessment(
      internships: const [
        {'id': 4, 'title': 'Laravel Developer'},
        {'id': 9, 'title': 'QA Intern'},
      ],
    );
    final service = _FakeCompanyService(assessments: [onTwoPostings]);
    final assessments = _FakeAssessmentService(stored: onTwoPostings);

    await _pump(tester, service, assessments: assessments);

    await _scrollTo(tester, find.textContaining('shared with 1 other posting'));
    expect(find.textContaining('shared with 1 other posting'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Stop using this assessment here'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stop using this assessment here'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Only this posting goes; the other keeps screening with the same paper.
    expect(assessments.lastInternshipIds, [9]);
  });
}
