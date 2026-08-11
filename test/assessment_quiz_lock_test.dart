import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/core/api_client.dart';
import 'package:skillmatch/models/assessment.dart';
import 'package:skillmatch/screens/assessments/assessment_quiz_screen.dart';
import 'package:skillmatch/services/assessment_service.dart';

/// Drives the quiz screen without a server so the cross-device lock can be
/// exercised exactly as a student hits it.
class _FakeAssessmentService extends AssessmentService {
  /// Flipped mid-test to stand in for the web submitting first.
  bool attemptOpen = true;
  int submitCalls = 0;
  bool? lastSubmitTimedOut;

  @override
  Future<AssessmentQuiz> fetchQuiz(int assessmentId) async => AssessmentQuiz.fromJson({
        'assessment': {'id': assessmentId, 'title': 'Design Intern', 'time_limit': 5},
        'questions': [
          {
            'id': 1,
            'question_text': 'Powerhouse of the cell',
            'question_type': 'multiple_choice',
            'points': 1,
            'choices': [
              {'id': 1, 'choice_text': 'mito'},
              {'id': 2, 'choice_text': 'hehe'},
            ],
          },
        ],
      });

  @override
  Future<bool> isAttemptOpen(int assessmentId) async => attemptOpen;

  /// Stands in for the server's 409 guard once the window has closed.
  @override
  Future<AssessmentAttemptResult> submit(
    int assessmentId,
    Map<int, Object> answers, {
    bool timedOut = false,
  }) async {
    submitCalls++;
    lastSubmitTimedOut = timedOut;
    if (!attemptOpen) {
      throw ApiException('Already submitted on another device.', statusCode: 409);
    }
    return AssessmentAttemptResult.fromJson({
      'assessment_title': 'Design Intern',
      'score': 1,
      'total_points': 1,
      'percentage': 100,
      'passed': true,
      'headline': 'Passed',
      'message': 'Nice',
    });
  }

  @override
  Future<AssessmentAttemptResult> fetchResult(int assessmentId) async =>
      AssessmentAttemptResult.fromJson({
        'assessment_title': 'Design Intern',
        'score': 0,
        'total_points': 1,
        'percentage': 0,
        'passed': false,
        'headline': "You didn't pass this time",
        'message': 'Recorded.',
      });
}

/// A timed quiz ticks once a second forever, so `pumpAndSettle` would never
/// return. These helpers pump a bounded number of frames instead.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _pumpQuiz(WidgetTester tester, _FakeAssessmentService service) async {
  await tester.pumpWidget(MaterialApp(
    home: AssessmentQuizScreen(assessmentId: 1, service: service),
  ));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('submitting into a window closed on the web ends the quiz for good', (tester) async {
    final service = _FakeAssessmentService();
    await _pumpQuiz(tester, service);

    expect(find.text('Submit Assessment'), findsOneWidget);

    // The web submits in the background while this student is still answering.
    service.attemptOpen = false;

    await tester.tap(find.text('Submit Assessment'));
    await _settle(tester);
    await tester.tap(find.text('Submit')); // confirmation dialog
    await _settle(tester);

    expect(find.text('Already submitted'), findsOneWidget);
    // The paper is gone the moment the lock engages, dialog still up or not.
    expect(find.text('Submit Assessment'), findsNothing);

    // Both the dialog and the locked screen behind it offer this, so be exact.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('View result'),
    ));
    await _settle(tester);

    // The student must land on the recorded result — never back on the paper.
    expect(find.text('Submit Assessment'), findsNothing);
    expect(find.text('Back to Applications'), findsOneWidget);
    expect(find.textContaining('You scored'), findsOneWidget);
  });

  testWidgets('the background poll closes the quiz even if nothing is tapped', (tester) async {
    final service = _FakeAssessmentService();
    await _pumpQuiz(tester, service);

    service.attemptOpen = false;

    // Let the 8-second state poll fire.
    await tester.pump(const Duration(seconds: 9));
    await _settle(tester);

    expect(find.text('Already submitted'), findsOneWidget);

    // Both the dialog and the locked screen behind it offer this, so be exact.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('View result'),
    ));
    await _settle(tester);

    expect(find.text('Submit Assessment'), findsNothing);
    expect(find.text('Back to Applications'), findsOneWidget);
  });

  testWidgets('a closed quiz exposes nothing left to submit', (tester) async {
    final service = _FakeAssessmentService();
    await _pumpQuiz(tester, service);

    service.attemptOpen = false;
    await tester.pump(const Duration(seconds: 9));
    await _settle(tester);

    final callsAfterLock = service.submitCalls;

    // Both the dialog and the locked screen behind it offer this, so be exact.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('View result'),
    ));
    await _settle(tester);

    // No submit button survives, so there is nothing left to spam.
    expect(find.text('Submit Assessment'), findsNothing);
    expect(service.submitCalls, callsAfterLock);
  });

  testWidgets('an expired deadline auto-submits and is flagged as timed out', (tester) async {
    // The deadline is wall-clock and persisted, so this is what a student who
    // walked away and came back after the limit actually hits. (Pumping fake
    // time wouldn't expire it — DateTime.now() is the real clock.)
    SharedPreferences.setMockInitialValues({
      'student_quiz_timer_end_1': DateTime.now().millisecondsSinceEpoch - 1000,
    });

    final service = _FakeAssessmentService();
    await _pumpQuiz(tester, service);
    await _settle(tester);

    expect(service.submitCalls, 1);
    // Without this flag the server would happily pass a timed-out attempt.
    expect(service.lastSubmitTimedOut, isTrue);
  });

  testWidgets('the countdown ticking does not rebuild the question card', (tester) async {
    final service = _FakeAssessmentService();
    await _pumpQuiz(tester, service);

    final choice = find.text('mito');
    expect(choice, findsOneWidget);
    final elementBefore = tester.element(choice);

    // Several seconds of ticking must leave the question's element identical —
    // if the clock rebuilt the page, this would be a different Element.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(identical(tester.element(choice), elementBefore), isTrue);
  });
}
