import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/app_theme.dart';
import 'package:skillmatch/models/assessment.dart';
import 'package:skillmatch/models/assessment_answer_sheet.dart';
import 'package:skillmatch/models/company_assessment.dart';
import 'package:skillmatch/screens/company/assessment_draft.dart';
import 'package:skillmatch/widgets/code_viewer.dart';

const _snippet = 'nums = [1, 2, 3]\ntotal = 0\nfor n in nums:\n'
    '    total += n * 2\nprint(total)';

const _pythonBadge = {
  'slug': 'python',
  'label': 'Python',
  'mono': 'Py',
  'color': '#3776AB',
  'kind': 'language',
  'icon': 'http://localhost/devicon/python.svg',
};

// Walang logo ang SQL sa Devicon, kaya walang icon ang ipinapadala ng server.
const _sqlBadge = {
  'slug': 'sql',
  'label': 'SQL',
  'mono': 'SQ',
  'color': '#E38C00',
  'kind': 'language',
  'icon': null,
};

void main() {
  group('the question type itself', () {
    test('code_tracing is recognised, not quietly turned into a choice one', () {
      expect(QuestionType.parse('code_tracing'), QuestionType.codeTracing);
      expect(QuestionType.codeTracing.isCodeTracing, isTrue);
      expect(QuestionType.codeTracing.apiValue, 'code_tracing');
      expect(QuestionType.codeTracing.label, 'Code Tracing');
    });

    test('it counts as free text, so the quiz makes it a typing box', () {
      expect(QuestionType.codeTracing.isFreeText, isTrue);
      expect(QuestionType.codeTracing.isMultiSelect, isFalse);
    });
  });

  group('what the student receives', () {
    test('the code and the badge arrive, the answer key does not', () {
      final question = AssessmentQuestion.fromJson({
        'id': 7,
        'question_text': 'What does this print?',
        'question_type': 'code_tracing',
        'points': 5,
        'language': _pythonBadge,
        'source_code': _snippet,
        'choices': <Map<String, dynamic>>[],
      });

      expect(question.type, QuestionType.codeTracing);
      expect(question.sourceCode, _snippet);
      expect(question.language?.label, 'Python');
      expect(question.language?.color, '#3776AB');
      expect(question.choices, isEmpty);
    });

    test('a missing badge falls back to plain text instead of crashing', () {
      final question = AssessmentQuestion.fromJson({
        'id': 8,
        'question_text': 'What does this print?',
        'question_type': 'code_tracing',
        'points': 1,
        'source_code': 'print(1)',
        'choices': <Map<String, dynamic>>[],
      });

      expect(question.language, isNull);
      expect(LanguageBadge.plain.label, 'Plain text');
    });
  });

  group('authoring one', () {
    test('the payload carries the language, the code and the key', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.type = QuestionType.codeTracing;
      question.textController.text = 'What does this print?';
      question.languageSlug = 'python';
      question.sourceCodeController.text = _snippet;
      question.expectedOutputController.text = '12';
      question.pointsController.text = '5';

      final payload = question.toPayload();

      expect(payload['type'], 'code_tracing');
      expect(payload['language'], 'python');
      expect(payload['source_code'], _snippet);
      expect(payload['expected_output'], '12');
      expect(payload['points'], 5);
      expect(payload['choices'], isEmpty);
      // Sarili nitong susi ang gamit, hindi yung answer key ng sulat na sagot.
      expect(payload.containsKey('answer_key'), isFalse);
    });

    test('it says what is missing before the trip to the server', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.type = QuestionType.codeTracing;
      question.textController.text = 'What does this print?';

      expect(question.tracingProblem, contains('the code'));

      question.sourceCodeController.text = _snippet;
      expect(question.tracingProblem, contains('the output'));

      question.expectedOutputController.text = '12';
      expect(question.tracingProblem, isNull);
    });

    test('a question of another type is never held back by that check', () {
      final question = DraftQuestion();
      addTearDown(question.dispose);

      question.type = QuestionType.multipleChoice;
      expect(question.tracingProblem, isNull);
    });

    test('reopening a saved one restores the code, the key and the badge', () {
      final saved = CompanyAssessmentQuestion.fromJson({
        'id': 3,
        'question_text': 'What does this print?',
        'question_type': 'code_tracing',
        'points': 5,
        'language': 'python',
        'language_badge': _pythonBadge,
        'source_code': _snippet,
        'expected_output': '12',
        'choices': <Map<String, dynamic>>[],
      });

      final question = DraftQuestion.fromExisting(saved);
      addTearDown(question.dispose);

      expect(question.type, QuestionType.codeTracing);
      expect(question.languageSlug, 'python');
      expect(question.languageBadge?.label, 'Python');
      expect(question.sourceCodeController.text, _snippet);
      expect(question.expectedOutputController.text, '12');
      expect(question.tracingProblem, isNull);
    });
  });

  group('the answer sheet row', () {
    test('it carries the snippet and both outputs', () {
      final row = AnswerSheetRow.fromJson({
        'question_id': 3,
        'question_text': 'What does this print?',
        'question_type': 'code_tracing',
        'manual': false,
        'answered': true,
        'is_correct': false,
        'points_awarded': 0,
        'points_possible': 5,
        'answer_text': '6',
        'language_badge': _pythonBadge,
        'source_code': _snippet,
        'expected_output': '12',
      });

      expect(row.isCodeTracing, isTrue);
      // Kusa itong nakikilala, kaya walang taong nagbibigay ng puntos dito.
      expect(row.manual, isFalse);
      expect(row.answerText, '6');
      expect(row.expectedOutput, '12');
      expect(row.languageBadge?.mono, 'Py');
    });
  });

  group('the language badge', () {
    test('it picks up whether the server has a logo for this one', () {
      expect(LanguageBadge.fromJson(_pythonBadge).hasIcon, isTrue);
      expect(LanguageBadge.fromJson(_sqlBadge).hasIcon, isFalse);
      expect(LanguageBadge.plain.hasIcon, isFalse);
    });
  });

  group('the code viewer', () {
    testWidgets('numbers every line and shows the code as written', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeViewer(
              badge: LanguageBadge.fromJson(_pythonBadge),
              code: _snippet,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('1\n2\n3\n4\n5'), findsOneWidget);
      expect(find.text(_snippet), findsOneWidget);
    });

    testWidgets('a language with a logo draws the logo, not the letters', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeViewer(
              badge: LanguageBadge.fromJson(_pythonBadge),
              code: 'print(1)',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Py'), findsNothing);
    });

    testWidgets('one without a logo falls back to the coloured letters', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeViewer(
              badge: LanguageBadge.fromJson(_sqlBadge),
              code: 'SELECT 1;',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SQ'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('a language the app has no logo file for still shows a mark', (
      tester,
    ) async {
      // Naidagdag sa server pero wala pang kopya ng logo dito sa app. Hindi
      // ito dapat magbunga ng blangkong tanda.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeViewer(
              badge: LanguageBadge.fromJson(const {
                'slug': 'brandnewlang',
                'label': 'Brand New',
                'mono': 'BN',
                'color': '#3776AB',
                'kind': 'language',
                'icon': 'http://localhost/devicon/brandnewlang.svg',
              }),
              code: 'print(1)',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BN'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('a long line scrolls sideways instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeViewer(
              badge: LanguageBadge.plain,
              code:
                  'print("${'x' * 400}")\nprint("short")',
            ),
          ),
        ),
      );

      // Bumabagsak ang test pag may umapaw, kaya sapat na ang malinis na pump.
      expect(tester.takeException(), isNull);
      expect(find.text('1\n2'), findsOneWidget);
    });

    testWidgets('the typing boxes stay dark under the app-wide theme', (
      tester,
    ) async {
      // Puti ang itinatakda ng inputDecorationTheme ng app para sa lahat ng
      // TextField. Kung susundin yun ng basahan ng code, magiging puti ang
      // loob nito at halos hindi na mabasa ang maputlang letra doon. Kaya
      // sinasabi na ng CodeField ang sarili niyang likod.
      final code = TextEditingController();
      final output = TextEditingController();
      addTearDown(code.dispose);
      addTearDown(output.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                CodeField(controller: code, gutter: true),
                CodeField(controller: output),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final fills = fields.map((f) => f.decoration?.fillColor).toList();

      expect(fills, [CodeColors.shell, CodeColors.output]);
      for (final field in fields) {
        expect(field.decoration?.filled, isTrue);
        expect(field.style?.color, CodeColors.code);
      }

      // Yung likod na ipininta ng Container, kasingkulay rin dapat - kung
      // hindi, may guhit na ibang kulay sa gilid ng kahon.
      final shells = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == CodeColors.shell || c.color == CodeColors.output)
          .toList();
      expect(shells, isNotEmpty);
    });

    test('the tile ink flips so a light brand colour stays readable', () {
      // Dilaw ang JavaScript. Puting letra dito, nawawala.
      expect(inkOn(colorFromHex('#F7DF1E')), const Color(0xFF12161F));
      expect(inkOn(colorFromHex('#3776AB')), const Color(0xFFFFFFFF));
    });

    test('a broken hex falls back to grey rather than throwing', () {
      expect(colorFromHex('nope'), const Color(0xFF6B7A99));
      expect(colorFromHex('#3776AB'), const Color(0xFF3776AB));
    });
  });
}
