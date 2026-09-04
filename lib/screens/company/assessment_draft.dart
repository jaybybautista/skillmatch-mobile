import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/assessment.dart';
import '../../models/company_assessment.dart';

int _nextDraftId = 0;

/// Display label for the three question types a company can currently
/// author (see [QuestionType]'s own doc comment).
extension QuestionTypeLabel on QuestionType {
  String get label => switch (this) {
    QuestionType.multipleChoice => 'Multiple Choice',
    QuestionType.checkbox => 'Checkboxes',
    QuestionType.dropdown => 'Dropdown',
    QuestionType.identification => 'Identification',
    QuestionType.shortAnswer => 'Short Answer',
    QuestionType.longAnswer => 'Long Answer',
    QuestionType.codeTracing => 'Code Tracing',
  };

  /// The value the API stores in `questions.question_type`.
  String get apiValue => switch (this) {
    QuestionType.multipleChoice => 'multiple_choice',
    QuestionType.checkbox => 'checkbox',
    QuestionType.dropdown => 'dropdown',
    QuestionType.identification => 'identification',
    QuestionType.shortAnswer => 'short_answer',
    QuestionType.longAnswer => 'long_answer',
    QuestionType.codeTracing => 'code_tracing',
  };
}

/// One answer option being authored in [CreateAssessmentScreen]'s question
/// builder. Holds its own controller so option text survives rebuilds and
/// question reordering without losing cursor/focus state.
class DraftOption {
  DraftOption({String text = ''})
    : id = _nextDraftId++,
      controller = TextEditingController(text: text);

  final int id;
  final TextEditingController controller;

  String get text => controller.text.trim();

  void dispose() => controller.dispose();
}

/// One question being authored in [CreateAssessmentScreen]'s question
/// builder — the local, editable counterpart to the read-only
/// [AssessmentQuestion] the student side receives.
class DraftQuestion {
  DraftQuestion()
    : id = _nextDraftId++,
      textController = TextEditingController(),
      descriptionController = TextEditingController(),
      answerKeyController = TextEditingController(),
      pointsController = TextEditingController(text: '1'),
      sourceCodeController = TextEditingController(),
      expectedOutputController = TextEditingController(),
      options = List.generate(4, (_) => DraftOption());

  /// Rebuilds a draft from an assessment already stored on the server, so
  /// editing starts from what is really saved rather than a blank form.
  DraftQuestion.fromExisting(CompanyAssessmentQuestion question)
    : id = _nextDraftId++,
      textController = TextEditingController(text: question.text),
      descriptionController = TextEditingController(
        text: question.description ?? '',
      ),
      // A written question keeps its answer key in the single choice flagged
      // correct, which is where the web builder reads it back from as well.
      pointsController = TextEditingController(
        text: (question.points > 0 ? question.points : 1).toString(),
      ),
      answerKeyController = TextEditingController(
        text: question.type.isFreeText
            ? (question.choices
                      .where((c) => c.isCorrect)
                      .map((c) => c.text)
                      .firstOrNull ??
                  '')
            : '',
      ),
      sourceCodeController = TextEditingController(
        text: question.sourceCode ?? '',
      ),
      expectedOutputController = TextEditingController(
        text: question.expectedOutput ?? '',
      ),
      options = question.choices
          .map((c) => DraftOption(text: c.text))
          .toList() {
    type = question.type;
    imageUrl = question.imageUrl;
    languageSlug = question.language;
    languageBadge = question.languageBadge;

    // The four blank option slots a fresh question starts with are a UI
    // default, not a rule — a stored question keeps however many it has, and
    // is topped up only if it somehow has fewer than the two the server
    // requires.
    while (options.length < 2) {
      options.add(DraftOption());
    }

    for (var i = 0; i < question.choices.length && i < options.length; i++) {
      if (!question.choices[i].isCorrect) continue;
      if (question.type.isMultiSelect) {
        correctOptionIds.add(options[i].id);
      } else {
        correctOptionId ??= options[i].id;
      }
    }
  }

  final int id;
  final TextEditingController textController;
  final TextEditingController descriptionController;

  /// The expected answer for a written question. Leaving it empty is a
  /// deliberate choice, not an omission: the question is then flagged for
  /// review and the company scores it by hand from the answer sheet.
  final TextEditingController answerKeyController;

  /// What this question is worth. An essay is usually worth more than a
  /// multiple choice, and the number set here becomes the ceiling the grader
  /// scores against on the answer sheet.
  final TextEditingController pointsController;

  /// Code tracing lang gumagamit ng dalawang ito. Yung code na babasahin ng
  /// estudyante, at yung dapat lumabas pag pinatakbo ito - yun ang susi.
  final TextEditingController sourceCodeController;
  final TextEditingController expectedOutputController;

  /// Aling wika ang nakadikit sa code. Slug lang ito, gaya ng python o cpp -
  /// yung pangalan at kulay, sa server na nanggagaling.
  String? languageSlug;

  /// Yung tanda na ipinapakita habang pinipili. Itinatabi ito para hindi na
  /// kailangang tumawag ulit sa server para lang malaman kung ano ang kulay
  /// ng napili niya.
  LanguageBadge? languageBadge;

  /// The points as a number, kept inside the range the server accepts so a
  /// blank or nonsense box never blocks saving.
  int get points {
    final parsed = int.tryParse(pointsController.text.trim()) ?? 1;
    if (parsed < 1) return 1;
    return parsed > 100 ? 100 : parsed;
  }

  List<DraftOption> options;

  QuestionType type = QuestionType.multipleChoice;
  bool expanded = true;

  /// A newly picked image on this device, not yet uploaded.
  String? imagePath;

  /// The image already stored on the server — an `http(s)` URL or an inline
  /// `data:` URI. Replaced by [imagePath] once a new one is picked.
  String? imageUrl;

  /// The correct option for single-answer types (multiple choice, dropdown).
  int? correctOptionId;

  /// The correct options for [QuestionType.checkbox], where more than one
  /// answer can be right.
  Set<int> correctOptionIds = {};

  bool get hasImage =>
      imagePath != null || (imageUrl != null && imageUrl!.isNotEmpty);

  bool isCorrect(DraftOption option) => type.isMultiSelect
      ? correctOptionIds.contains(option.id)
      : correctOptionId == option.id;

  /// The payload shape the API expects — identical to what the web builder
  /// posts, since one shared service parses both.
  ///
  /// Blank options are left in deliberately: the server drops them, and doing
  /// the same filtering here as well would just be a second place to keep in
  /// step.
  Map<String, dynamic> toPayload() => {
    'type': type.apiValue,
    'question_text': textController.text.trim(),
    'description': descriptionController.text.trim(),
    'image_url': _imagePayload() ?? '',
    'points': points,
    // A written question has no options — the shared service turns the
    // answer key into the one correct choice, or marks the question for
    // manual review when it is blank.
    //
    // Hindi kasama dito ang code tracing kahit teksto rin ang sagot nito. May
    // sarili itong tatlong field sa ibaba, at doon nakalagay ang susi.
    if (type.isFreeText && !type.isCodeTracing)
      'answer_key': answerKeyController.text.trim(),
    if (type.isCodeTracing) ...{
      'language': languageSlug ?? '',
      'source_code': sourceCodeController.text,
      'expected_output': expectedOutputController.text,
    },
    'choices': type.isFreeText
        ? const []
        : [
            for (final option in options)
              {'text': option.text, 'is_correct': isCorrect(option)},
          ],
  };

  /// Ano ang kulang sa code tracing na tanong na ito, kung meron man.
  ///
  /// Tinatanong ito bago pa ipadala. Tinatanggihan din naman ito ng server,
  /// pero mas mabuting sabihin agad kaysa hintayin pa ang biyahe - lalo na
  /// pag mahaba na ang papel at malayo na siyang nag-scroll.
  String? get tracingProblem {
    if (!type.isCodeTracing) return null;

    if (sourceCodeController.text.trim().isEmpty) {
      return 'needs the code the student will trace';
    }

    if (expectedOutputController.text.trim().isEmpty) {
      return 'needs the output that code produces, which is the answer key';
    }

    return null;
  }

  /// A newly picked file is inlined as a `data:` URI, which is exactly what
  /// the web builder stores for an inline image — so the student quiz renders
  /// it the same either way, with no upload endpoint or file cleanup needed.
  String? _imagePayload() {
    final path = imagePath;
    if (path == null) return imageUrl;

    try {
      final bytes = File(path).readAsBytesSync();
      final dot = path.lastIndexOf('.');
      final extension = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
      final mime = switch (extension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } on FileSystemException {
      // The picked file vanished between choosing and saving — keep whatever
      // was already stored rather than losing the question over it.
      return imageUrl;
    }
  }

  void dispose() {
    textController.dispose();
    descriptionController.dispose();
    pointsController.dispose();
    answerKeyController.dispose();
    sourceCodeController.dispose();
    expectedOutputController.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
