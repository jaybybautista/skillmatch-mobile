import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../models/assessment.dart';
import '../../models/company_assessment.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/company_screen_header.dart';
import 'assessment_draft.dart';

/// The company's 2-step "Create Assessment" flow — Details, then Questions —
/// reached from [AssessmentLibraryScreen]'s "+" button, and reused for
/// editing when [existing] is supplied.
///
/// Both steps write through /api/company/assessments, which shares
/// CompanyAssessmentService with the website's builder: step 1 creates the
/// assessment as a draft, step 2 replaces its questions and publishes it —
/// the same two-phase save the web does, so an assessment half-built on the
/// phone can be finished in the browser.
class CreateAssessmentScreen extends StatefulWidget {
  const CreateAssessmentScreen({
    super.key,
    this.postings,
    this.existing,
    this.service,
  });

  /// The open postings an assessment can screen for. The backend requires
  /// one, and only open postings are offered — same as the web dropdown.
  ///
  /// Null when the caller hasn't already loaded them (the home screen's
  /// shortcut), in which case this screen fetches them itself.
  final List<AssessmentPostingOption>? postings;

  /// Supplied when editing rather than creating.
  final CompanyAssessment? existing;

  final CompanyAssessmentService? service;

  @override
  State<CreateAssessmentScreen> createState() => _CreateAssessmentScreenState();
}

class _CreateAssessmentScreenState extends State<CreateAssessmentScreen> {
  static const _totalSteps = 2;

  late final CompanyAssessmentService _service =
      widget.service ?? CompanyAssessmentService();

  int _step = 1;
  bool _isSaving = false;

  /// True once step 1 has been written to the server. From then on the
  /// assessment exists as a draft and step 1 edits become updates.
  int? _assessmentId;

  int? _internshipId;
  late List<AssessmentPostingOption> _postings = widget.postings ?? const [];
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeLimitController = TextEditingController();

  final List<DraftQuestion> _questions = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _assessmentId = existing.id;
      _internshipId = existing.internshipId;
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _timeLimitController.text = existing.timeLimitMinutes?.toString() ?? '';
    }

    _preselectSinglePosting();

    if (widget.postings == null) {
      _loadPostings();
    }

    if (_isEditing) {
      // The library card carries no questions, so the paper is fetched in
      // full before step 2 can show anything to edit.
      _loadExistingQuestions();
    } else {
      _questions.add(DraftQuestion());
    }
  }

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

  /// A single posting is not a choice — preselect it so the picker is one
  /// less thing to tap through.
  void _preselectSinglePosting() {
    _internshipId ??= _postings.length == 1 ? _postings.first.id : null;
  }

  /// Only runs for callers that didn't already have the list to hand.
  Future<void> _loadPostings() async {
    try {
      final library = await _service.fetchLibrary();
      if (!mounted) return;
      setState(() {
        _postings = library.postingOptions;
        _preselectSinglePosting();
      });
    } catch (e) {
      if (!mounted) return;
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _loadExistingQuestions() async {
    try {
      final full = await _service.fetchAssessment(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        for (final question in _questions) {
          question.dispose();
        }
        _questions
          ..clear()
          ..addAll(full.questions.map(DraftQuestion.fromExisting));
        if (_questions.isEmpty) _questions.add(DraftQuestion());
      });
    } catch (e) {
      if (!mounted) return;
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
      setState(() {
        if (_questions.isEmpty) _questions.add(DraftQuestion());
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addQuestion() => setState(() => _questions.add(DraftQuestion()));

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _addOption(DraftQuestion question) {
    setState(() => question.options.add(DraftOption()));
  }

  void _removeOption(DraftQuestion question, DraftOption option) {
    setState(() {
      question.options.remove(option);
      question.correctOptionIds.remove(option.id);
      if (question.correctOptionId == option.id) {
        question.correctOptionId = null;
      }
      option.dispose();
    });
  }

  void _toggleExpanded(int index) {
    setState(() => _questions[index].expanded = !_questions[index].expanded);
  }

  void _setType(DraftQuestion question, QuestionType type) {
    setState(() {
      question.type = type;
      // The two answer models aren't interchangeable, so switching type
      // clears whatever was ticked rather than half-carrying it over.
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

  void _clearImage(DraftQuestion question) {
    setState(() {
      question.imagePath = null;
      question.imageUrl = null;
    });
  }

  /// Step 1 → step 2. Writes the details first, so the assessment exists as a
  /// draft before any question is authored — exactly the web's order.
  Future<void> _saveDetailsAndContinue() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _notify('Give the assessment a title first.');
      return;
    }
    if (_internshipId == null) {
      _notify('Choose which posting this assessment screens for.');
      return;
    }

    final rawLimit = _timeLimitController.text.trim();
    final timeLimit = rawLimit.isEmpty ? null : int.tryParse(rawLimit);
    if (rawLimit.isNotEmpty &&
        (timeLimit == null || timeLimit < 1 || timeLimit > 480)) {
      // Mirrors the server's own bounds so the user is told here rather than
      // after a round trip.
      _notify('A time limit must be between 1 and 480 minutes.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final description = _descriptionController.text.trim();
      final saved = _assessmentId == null
          ? await _service.createAssessment(
              internshipId: _internshipId!,
              title: title,
              description: description.isEmpty ? null : description,
              timeLimitMinutes: timeLimit,
            )
          : await _service.updateAssessment(
              id: _assessmentId!,
              internshipId: _internshipId!,
              title: title,
              description: description.isEmpty ? null : description,
              timeLimitMinutes: timeLimit,
            );

      if (!mounted) return;
      setState(() {
        _assessmentId = saved.id;
        _step = 2;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  /// Step 2. Replaces the whole paper and publishes it.
  Future<void> _saveQuestions() async {
    if (_assessmentId == null) return;

    if (_questions.every((q) => q.textController.text.trim().isEmpty)) {
      _notify('Add at least one question before saving.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.saveQuestions(
        id: _assessmentId!,
        questions: _questions.map((q) => q.toPayload()).toList(),
      );
      if (!mounted) return;
      _notify('Assessment saved successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      // The server names the offending question ("Question 2 needs at least
      // 2 non-empty answer options"), so its message is shown as-is.
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  void _back() {
    if (_step == 1) {
      // Step 1 already wrote a draft when editing, and popping true makes the
      // library refresh so a title change shows up straight away.
      Navigator.of(context).maybePop(_isEditing);
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
            title: _isEditing ? 'Edit Assessment' : 'Create Assessment',
            subtitle:
                'Step $_step of $_totalSteps · ${_step == 1 ? 'Details' : 'Questions'}',
            onBack: _back,
            trailing: _step == 2
                ? IconButton(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add, color: Colors.white, size: 24),
                    tooltip: 'Add question',
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                if (_step == 1)
                  _DetailsStep(
                    postings: _postings,
                    internshipId: _internshipId,
                    onPostingChanged: (id) =>
                        setState(() => _internshipId = id),
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
                    onClearImage: _clearImage,
                    onAddOption: _addOption,
                    onRemoveOption: _removeOption,
                  ),
              ],
            ),
          ),
          _CreateAssessmentFooter(
            onNext: _isSaving
                ? null
                : (_step == _totalSteps
                      ? _saveQuestions
                      : _saveDetailsAndContinue),
            isSaving: _isSaving,
            nextLabel: _step == _totalSteps ? 'Save' : 'Next',
          ),
        ],
      ),
    );
  }
}

class _CreateAssessmentFooter extends StatelessWidget {
  const _CreateAssessmentFooter({
    required this.onNext,
    required this.nextLabel,
    required this.isSaving,
  });

  final VoidCallback? onNext;
  final String nextLabel;
  final bool isSaving;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(nextLabel),
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.postings,
    required this.internshipId,
    required this.onPostingChanged,
    required this.titleController,
    required this.descriptionController,
    required this.timeLimitController,
  });

  final List<AssessmentPostingOption> postings;
  final int? internshipId;
  final ValueChanged<int?> onPostingChanged;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController timeLimitController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An assessment always screens for one posting — the backend requires
        // it, and the web asks for it first too.
        _FieldCard(
          label: 'FOR WHICH POSTING',
          child: DropdownButtonFormField<int>(
            initialValue: internshipId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Color(0xFFEEF1F5),
              border: OutlineInputBorder(borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintText: 'Select a posting',
            ),
            items: [
              for (final posting in postings)
                DropdownMenuItem(
                  value: posting.id,
                  child: Text(posting.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onPostingChanged,
          ),
        ),
        const SizedBox(height: 16),
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
            hintText:
                'Outline the goals of this assessment, required skills, and what the candidate can expect…',
            minLines: 3,
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.timer_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Time Limit', style: AppFonts.title(fontSize: 16)),
                  const SizedBox(height: 2),
                  const Text(
                    'Define how time pressure is applied to your candidates to ensure fair and accurate results.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
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
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
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
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: '00',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MINUTES',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leave blank for no time limit.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
            ],
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
    required this.onClearImage,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  final List<DraftQuestion> questions;
  final void Function(int index) onToggleExpanded;
  final void Function(int index) onRemove;
  final void Function(DraftQuestion question, QuestionType type) onSetType;
  final void Function(DraftQuestion question, int optionId) onSetCorrectOption;
  final void Function(DraftQuestion question, int optionId)
  onToggleCorrectOption;
  final void Function(DraftQuestion question) onPickImage;
  final void Function(DraftQuestion question) onClearImage;
  final void Function(DraftQuestion question) onAddOption;
  final void Function(DraftQuestion question, DraftOption option)
  onRemoveOption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < questions.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == questions.length - 1 ? 0 : 16,
            ),
            child: _QuestionCard(
              index: i,
              question: questions[i],
              onToggleExpanded: () => onToggleExpanded(i),
              onRemove: questions.length > 1 ? () => onRemove(i) : null,
              onSetType: (type) => onSetType(questions[i], type),
              onSetCorrectOption: (optionId) =>
                  onSetCorrectOption(questions[i], optionId),
              onToggleCorrectOption: (optionId) =>
                  onToggleCorrectOption(questions[i], optionId),
              onPickImage: () => onPickImage(questions[i]),
              onClearImage: () => onClearImage(questions[i]),
              onAddOption: () => onAddOption(questions[i]),
              onRemoveOption: (option) => onRemoveOption(questions[i], option),
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
    required this.onClearImage,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  final int index;
  final DraftQuestion question;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onRemove;
  final void Function(QuestionType type) onSetType;
  final void Function(int optionId) onSetCorrectOption;
  final void Function(int optionId) onToggleCorrectOption;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onAddOption;
  final void Function(DraftOption option) onRemoveOption;

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
                  question.expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${index + 1}',
                      style: AppFonts.title(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    PopupMenuButton<QuestionType>(
                      padding: EdgeInsets.zero,
                      onSelected: onSetType,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          enabled: false,
                          child: Text(
                            'Select type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        for (final type in const [
                          QuestionType.multipleChoice,
                          QuestionType.checkbox,
                          QuestionType.dropdown,
                        ])
                          PopupMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  type == question.type
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: type == question.type
                                      ? AppColors.primary
                                      : AppColors.textMuted,
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
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (question.expanded) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Question'),
            const SizedBox(height: 6),
            _GreyTextField(
              controller: question.textController,
              hintText: 'Type here your question',
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Description (Optional)'),
            const SizedBox(height: 6),
            _GreyTextField(
              controller: question.descriptionController,
              hintText: 'Type here your description',
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onPickImage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    question.hasImage
                        ? 'Change Inline Image'
                        : 'Add Inline Image',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (question.hasImage) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _QuestionImage(question: question),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      // Removes the image outright. Picking a different one
                      // is the "Change Inline Image" link above.
                      onTap: onClearImage,
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
              for (final option in question.options) ...[
                _OptionLabelRow(
                  label:
                      'Option ${_letterFor(question.options.indexOf(option))}',
                  onRemove: question.options.length > 2
                      ? () => onRemoveOption(option)
                      : null,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Checkbox(
                      value: question.correctOptionIds.contains(option.id),
                      onChanged: (_) => onToggleCorrectOption(option.id),
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: _GreyTextField(
                        controller: option.controller,
                        hintText: 'Add answer…',
                      ),
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
                    for (final option in question.options) ...[
                      _OptionLabelRow(
                        label:
                            'Option ${_letterFor(question.options.indexOf(option))}',
                        onRemove: question.options.length > 2
                            ? () => onRemoveOption(option)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Radio<int>(
                            value: option.id,
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: _GreyTextField(
                              controller: option.controller,
                              hintText: 'Add answer…',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddOption,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add option'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ),
            if (question.type != QuestionType.checkbox) ...[
              const SizedBox(height: 4),
              AppDropdownField<int>(
                label: 'Answer',
                value: question.correctOptionId,
                items: [for (final option in question.options) option.id],
                itemLabel: (id) =>
                    'Option ${_letterFor(question.options.indexWhere((o) => o.id == id))}',
                hint: 'Select the correct answer',
                onChanged: (value) => onSetCorrectOption(value!),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// A, B, C … then plain numbers once the alphabet runs out, so a long
  /// option list can't produce nonsense labels.
  static String _letterFor(int index) =>
      index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';
}

/// Renders whichever image the question currently has — a freshly picked
/// local file, or the one already stored on the server (an inline `data:`
/// URI, which `Image.network` handles as well as an http URL).
class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.question});

  final DraftQuestion question;

  @override
  Widget build(BuildContext context) {
    final path = question.imagePath;
    if (path != null) {
      return Image.file(
        File(path),
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      question.imageUrl!,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 120,
        alignment: Alignment.center,
        color: AppColors.background,
        child: const Text(
          'Image could not be loaded',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

class _OptionLabelRow extends StatelessWidget {
  const _OptionLabelRow({required this.label, this.onRemove});

  final String label;

  /// Null for the last two options: the server rejects a question with fewer
  /// than two, so the control is withheld rather than failing on save.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FieldLabel(label),
        const Spacer(),
        if (onRemove != null)
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: AppColors.textMuted),
            ),
          ),
      ],
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
        children: [_FieldLabel(label), const SizedBox(height: 8), child],
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
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
