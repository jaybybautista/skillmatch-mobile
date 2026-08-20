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
  };

  /// The value the API stores in `questions.question_type`.
  String get apiValue => switch (this) {
    QuestionType.multipleChoice => 'multiple_choice',
    QuestionType.checkbox => 'checkbox',
    QuestionType.dropdown => 'dropdown',
    QuestionType.identification => 'identification',
    QuestionType.shortAnswer => 'short_answer',
    QuestionType.longAnswer => 'long_answer',
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
      options = List.generate(4, (_) => DraftOption());

  /// Rebuilds a draft from an assessment already stored on the server, so
  /// editing starts from what is really saved rather than a blank form.
  DraftQuestion.fromExisting(CompanyAssessmentQuestion question)
    : id = _nextDraftId++,
      textController = TextEditingController(text: question.text),
      descriptionController = TextEditingController(
        text: question.description ?? '',
      ),
      options = question.choices
          .map((c) => DraftOption(text: c.text))
          .toList() {
    type = question.type;
    imageUrl = question.imageUrl;

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
    'choices': [
      for (final option in options)
        {'text': option.text, 'is_correct': isCorrect(option)},
    ],
  };

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
    for (final option in options) {
      option.dispose();
    }
  }
}
