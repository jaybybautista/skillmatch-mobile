import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/assessment.dart';
import 'package:skillmatch/screens/student/assessments/assessment_result_screen.dart';
import 'package:skillmatch/services/assessment_service.dart';

class _FakeAssessmentService extends AssessmentService {
  _FakeAssessmentService(this.result);

  final AssessmentAttemptResult result;

  @override
  Future<AssessmentAttemptResult> fetchResult(int assessmentId) async => result;
}

/// The payload the API sends while written answers are still with the company.
/// Score, percentage and passed are all null on purpose.
Map<String, dynamic> _underReviewJson({bool timedOut = false}) => {
  'assessment_title': 'Design Intern',
  'state': 'under_review',
  'pending_review': true,
  'show_score': false,
  'was_reviewed': false,
  'score': null,
  'total_points': 4,
  'percentage': null,
  'passed': null,
  'timed_out': timedOut,
  'company_name': 'AstraM',
  'review_counts': {'total': 4, 'auto_checked': 2, 'awaiting': 2},
  'review_details': <String>[],
  'headline': 'Your answers are being reviewed',
  'message': 'Your answers are being reviewed.',
};

Map<String, dynamic> _gradedJson({required bool passed, bool wasReviewed = false}) => {
  'assessment_title': 'Design Intern',
  'state': passed ? 'passed' : 'failed',
  'pending_review': false,
  'show_score': true,
  'was_reviewed': wasReviewed,
  'score': passed ? 3 : 1,
  'total_points': 4,
  'percentage': passed ? 75 : 25,
  'passed': passed,
  'timed_out': false,
  'company_name': 'AstraM',
  'review_counts': {'total': 4, 'auto_checked': 4, 'awaiting': 0},
  'review_details': <String>[],
  'headline': passed
      ? "You've passed the assessment"
      : "You didn't pass this time",
  'message': 'Recorded.',
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  final result = AssessmentAttemptResult.fromJson(json);

  await tester.pumpWidget(
    MaterialApp(
      home: AssessmentResultScreen(
        assessmentId: 1,
        service: _FakeAssessmentService(result),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('while the answers are still being reviewed', () {
    test('the model keeps the verdict empty rather than guessing', () {
      final result = AssessmentAttemptResult.fromJson(_underReviewJson());

      expect(result.isUnderReview, isTrue);
      expect(result.score, isNull);
      expect(result.percentage, isNull);
      expect(result.passed, isNull);
      expect(result.reviewCounts.awaiting, 2);
      expect(result.reviewCounts.autoChecked, 2);
    });

    testWidgets('no pass, no fail and no score reach the screen', (
      tester,
    ) async {
      await _pump(tester, _underReviewJson());

      expect(find.text('Your answers are being reviewed'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);

      // Wala talagang marka dito. Ito yung buong punto.
      expect(find.textContaining('You scored'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('passed'), findsNothing);
      expect(find.textContaining("didn't pass"), findsNothing);
    });

    testWidgets('it says what was settled and what is still owed', (
      tester,
    ) async {
      await _pump(tester, _underReviewJson());

      expect(
        find.textContaining('2 of 4 questions were checked automatically'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 written answers still need to be read by AstraM'),
        findsOneWidget,
      );
      expect(
        find.textContaining("We'll notify you as soon as your result is ready"),
        findsOneWidget,
      );
    });

    testWidgets('running out of time is still stated, since that part is certain', (
      tester,
    ) async {
      await _pump(tester, _underReviewJson(timedOut: true));

      expect(
        find.textContaining('will not count as a pass'),
        findsOneWidget,
      );
      // Pero wala pa ring marka. Yun ang hinihintay, hindi yung hatol sa oras.
      expect(find.textContaining('You scored'), findsNothing);
    });
  });

  group('once the review is done', () {
    testWidgets('the score and the verdict come back', (tester) async {
      await _pump(tester, _gradedJson(passed: true, wasReviewed: true));

      expect(find.text("You've passed the assessment"), findsOneWidget);
      expect(find.text('You scored 3 out of 4 points (75%)'), findsOneWidget);
      expect(find.text('Final score'), findsOneWidget);
      expect(find.text('Under review'), findsNothing);
    });

    testWidgets('an ordinary auto-graded attempt is unchanged', (tester) async {
      await _pump(tester, _gradedJson(passed: false));

      expect(find.text("You didn't pass this time"), findsOneWidget);
      expect(find.text('You scored 1 out of 4 points (25%)'), findsOneWidget);
      // Walang tao ang bumasa nito, kaya walang "Final score" na tanda.
      expect(find.text('Final score'), findsNothing);
      expect(find.text('Under review'), findsNothing);
    });
  });
}
