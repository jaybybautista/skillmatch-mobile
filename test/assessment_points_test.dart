import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/assessment.dart';
import 'package:skillmatch/models/assessment_answer_sheet.dart';
import 'package:skillmatch/models/company_assessment.dart';
import 'package:skillmatch/screens/company/assessment_draft.dart';

void main() {
  group('points on a draft question', () {
    test('a new question starts at one point', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      expect(question.points, 1);
      expect(question.toPayload()['points'], 1);
    });

    test('what the company typed is what gets sent', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.type = QuestionType.longAnswer;
      question.textController.text = 'Describe a project you led.';
      question.pointsController.text = '15';

      expect(question.points, 15);
      expect(question.toPayload()['points'], 15);
    });

    test('a blank or nonsense box falls back to one rather than blocking', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.pointsController.text = '';
      expect(question.points, 1);

      question.pointsController.text = 'abc';
      expect(question.points, 1);

      question.pointsController.text = '0';
      expect(question.points, 1);
    });

    test('the range is clamped the same way the server clamps it', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.pointsController.text = '-5';
      expect(question.points, 1);

      question.pointsController.text = '250';
      expect(question.points, 100);
    });

    test('reopening a saved question restores its points', () {
      final saved = CompanyAssessmentQuestion.fromJson({
        'id': 1,
        'question_text': 'Describe a project you led.',
        'question_type': 'long_answer',
        'points': 12,
        'choices': <Map<String, dynamic>>[],
      });

      final question = DraftQuestion.fromExisting(saved);
      addTearDown(question.dispose);

      expect(question.points, 12);
      expect(question.toPayload()['points'], 12);
    });

    test('a saved question with no points reads as one, not zero', () {
      final saved = CompanyAssessmentQuestion.fromJson({
        'id': 2,
        'question_text': 'Pick B',
        'question_type': 'multiple_choice',
        'choices': [
          {'id': 1, 'choice_text': 'A', 'is_correct': false},
          {'id': 2, 'choice_text': 'B', 'is_correct': true},
        ],
      });

      final question = DraftQuestion.fromExisting(saved);
      addTearDown(question.dispose);

      expect(question.points, 1);
    });
  });

  group('the answer sheet', () {
    test('carries the ceiling each answer was graded against', () {
      final sheet = AssessmentAnswerSheet.fromJson({
        'assessment': {'id': 1, 'title': 'Design Intern', 'total_points': 20},
        'result': {
          'id': 5,
          'score': 8,
          'total_points': 20,
          'pending_review': true,
        },
        'rows': [
          {
            'answer_id': 1,
            'question': {'question_text': 'Pick B', 'question_type': 'multiple_choice'},
            'points_awarded': 3,
            'points_possible': 3,
            'manual': false,
            'answered': true,
          },
          {
            'answer_id': 2,
            'question': {'question_text': 'Describe.', 'question_type': 'long_answer'},
            'points_awarded': 0,
            'points_possible': 15,
            'manual': true,
            'answered': true,
            'answer_text': 'I rebuilt the campus portal.',
          },
        ],
      });

      // Yung hangganan, hindi pare-pareho. Dito nakasalalay yung sinasabi sa
      // nagrerepaso kung hanggang saan siya pwedeng magbigay.
      expect(sheet.rows.first.pointsPossible, 3);
      expect(sheet.rows.last.pointsPossible, 15);
      expect(sheet.totalPoints, 20);

      // Tatlong-kapat ng buong papel ang sanaysay na ito.
      final share = (sheet.rows.last.pointsPossible / sheet.totalPoints) * 100;
      expect(share.round(), 75);
    });
  });
}
