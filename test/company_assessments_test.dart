import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/core/app_theme.dart';
import 'package:skillmatch/models/assessment.dart';
import 'package:skillmatch/models/assessment_submission.dart';
import 'package:skillmatch/models/company_assessment.dart';
import 'package:skillmatch/screens/company/assessment_draft.dart';
import 'package:skillmatch/screens/company/assessment_library_screen.dart';
import 'package:skillmatch/screens/company/assessment_preview_screen.dart';
import 'package:skillmatch/screens/company/assessment_submissions_screen.dart';
import 'package:skillmatch/screens/company/create_assessment_screen.dart';
import 'package:skillmatch/services/company_assessment_service.dart';

/// Stands in for the real service so the screens can run without a backend,
/// recording what it was asked for and what payload it was handed.
class _FakeAssessmentService extends CompanyAssessmentService {
  _FakeAssessmentService({
    this.library,
    this.submissions = const [],
    this.error,
  });

  AssessmentLibrary? library;

  /// Set directly by a test that needs [fetchAssessment] to answer with
  /// something other than the default paper.
  CompanyAssessment? assessment;
  List<AssessmentSubmission> submissions;

  /// The postings the results can be split by, as the server reports them.
  List<SubmissionPosting> submissionPostings = const [];
  final Object? error;

  final calls = <String>[];
  List<Map<String, dynamic>>? lastQuestionPayload;
  Map<String, dynamic>? lastDetails;

  @override
  Future<AssessmentLibrary> fetchLibrary() async {
    calls.add('library');
    if (error != null) throw error!;
    return library ?? AssessmentLibrary.fromJson(const {});
  }

  @override
  Future<CompanyAssessment> fetchAssessment(int id) async {
    calls.add('fetch:$id');
    if (error != null) throw error!;
    return assessment ?? CompanyAssessment.fromJson(_assessmentJson());
  }

  @override
  Future<AssessmentEdit> fetchAssessmentForEditing(int id) async {
    calls.add('edit:$id');
    if (error != null) throw error!;
    return AssessmentEdit(
      assessment: assessment ?? CompanyAssessment.fromJson(_assessmentJson()),
      postingOptions: library?.postingOptions ?? const [],
    );
  }

  @override
  Future<CompanyAssessment> createAssessment({
    required List<int> internshipIds,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    calls.add('create');
    lastDetails = {
      'internship_ids': internshipIds,
      'title': title,
      'description': description,
      'time_limit': timeLimitMinutes,
    };
    return CompanyAssessment.fromJson(
      _assessmentJson(id: 7, questions: const []),
    );
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
    lastDetails = {
      'internship_ids': internshipIds,
      'title': title,
      'description': description,
      'time_limit': timeLimitMinutes,
    };
    return CompanyAssessment.fromJson(_assessmentJson(id: id));
  }

  @override
  Future<CompanyAssessment> saveQuestions({
    required int id,
    required List<Map<String, dynamic>> questions,
  }) async {
    calls.add('saveQuestions:$id');
    lastQuestionPayload = questions;
    return CompanyAssessment.fromJson(_assessmentJson(id: id));
  }

  @override
  Future<void> deleteAssessment(int id) async {
    calls.add('delete:$id');
  }

  @override
  Future<AssessmentSubmissions> fetchSubmissions(
    int id, {
    String query = '',
    int? internshipId,
  }) async {
    calls.add('submissions:$id:$query:${internshipId ?? 'all'}');
    if (error != null) throw error!;
    return AssessmentSubmissions(
      submissions: internshipId == null
          ? submissions
          : submissions
                .where((s) => s.internshipId == internshipId)
                .toList(),
      postings: submissionPostings,
    );
  }
}

Map<String, dynamic> _assessmentJson({
  int id = 1,
  String title = 'Design Intern',
  String status = 'published',
  int submissions = 4,
  List<Map<String, dynamic>>? questions,
}) => {
  'id': id,
  'internship_id': 2,
  'internship_title': 'Product Design Intern',
  'internships': [
    {'id': 2, 'title': 'Product Design Intern'},
  ],
  'title': title,
  'description': 'Screens for core visual principles.',
  'time_limit': 45,
  'total_points': 2,
  'status': status,
  'question_count': questions?.length ?? 2,
  'submission_count': submissions,
  'created_at_human': '2 weeks ago',
  'questions':
      questions ??
      [
        {
          'id': 11,
          'question_text': 'Which is a CSS preprocessor?',
          'description': 'Pick one.',
          'question_type': 'multiple_choice',
          'image_url': null,
          'points': 1,
          'choices': [
            {'id': 1, 'choice_text': 'Sass', 'is_correct': true},
            {'id': 2, 'choice_text': 'Django', 'is_correct': false},
          ],
        },
        {
          'id': 12,
          'question_text': 'Which are JavaScript frameworks?',
          'description': null,
          'question_type': 'checkbox',
          'image_url': null,
          'points': 1,
          'choices': [
            {'id': 3, 'choice_text': 'React', 'is_correct': true},
            {'id': 4, 'choice_text': 'Vue', 'is_correct': true},
            {'id': 5, 'choice_text': 'Laravel', 'is_correct': false},
          ],
        },
      ],
};

Map<String, dynamic> _submissionJson({
  int id = 1,
  String name = 'Jayby Bautista',
  int score = 1,
  int total = 1,
  int percentage = 100,
  bool passed = true,
  bool timedOut = false,
}) => {
  'id': id,
  'student_id': 2,
  'student_name': name,
  'student_email': 'jayby@example.test',
  'student_avatar_url': null,
  'score': score,
  'total_points': total,
  'percentage': percentage,
  'passed': passed,
  'timed_out': timedOut,
  'submitted_at': '2026-08-11T13:35:16+00:00',
  'submitted_at_label': 'Aug 11, 2026',
};

AssessmentLibrary _library({
  List<Map<String, dynamic>>? assessments,
  bool withPostings = true,
  List<Map<String, dynamic>>? groups,
}) {
  final papers = assessments ?? [_assessmentJson()];

  return AssessmentLibrary.fromJson({
    'assessments': papers,
    // The screen lists papers under the posting they screen for, so unless a
    // test says otherwise everything sits under the one posting they were
    // written for.
    'groups': groups ??
        (papers.isEmpty
            ? <Map<String, dynamic>>[]
            : [
                {
                  'internship_id': 2,
                  'internship_title': 'Product Design Intern',
                  'status': 'open',
                  'assessments': papers,
                },
              ]),
    'posting_options': withPostings
        ? [
            {'id': 2, 'title': 'Product Design Intern'},
            {'id': 5, 'title': 'Laravel Developer'},
          ]
        : <Map<String, dynamic>>[],
  });
}

/// One paper screening for two postings, optionally counted for just one
/// of them the way a card under a posting heading is.
Map<String, dynamic> _sharedPaper({int submissions = 4, int? scope}) => {
  ..._assessmentJson(submissions: submissions),
  'internships': [
    {'id': 2, 'title': 'Product Design Intern'},
    {'id': 5, 'title': 'Laravel Developer'},
  ],
  'submission_scope_internship_id': scope,
};

/// Drags the list up until [finder] appears. Used where the target is far
/// enough down that the viewport has not built it yet.
Future<void> _dragUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
  }
}

/// Scrolls the screen's list until [finder] is built — these are long pages
/// and the 800x600 test viewport only builds what is near the top.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CompanyAssessment parsing', () {
    test('reads a library card', () {
      final assessment = CompanyAssessment.fromJson(_assessmentJson());

      expect(assessment.id, 1);
      expect(assessment.internshipTitle, 'Product Design Intern');
      expect(assessment.timeLimitMinutes, 45);
      expect(assessment.questionCount, 2);
      expect(assessment.submissionCount, 4);
      expect(assessment.isPublished, isTrue);
    });

    test('a draft is told apart from a published paper', () {
      final draft = CompanyAssessment.fromJson(
        _assessmentJson(status: 'draft'),
      );

      expect(draft.isDraft, isTrue);
      expect(draft.isPublished, isFalse);
      expect(
        assessmentStatusColors('draft').text,
        isNot(assessmentStatusColors('published').text),
      );
    });

    test('reads questions with their correct answers', () {
      final assessment = CompanyAssessment.fromJson(_assessmentJson());

      final first = assessment.questions.first;
      expect(first.type, QuestionType.multipleChoice);
      expect(first.choices.where((c) => c.isCorrect).map((c) => c.text), [
        'Sass',
      ]);

      final second = assessment.questions[1];
      expect(second.type, QuestionType.checkbox);
      expect(second.choices.where((c) => c.isCorrect).map((c) => c.text), [
        'React',
        'Vue',
      ]);
    });

    test('an empty payload parses without throwing', () {
      final library = AssessmentLibrary.fromJson(const {});

      expect(library.assessments, isEmpty);
      expect(library.postingOptions, isEmpty);
    });
  });

  group('DraftQuestion', () {
    test('builds the payload shape the API expects', () {
      final draft = DraftQuestion();
      draft.textController.text = '  Which is a CSS preprocessor?  ';
      draft.options[0].controller.text = 'Sass';
      draft.options[1].controller.text = 'Django';
      draft.correctOptionId = draft.options[0].id;

      final payload = draft.toPayload();

      expect(payload['type'], 'multiple_choice');
      expect(payload['question_text'], 'Which is a CSS preprocessor?');
      // Blank options are left in — the server drops them, so filtering here
      // as well would be a second place to keep in step.
      expect((payload['choices'] as List), hasLength(4));
      expect((payload['choices'] as List).first, {
        'text': 'Sass',
        'is_correct': true,
      });
      expect((payload['choices'] as List)[1], {
        'text': 'Django',
        'is_correct': false,
      });
    });

    test('a checkbox question marks every ticked option correct', () {
      final draft = DraftQuestion();
      draft.type = QuestionType.checkbox;
      draft.options[0].controller.text = 'React';
      draft.options[1].controller.text = 'Vue';
      draft.options[2].controller.text = 'Laravel';
      draft.correctOptionIds.addAll([draft.options[0].id, draft.options[1].id]);

      final choices = draft.toPayload()['choices'] as List;

      expect(choices[0]['is_correct'], isTrue);
      expect(choices[1]['is_correct'], isTrue);
      expect(choices[2]['is_correct'], isFalse);
    });

    test('rebuilds from a stored question, keeping its answers', () {
      final stored = CompanyAssessment.fromJson(_assessmentJson()).questions;

      final single = DraftQuestion.fromExisting(stored[0]);
      expect(single.type, QuestionType.multipleChoice);
      expect(single.options, hasLength(2));
      expect(single.options[0].text, 'Sass');
      expect(single.correctOptionId, single.options[0].id);

      final multi = DraftQuestion.fromExisting(stored[1]);
      expect(multi.type, QuestionType.checkbox);
      expect(multi.options, hasLength(3));
      expect(multi.correctOptionIds, {
        multi.options[0].id,
        multi.options[1].id,
      });
    });

    test('keeps an existing image until a new one replaces it', () {
      final stored = CompanyAssessmentQuestion.fromJson(const {
        'id': 1,
        'question_text': 'Powerhouse of the cell',
        'question_type': 'multiple_choice',
        'image_url': 'data:image/png;base64,AAAA',
        'choices': [
          {'id': 1, 'choice_text': 'Mitochondria', 'is_correct': true},
          {'id': 2, 'choice_text': 'Nucleus', 'is_correct': false},
        ],
      });

      final draft = DraftQuestion.fromExisting(stored);

      expect(draft.hasImage, isTrue);
      expect(draft.toPayload()['image_url'], 'data:image/png;base64,AAAA');
    });

    test('question types map to the values the API stores', () {
      expect(QuestionType.multipleChoice.apiValue, 'multiple_choice');
      expect(QuestionType.checkbox.apiValue, 'checkbox');
      expect(QuestionType.dropdown.apiValue, 'dropdown');
    });
  });

  group('AssessmentLibraryScreen', () {
    testWidgets('lists the assessments it fetched', (tester) async {
      final service = _FakeAssessmentService(library: _library());

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(service.calls, contains('library'));
      expect(find.text('Design Intern'), findsOneWidget);
      expect(find.text('Product Design Intern'), findsOneWidget);
      expect(find.text('2 Questions'), findsOneWidget);
      expect(find.text('45 Mins'), findsOneWidget);
      expect(find.text('View Submissions (4)'), findsOneWidget);
    });

    testWidgets(
      'a paper used by two postings is listed under each, counted separately',
      (tester) async {
        // The same assessment row, under both headings. Two identical cards
        // with no headings and one shared total is what made this look like
        // a duplicate; the heading says which applicants each card is about,
        // and the count follows the heading.
        final service = _FakeAssessmentService(
          library: _library(
            assessments: [_sharedPaper(submissions: 4)],
            groups: [
              {
                'internship_id': 2,
                'internship_title': 'Product Design Intern',
                'status': 'open',
                'assessments': [
                  _sharedPaper(submissions: 4, scope: 2),
                ],
              },
              {
                'internship_id': 5,
                'internship_title': 'Laravel Developer',
                'status': 'open',
                'assessments': [
                  _sharedPaper(submissions: 0, scope: 5),
                ],
              },
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: AssessmentLibraryScreen(service: service)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Product Design Intern'), findsOneWidget);
        expect(find.text('Design Intern'), findsWidgets);

        // The whole point: different postings, different results.
        expect(find.text('View Submissions (4)'), findsOneWidget);

        // And the card says it is the same paper doing a job elsewhere, not
        // a copy that could be edited on its own.
        expect(find.text('Also screens for 1 other posting'), findsWidgets);

        await _dragUntil(tester, find.text('Laravel Developer'));
        expect(find.text('Laravel Developer'), findsOneWidget);

        // Nobody has taken it for this posting yet, so its card offers the
        // results without a number — while the other card still says 4.
        await _dragUntil(tester, find.text('View Submissions'));
        expect(find.text('View Submissions'), findsOneWidget);
      },
    );

    testWidgets('a card opens the results for its own posting only', (
      tester,
    ) async {
      final service = _FakeAssessmentService(
        library: _library(
          assessments: [_sharedPaper()],
          groups: [
            {
              'internship_id': 5,
              'internship_title': 'Laravel Developer',
              'status': 'open',
              'assessments': [_sharedPaper(scope: 5)],
            },
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.textContaining('View Submissions'));
      await tester.tap(find.textContaining('View Submissions'));
      await tester.pumpAndSettle();

      // Narrowed to the posting whose heading it sat under — otherwise
      // listing it under each posting would tell you nothing new.
      expect(service.calls, contains('submissions:1::5'));
    });

    testWidgets('an empty library explains what to do next', (tester) async {
      final service = _FakeAssessmentService(
        library: _library(assessments: const []),
      );

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No assessments yet'), findsOneWidget);
    });

    testWidgets('deleting warns about the submissions it would take with it', (
      tester,
    ) async {
      final service = _FakeAssessmentService(library: _library());

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('has 4 submissions'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('delete:1'));
    });

    testWidgets('cancelling the delete dialog leaves it alone', (tester) async {
      final service = _FakeAssessmentService(library: _library());

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls.where((c) => c.startsWith('delete')), isEmpty);
    });

    testWidgets('creating is refused while no posting is open', (tester) async {
      // The backend requires a posting and only offers open ones, so with
      // none open there is nothing an assessment could screen for.
      final service = _FakeAssessmentService(
        library: _library(withPostings: false),
      );

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.textContaining('Open a posting first'), findsOneWidget);
    });

    testWidgets('a load failure is retryable', (tester) async {
      final service = _FakeAssessmentService(error: Exception('offline'));

      await tester.pumpWidget(
        MaterialApp(home: AssessmentLibraryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load your assessments.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CreateAssessmentScreen', () {
    testWidgets('step 1 saves the details, then step 2 saves the questions', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A single posting is preselected, so only the title is needed.
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Senior Frontend Engineer Screening',
        ),
        'Frontend Screening',
      );
      await tester.enterText(find.widgetWithText(TextField, '00'), '30');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('create'));
      expect(service.lastDetails, {
        'internship_ids': [2],
        'title': 'Frontend Screening',
        'description': null,
        'time_limit': 30,
      });

      // Now on step 2.
      expect(find.text('Question 1'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type here your question'),
        'Which is a CSS preprocessor?',
      );
      final answerFields = find.widgetWithText(TextField, 'Add answer…');
      await tester.enterText(answerFields.at(0), 'Sass');
      await tester.enterText(answerFields.at(1), 'Django');

      await _scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('saveQuestions:7'));
      final payload = service.lastQuestionPayload!;
      expect(payload, hasLength(1));
      expect(payload.first['question_text'], 'Which is a CSS preprocessor?');
      expect((payload.first['choices'] as List).first['text'], 'Sass');
    });

    testWidgets('a missing title is caught before any request', (tester) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Give the assessment a title first.'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('a time limit outside the allowed range is caught locally', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Senior Frontend Engineer Screening',
        ),
        'Screening',
      );
      await tester.enterText(find.widgetWithText(TextField, '00'), '900');

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.textContaining('between 1 and 480 minutes'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('several postings can screen with one assessment', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
              AssessmentPostingOption(id: 5, title: 'Frontend Intern'),
              AssessmentPostingOption(id: 9, title: 'QA Intern'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // More than one posting, so nothing is preselected — every one that
      // should screen with this paper is ticked by hand.
      await tester.tap(find.text('Product Design Intern'));
      await tester.tap(find.text('QA Intern'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Senior Frontend Engineer Screening',
        ),
        'Shared Screening',
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Both ids go out in one request: one paper, two postings, rather than
      // two copies that then drift apart.
      expect(service.lastDetails!['internship_ids'], [2, 9]);
      expect(service.calls.where((c) => c == 'create'), hasLength(1));
    });

    testWidgets('no posting ticked is caught before any request', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
              AssessmentPostingOption(id: 5, title: 'Frontend Intern'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Senior Frontend Engineer Screening',
        ),
        'Screening',
      );

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(
        find.textContaining('at least one posting'),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets(
      'editing starts from the postings it already screens for, closed ones '
      'included',
      (tester) async {
        final service = _FakeAssessmentService();

        // The paper screens for two postings, one of which is closed and so
        // never appears in the library's own list of options.
        service.assessment = CompanyAssessment.fromJson({
          ..._assessmentJson(),
          'internships': [
            {'id': 2, 'title': 'Product Design Intern'},
            {'id': 4, 'title': 'Archived Winter Intake'},
          ],
        });
        service.library = AssessmentLibrary.fromJson(const {
          'posting_options': [
            {'id': 2, 'title': 'Product Design Intern'},
            {'id': 4, 'title': 'Archived Winter Intake'},
            {'id': 5, 'title': 'Frontend Intern'},
          ],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: CreateAssessmentScreen(
              existing: CompanyAssessment.fromJson(_assessmentJson()),
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Saving writes exactly what is ticked, so the closed posting has to
        // survive an untouched form — otherwise opening the editor and
        // pressing Next would quietly unlink it.
        expect(service.lastDetails!['internship_ids'], [2, 4]);
      },
    );

    testWidgets(
      'editing loads the stored paper and updates rather than creates',
      (tester) async {
        final service = _FakeAssessmentService();
        final existing = CompanyAssessment.fromJson(_assessmentJson());

        await tester.pumpWidget(
          MaterialApp(
            home: CreateAssessmentScreen(
              postings: const [
                AssessmentPostingOption(id: 2, title: 'Product Design Intern'),
              ],
              existing: existing,
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Assessment'), findsOneWidget);
        expect(service.calls, contains('edit:1'));

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(service.calls, contains('update:1'));

        // The stored questions came back, so both are on the form.
        expect(find.text('Question 1'), findsOneWidget);
        expect(find.text('Question 2'), findsOneWidget);
      },
    );
  });

  group('CreateAssessmentScreen side panel', () {
    /// Fills in step 1 and moves to the questions step, where the panel is.
    Future<void> toQuestions(
      WidgetTester tester,
      _FakeAssessmentService service, {
      String timeLimit = '5',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Laravel Developer'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Senior Frontend Engineer Screening',
        ),
        'SAMPLE',
      );
      await tester.enterText(find.widgetWithText(TextField, '00'), timeLimit);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWidgets('the panel button is on the questions step, not on details', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: CreateAssessmentScreen(
            postings: const [
              AssessmentPostingOption(id: 2, title: 'Laravel Developer'),
            ],
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 has no question to set a type on and nothing to save yet.
      expect(find.byType(FloatingActionButton), findsNothing);

      await toQuestions(tester, service);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('the button sits clear of the Save bar', (tester) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service);

      // They were landing on top of each other: a Scaffold's floating action
      // button goes to the very bottom of the screen, which is exactly where
      // the Save bar is.
      final button = tester.getRect(find.byType(FloatingActionButton));
      final saveBar = tester.getRect(find.text('Save'));

      expect(
        button.bottom,
        lessThan(saveBar.top),
        reason: 'the panel button must not cover the Save button',
      );
    });

    testWidgets('it carries the three panels the web shows', (tester) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service);
      await openPanel(tester);

      expect(find.text('Select type'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsWidgets);
      expect(find.text('Checkboxes'), findsOneWidget);
      expect(find.text('Dropdown'), findsOneWidget);

      expect(find.text('Assessment info'), findsOneWidget);
      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('Time limit'), findsOneWidget);
      expect(find.text('Posting'), findsOneWidget);

      expect(find.text('Save assessment'), findsOneWidget);
      expect(find.text('Back to details'), findsOneWidget);
    });

    testWidgets('the info reads the assessment being built', (tester) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service, timeLimit: '5');
      await openPanel(tester);

      expect(find.text('1'), findsWidgets, reason: 'one question so far');
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('Laravel Developer'), findsOneWidget);
    });

    testWidgets('an untimed assessment says so rather than showing 0 min', (
      tester,
    ) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service, timeLimit: '');
      await openPanel(tester);

      expect(find.text('No limit'), findsOneWidget);
    });

    testWidgets('choosing a type in the panel changes the question', (
      tester,
    ) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service);
      await openPanel(tester);

      await tester.tap(find.text('Checkboxes'));
      await tester.pumpAndSettle();

      // The panel follows the change...
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.ancestor(
                  of: find.text('Checkboxes'),
                  matching: find.byType(InkWell),
                ),
                matching: find.byIcon(Icons.radio_button_checked),
              ),
            )
            .color,
        AppColors.primary,
      );

      // ...and so does the question card behind it, which is the point.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The card shows its type in caps, so this is the question itself
      // reporting the change the panel made.
      expect(find.text('CHECKBOXES'), findsOneWidget);
    });

    testWidgets('Back to details returns to step 1', (tester) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service);
      await openPanel(tester);

      await tester.tap(find.text('Back to details'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2 \u00b7 Details'), findsOneWidget);
      expect(find.text('LINKED POSTINGS'), findsOneWidget);
    });

    testWidgets('Save assessment saves the paper', (tester) async {
      final service = _FakeAssessmentService();
      await toQuestions(tester, service);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type here your question'),
        'Which is a CSS preprocessor?',
      );
      final answers = find.widgetWithText(TextField, 'Add answer\u2026');
      await tester.enterText(answers.at(0), 'Sass');
      await tester.enterText(answers.at(1), 'Django');

      await openPanel(tester);
      await tester.tap(find.text('Save assessment'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('saveQuestions:7'));
      expect(service.lastQuestionPayload!.first['question_text'],
          'Which is a CSS preprocessor?');
    });
  });

  group('AssessmentPreviewScreen', () {
    testWidgets('hides the correct answers until they are revealed', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentPreviewScreen(assessmentId: 1, service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Which is a CSS preprocessor?'), findsOneWidget);
      expect(find.text('Sass'), findsOneWidget);
      // Nothing is marked correct on screen yet.
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.tap(find.text('Show correct answer').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.text('Hide correct answer'), findsOneWidget);
    });

    testWidgets('reveal-all toggles every question at once', (tester) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentPreviewScreen(assessmentId: 1, service: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Hide correct answer'), findsNWidgets(2));
    });
  });

  group('AssessmentSubmissionsScreen', () {
    testWidgets('lists attempts with their score and verdict', (tester) async {
      final service = _FakeAssessmentService(
        submissions: [
          AssessmentSubmission.fromJson(_submissionJson()),
          AssessmentSubmission.fromJson(
            _submissionJson(
              id: 2,
              name: 'Ana Cruz',
              score: 0,
              percentage: 0,
              passed: false,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentSubmissionsScreen(
            assessment: CompanyAssessment.fromJson(_assessmentJson()),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jayby Bautista'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('a timed-out attempt reads as timed out, not passed', (
      tester,
    ) async {
      // Running out of time never passes, however well the answered
      // questions scored — the same rule the student's result screen applies.
      final service = _FakeAssessmentService(
        submissions: [
          AssessmentSubmission.fromJson(
            _submissionJson(percentage: 90, passed: false, timedOut: true),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentSubmissionsScreen(
            assessment: CompanyAssessment.fromJson(_assessmentJson()),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Passed'), findsNothing);
    });

    testWidgets('an empty list says results appear once someone completes it', (
      tester,
    ) async {
      final service = _FakeAssessmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentSubmissionsScreen(
            assessment: CompanyAssessment.fromJson(
              _assessmentJson(submissions: 0),
            ),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No submissions yet'), findsOneWidget);
    });

    testWidgets('searching re-queries with the term', (tester) async {
      final service = _FakeAssessmentService(
        submissions: [AssessmentSubmission.fromJson(_submissionJson())],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentSubmissionsScreen(
            assessment: CompanyAssessment.fromJson(_assessmentJson()),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(service.calls, contains('submissions:1:Ana:all'));
    });
  });
}
