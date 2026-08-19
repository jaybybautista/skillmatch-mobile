import 'package:flutter/material.dart';

import '../../models/assessment.dart';

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

  final int id;
  final TextEditingController textController;
  final TextEditingController descriptionController;
  List<DraftOption> options;

  QuestionType type = QuestionType.multipleChoice;
  bool expanded = true;
  String? imagePath;

  /// The correct option for single-answer types (multiple choice, dropdown).
  int? correctOptionId;

  /// The correct options for [QuestionType.checkbox], where more than one
  /// answer can be right.
  Set<int> correctOptionIds = {};

  void dispose() {
    textController.dispose();
    descriptionController.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
