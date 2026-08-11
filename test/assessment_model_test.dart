import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/application.dart';
import 'package:skillmatch/models/assessment.dart';

void main() {
  group('QuestionType', () {
    test('maps every type the backend can send', () {
      expect(QuestionType.parse('multiple_choice'), QuestionType.multipleChoice);
      expect(QuestionType.parse('checkbox'), QuestionType.checkbox);
      expect(QuestionType.parse('dropdown'), QuestionType.dropdown);
      expect(QuestionType.parse('identification'), QuestionType.identification);
      expect(QuestionType.parse('short_answer'), QuestionType.shortAnswer);
      expect(QuestionType.parse('long_answer'), QuestionType.longAnswer);
    });

    test('falls back to multiple choice for anything unrecognised', () {
      // A type added on the web later must still render as something usable
      // rather than crashing the quiz.
      expect(QuestionType.parse('something_new'), QuestionType.multipleChoice);
      expect(QuestionType.parse(null), QuestionType.multipleChoice);
    });

    test('flags free-text and multi-select types', () {
      expect(QuestionType.shortAnswer.isFreeText, isTrue);
      expect(QuestionType.longAnswer.isFreeText, isTrue);
      expect(QuestionType.multipleChoice.isFreeText, isFalse);

      expect(QuestionType.checkbox.isMultiSelect, isTrue);
      expect(QuestionType.dropdown.isMultiSelect, isFalse);
    });
  });

  group('AssessmentQuiz.fromJson', () {
    test('parses questions, choices and an inline image', () {
      final quiz = AssessmentQuiz.fromJson({
        'assessment': {'id': 1, 'title': 'Design Intern', 'time_limit': 5},
        'questions': [
          {
            'id': 7,
            'question_text': 'Powerhouse of the cell',
            'description': 'displayed photo',
            'question_type': 'multiple_choice',
            'points': 3,
            'image_url': 'data:image/png;base64,AAAA',
            'choices': [
              {'id': 11, 'choice_text': 'mito'},
              {'id': 12, 'choice_text': 'hehe'},
            ],
          },
        ],
      });

      expect(quiz.id, 1);
      expect(quiz.title, 'Design Intern');
      expect(quiz.timeLimitMinutes, 5);
      expect(quiz.questions, hasLength(1));

      final question = quiz.questions.single;
      expect(question.id, 7);
      expect(question.description, 'displayed photo');
      expect(question.points, 3);
      expect(question.type, QuestionType.multipleChoice);
      expect(question.imageUrl, startsWith('data:image/png'));
      expect(question.choices.map((c) => c.text), ['mito', 'hehe']);
    });

    test('handles an untimed assessment and a question with no points set', () {
      final quiz = AssessmentQuiz.fromJson({
        'assessment': {'id': 2, 'title': 'Untimed', 'time_limit': null},
        'questions': [
          {'id': 1, 'question_text': 'Q', 'question_type': 'checkbox', 'choices': []},
        ],
      });

      expect(quiz.timeLimitMinutes, isNull);
      // The backend scores a missing/zero points value as 1, so the app shows 1.
      expect(quiz.questions.single.points, 1);
      expect(quiz.questions.single.choices, isEmpty);
    });
  });

  group('AssessmentIntro', () {
    test('parses the payload and joins company with location', () {
      final intro = AssessmentIntro.fromJson({
        'assessment': {
          'id': 1,
          'title': 'Design Intern',
          'company_name': 'Creatix Studio',
          'location': 'New York, NY',
          'question_count': 13,
          'total_points': 130,
          'time_limit': 75,
        },
        'instructions': ['One', 'Two'],
        'already_completed': false,
      });

      expect(intro.subtitle, 'Creatix Studio · New York, NY');
      expect(intro.questionCount, 13);
      expect(intro.totalPoints, 130);
      expect(intro.instructions, ['One', 'Two']);
      expect(intro.alreadyCompleted, isFalse);
    });

    test('drops the separator when the internship has no location', () {
      final intro = AssessmentIntro.fromJson({
        'assessment': {'id': 1, 'title': 'T', 'company_name': 'Acme', 'location': null},
        'instructions': const [],
        'already_completed': true,
      });

      expect(intro.subtitle, 'Acme');
      expect(intro.alreadyCompleted, isTrue);
    });
  });

  group('retake', () {
    test('intro carries the retake flag and past attempts', () {
      final intro = AssessmentIntro.fromJson({
        'assessment': {'id': 1, 'title': 'T', 'company_name': 'Acme'},
        'instructions': const [],
        'already_completed': false,
        'is_retake': true,
        'attempt_history': [
          {
            'score': 1,
            'total_points': 1,
            'percentage': 100,
            'passed': true,
            'submitted_at_label': 'Aug 11, 2026 9:59 AM',
            'is_current': false,
          },
        ],
      });

      expect(intro.isRetake, isTrue);
      expect(intro.alreadyCompleted, isFalse);
      expect(intro.attemptHistory, hasLength(1));
      // Attempts from before the reassignment get the explanatory label.
      expect(intro.attemptHistory.single.isCurrent, isFalse);
      expect(intro.attemptHistory.single.passed, isTrue);
    });

    test('an application flags a reassignment for the green retake button', () {
      final reassigned = ApplicationSummary.fromJson({
        'id': 4,
        'has_pending_assessment': true,
        'is_reassignment': true,
        'assessment_id': 1,
      });
      expect(reassigned.isReassignment, isTrue);
      expect(reassigned.hasPendingAssessment, isTrue);

      // A first-time assignment must not turn green.
      final firstTime = ApplicationSummary.fromJson({
        'id': 5,
        'has_pending_assessment': true,
        'assessment_id': 1,
      });
      expect(firstTime.isReassignment, isFalse);
    });

    test('the green banner takes precedence over the blue one', () {
      final result = ApplicationsResult.fromJson({
        'applications': const [],
        'has_reassignment': true,
        'has_new_assessment': false,
      });

      expect(result.hasReassignment, isTrue);
      expect(result.hasNewAssessment, isFalse);
    });

    test('banner flags default to false when the payload omits them', () {
      // Guards against a half-updated backend (or a cached response) leaving
      // the banner flags null and blowing up the build.
      final result = ApplicationsResult.fromJson({'applications': const []});

      expect(result.hasReassignment, isFalse);
      expect(result.hasNewAssessment, isFalse);
    });
  });

  group('ApplicationsStatusSnapshot', () {
    test('keys applications by id so a poll can diff them', () {
      final snapshot = ApplicationsStatusSnapshot.fromJson({
        'applications': [
          {
            'id': 4,
            'internship_title': 'Product Design Intern',
            'status': 'interview',
            'has_pending_assessment': true,
            'is_reassignment': true,
          },
        ],
        'pending_assessments': 1,
        'reassigned_assessments': 1,
      });

      expect(snapshot.statuses.keys, [4]);
      expect(snapshot.statuses[4]!.status, 'interview');
      expect(snapshot.statuses[4]!.isReassignment, isTrue);
      expect(snapshot.pendingAssessments, 1);
      expect(snapshot.reassignedAssessments, 1);
    });
  });

  group('AssessmentAttemptResult', () {
    test('carries the score and the pass/fail copy the API decided on', () {
      final result = AssessmentAttemptResult.fromJson({
        'assessment_title': 'Design Intern',
        'score': 24,
        'total_points': 25,
        'percentage': 96,
        'passed': true,
        'headline': "You've passed the assessment",
        'message': 'Great work!',
        'submitted_at': '2026-08-11T09:59:27+00:00',
      });

      expect(result.score, 24);
      expect(result.totalPoints, 25);
      expect(result.percentage, 96);
      expect(result.passed, isTrue);
      expect(result.headline, "You've passed the assessment");
    });
  });
}
