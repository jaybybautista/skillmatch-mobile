import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/assessment.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/company_screen_header.dart';
import 'assessment_draft.dart';

/// The company's 2-step "Create Assessment" flow — Basic Info, Questions —
/// reached from [AssessmentLibraryScreen]'s "+" button.
///
/// TODO: not wired to the backend yet — there is no company-assessments
/// endpoint to save against (see `CompanyAssessment`), so "Save" just
/// confirms and returns to the library like every other unbuilt company
/// action.
class CreateAssessmentScreen extends StatefulWidget {
  const CreateAssessmentScreen({super.key});

  @override
  State<CreateAssessmentScreen> createState() => _CreateAssessmentScreenState();
}

class _CreateAssessmentScreenState extends State<CreateAssessmentScreen> {
  static const _totalSteps = 2;
  int _step = 1;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeLimitController = TextEditingController();

  final List<DraftQuestion> _questions = [DraftQuestion()];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeLimitController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(DraftQuestion()));

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _toggleExpanded(int index) {
    setState(() => _questions[index].expanded = !_questions[index].expanded);
  }

  void _setType(DraftQuestion question, QuestionType type) {
    setState(() {
      question.type = type;
      question.correctOptionId = null;
      question.correctOptionIds.clear();
    });
  }

  void _setCorrectOption(DraftQuestion question, int optionId) {
    setState(() => question.correctOptionId = optionId);
  }

  void _toggleCorrectOption(DraftQuestion question, int optionId) {
    setState(() {
      if (!question.correctOptionIds.remove(optionId)) {
        question.correctOptionIds.add(optionId);
      }
    });
  }

  Future<void> _pickImage(DraftQuestion question) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    setState(() => question.imagePath = path);
  }

  void _next() {
    if (_step == 1 && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the assessment a title first.')),
      );
      return;
    }
    if (_step < _totalSteps) {
      setState(() => _step++);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving assessments is coming soon.')),
    );
    Navigator.of(context).pop();
  }

  void _back() {
    if (_step == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: 'Create Assessment',
            onBack: _back,
            trailing: _step == 2
                ? IconButton(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                if (_step == 1)
                  _BasicInfoStep(
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                    timeLimitController: _timeLimitController,
                  )
                else
                  _QuestionsStep(
                    questions: _questions,
                    onToggleExpanded: _toggleExpanded,
                    onRemove: _removeQuestion,
                    onSetType: _setType,
                    onSetCorrectOption: _setCorrectOption,
                    onToggleCorrectOption: _toggleCorrectOption,
                    onPickImage: _pickImage,
                  ),
              ],
            ),
          ),
          _CreateAssessmentFooter(
            onNext: _next,
            nextLabel: _step == _totalSteps ? 'Save' : 'Next',
          ),
        ],
      ),
    );
  }
}

class _CreateAssessmentFooter extends StatelessWidget {
  const _CreateAssessmentFooter({required this.onNext, required this.nextLabel});

  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(nextLabel),
        ),
      ),
    );
  }
}

class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.titleController,
    required this.descriptionController,
    required this.timeLimitController,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController timeLimitController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldCard(
          label: 'ASSESSMENT TITLE',
          child: _GreyTextField(
            controller: titleController,
            hintText: 'e.g. Senior Frontend Engineer Screening',
          ),
        ),
        const SizedBox(height: 16),
        _FieldCard(
          label: 'DESCRIPTION',
          child: _GreyTextField(
            controller: descriptionController,
            hintText: 'Outline the goals of this assessment, required skills, and what the candidate can expect…',
            minLines: 3,
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Time Limit', style: AppFonts.title(fontSize: 16)),
                  const SizedBox(height: 2),
                  const Text(
                    'Define how time pressure is applied to your candidates to ensure fair and accurate results.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: timeLimitController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '00',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MINUTES',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionsStep extends StatelessWidget {
  const _QuestionsStep({
    required this.questions,
    required this.onToggleExpanded,
    required this.onRemove,
    required this.onSetType,
    required this.onSetCorrectOption,
    required this.onToggleCorrectOption,
    required this.onPickImage,
  });

  final List<DraftQuestion> questions;
  final void Function(int index) onToggleExpanded;
  final void Function(int index) onRemove;
  final void Function(DraftQuestion question, QuestionType type) onSetType;
  final void Function(DraftQuestion question, int optionId) onSetCorrectOption;
  final void Function(DraftQuestion question, int optionId) onToggleCorrectOption;
  final void Function(DraftQuestion question) onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < questions.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == questions.length - 1 ? 0 : 16),
            child: _QuestionCard(
              index: i,
              question: questions[i],
              onToggleExpanded: () => onToggleExpanded(i),
              onRemove: questions.length > 1 ? () => onRemove(i) : null,
              onSetType: (type) => onSetType(questions[i], type),
              onSetCorrectOption: (optionId) => onSetCorrectOption(questions[i], optionId),
              onToggleCorrectOption: (optionId) => onToggleCorrectOption(questions[i], optionId),
              onPickImage: () => onPickImage(questions[i]),
            ),
          ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onToggleExpanded,
    required this.onRemove,
    required this.onSetType,
    required this.onSetCorrectOption,
    required this.onToggleCorrectOption,
    required this.onPickImage,
  });

  final int index;
  final DraftQuestion question;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onRemove;
  final void Function(QuestionType type) onSetType;
  final void Function(int optionId) onSetCorrectOption;
  final void Function(int optionId) onToggleCorrectOption;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(6),
                child: Icon(
                  question.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Question ${index + 1}', style: AppFonts.title(fontSize: 15)),
                    const SizedBox(height: 2),
                    PopupMenuButton<QuestionType>(
                      padding: EdgeInsets.zero,
                      onSelected: onSetType,
                      itemBuilder: (context) => [
                        const PopupMenuItem(enabled: false, child: Text('Select type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted))),
                        for (final type in const [QuestionType.multipleChoice, QuestionType.checkbox, QuestionType.dropdown])
                          PopupMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  type == question.type ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: type == question.type ? AppColors.primary : AppColors.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Text(type.label),
                              ],
                            ),
                          ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            question.type.label.toUpperCase(),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                ),
            ],
          ),
          if (question.expanded) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Question'),
            const SizedBox(height: 6),
            _GreyTextField(controller: question.textController, hintText: 'Type here your question'),
            const SizedBox(height: 14),
            const _FieldLabel('Description (Optional)'),
            const SizedBox(height: 6),
            _GreyTextField(controller: question.descriptionController, hintText: 'Type here your description'),
            const SizedBox(height: 10),
            InkWell(
              onTap: onPickImage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    question.imagePath == null ? 'Add Inline Image' : 'Change Inline Image',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (question.imagePath != null) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(question.imagePath!), height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => onPickImage.call(),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (question.type == QuestionType.checkbox)
              for (var i = 0; i < question.options.length; i++) ...[
                _FieldLabel('Option ${String.fromCharCode(65 + i)}'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: question.correctOptionIds.contains(question.options[i].id),
                      onChanged: (_) => onToggleCorrectOption(question.options[i].id),
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: _GreyTextField(controller: question.options[i].controller, hintText: 'Add answer…'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ]
            else
              RadioGroup<int>(
                groupValue: question.correctOptionId,
                onChanged: (value) => onSetCorrectOption(value!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < question.options.length; i++) ...[
                      _FieldLabel('Option ${String.fromCharCode(65 + i)}'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Radio<int>(value: question.options[i].id, activeColor: AppColors.primary),
                          Expanded(
                            child: _GreyTextField(controller: question.options[i].controller, hintText: 'Add answer…'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            if (question.type != QuestionType.checkbox) ...[
              const SizedBox(height: 4),
              AppDropdownField<int>(
                label: 'Answer',
                value: question.correctOptionId,
                items: [for (final option in question.options) option.id],
                itemLabel: (id) => 'Option ${String.fromCharCode(65 + question.options.indexWhere((o) => o.id == id))}',
                hint: 'Select the correct answer',
                onChanged: (value) => onSetCorrectOption(value!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.4),
    );
  }
}

class _GreyTextField extends StatelessWidget {
  const _GreyTextField({
    required this.controller,
    required this.hintText,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
