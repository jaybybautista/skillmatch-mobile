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

  /// The open postings an assessment can screen for. At least one is
  /// required; several are allowed, because one paper can screen for many
  /// postings — same as the web's checkbox list.
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

  /// The question the side panel's type picker acts on.
  ///
  /// The web panel edits whichever question is open in the builder; here the
  /// last one expanded plays that role, so tapping a question and then the
  /// panel changes the one you were just looking at.
  int _activeQuestion = 0;

  /// True once step 1 has been written to the server. From then on the
  /// assessment exists as a draft and step 1 edits become updates.
  int? _assessmentId;

  /// Every posting ticked in step 1. Saving writes exactly this set, so an
  /// id dropped from here is unlinked from the assessment.
  final Set<int> _internshipIds = {};
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
      _internshipIds.addAll(
        existing.internships.isNotEmpty
            ? existing.internshipIds
            : [?existing.internshipId],
      );
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _timeLimitController.text = existing.timeLimitMinutes?.toString() ?? '';
    }

    _preselectSinglePosting();

    if (_isEditing) {
      // The library card carries neither the questions nor the full list of
      // linked postings, so the paper is fetched in full — and that same
      // call brings back the picker's options, including any closed posting
      // already linked, which the library's list leaves out.
      _loadExisting();
    } else {
      _questions.add(DraftQuestion());
      if (widget.postings == null) _loadPostings();
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
    if (_internshipIds.isEmpty && _postings.length == 1) {
      _internshipIds.add(_postings.first.id);
    }
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

  Future<void> _loadExisting() async {
    try {
      final edit = await _service.fetchAssessmentForEditing(
        widget.existing!.id,
      );
      if (!mounted) return;
      setState(() {
        _postings = edit.postingOptions;
        // The server's answer wins over the library card's summary: it is
        // the one that knows about closed postings still linked here.
        _internshipIds
          ..clear()
          ..addAll(edit.assessment.internshipIds);
        _preselectSinglePosting();

        for (final question in _questions) {
          question.dispose();
        }
        _questions
          ..clear()
          ..addAll(edit.assessment.questions.map(DraftQuestion.fromExisting));
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

  /// "5 min", or that it runs untimed. Read from the field rather than from
  /// the server, so it follows an edit made on step 1 without a save.
  String get _timeLimitLabel {
    final raw = _timeLimitController.text.trim();
    final minutes = int.tryParse(raw);

    return minutes == null || minutes <= 0 ? 'No limit' : '$minutes min';
  }

  /// Which postings this paper screens for. One reads as its title; several
  /// as a count, because the panel is narrow.
  String get _postingLabel {
    if (_internshipIds.isEmpty) return 'None selected';
    if (_internshipIds.length > 1) return '${_internshipIds.length} postings';

    final id = _internshipIds.first;
    for (final posting in _postings) {
      if (posting.id == id) return posting.title;
    }
    return '1 posting';
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _togglePosting(int id) {
    setState(() {
      if (!_internshipIds.remove(id)) _internshipIds.add(id);
    });
  }

  void _addQuestion() {
    setState(() {
      _questions.add(DraftQuestion());
      _activeQuestion = _questions.length - 1;
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
      // Deleting the question the panel was pointing at must not leave it
      // pointing past the end of the list.
      _activeQuestion = _activeQuestion.clamp(0, _questions.length - 1);
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
    setState(() {
      _questions[index].expanded = !_questions[index].expanded;
      if (_questions[index].expanded) _activeQuestion = index;
    });
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
    if (_internshipIds.isEmpty) {
      _notify('Choose at least one posting this assessment screens for.');
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
              internshipIds: _internshipIds.toList(),
              title: title,
              description: description.isEmpty ? null : description,
              timeLimitMinutes: timeLimit,
            )
          : await _service.updateAssessment(
              id: _assessmentId!,
              internshipIds: _internshipIds.toList(),
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
    // Only step 2 has anything to put in it: the type picker needs a
    // question, and Save/Back to details belong to the questions step.
    final hasPanel = _step == 2 && _questions.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: hasPanel
          ? _AssessmentSidePanel(
              questionNumber: _activeQuestion + 1,
              selectedType: _questions[_activeQuestion].type,
              onSelectType: (type) =>
                  _setType(_questions[_activeQuestion], type),
              questionCount: _questions.length,
              timeLimitLabel: _timeLimitLabel,
              postingLabel: _postingLabel,
              isSaving: _isSaving,
              onSave: _isSaving ? null : _saveQuestions,
              onBackToDetails: () => setState(() => _step = 1),
            )
          : null,
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
            child: Stack(
              children: [
                ListView(
                  // Room at the bottom for the button to float over without
                  // covering the last option of the last question.
                  padding: EdgeInsets.fromLTRB(20, 22, 20, hasPanel ? 88 : 24),
                  children: [
                    if (_step == 1)
                      _DetailsStep(
                        postings: _postings,
                        selectedIds: _internshipIds,
                        onPostingToggled: _togglePosting,
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
                if (hasPanel)
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Builder(
                      builder: (context) => FloatingActionButton(
                        onPressed: Scaffold.of(context).openEndDrawer,
                        backgroundColor: AppColors.primary,
                        tooltip: 'Assessment panel',
                        child: const Icon(Icons.tune, color: Colors.white),
                      ),
                    ),
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
    required this.selectedIds,
    required this.onPostingToggled,
    required this.titleController,
    required this.descriptionController,
    required this.timeLimitController,
  });

  final List<AssessmentPostingOption> postings;
  final Set<int> selectedIds;
  final ValueChanged<int> onPostingToggled;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController timeLimitController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tick every posting this paper screens for. A checkbox list rather
        // than a dropdown for the same reason the web uses one: what is
        // already selected has to stay visible, because saving writes
        // exactly this set and anything unticked is unlinked.
        _FieldCard(
          label: 'LINKED POSTINGS',
          child: postings.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'You have no open postings yet. Create one first, then '
                    'come back here.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final posting in postings)
                      _PostingCheckbox(
                        posting: posting,
                        selected: selectedIds.contains(posting.id),
                        onChanged: () => onPostingToggled(posting.id),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pick every posting that should screen with this '
                      'assessment. Reusing one assessment across several '
                      'postings beats building it again — edit it once and '
                      'every posting that uses it follows.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
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

/// The web builder's right-hand column, which a phone has no room for
/// beside the questions — so it slides in from the same side instead.
///
/// Same three things it has there: the type of the question being edited,
/// the assessment at a glance, and the two actions that finish the job.
class _AssessmentSidePanel extends StatelessWidget {
  const _AssessmentSidePanel({
    required this.questionNumber,
    required this.selectedType,
    required this.onSelectType,
    required this.questionCount,
    required this.timeLimitLabel,
    required this.postingLabel,
    required this.isSaving,
    required this.onSave,
    required this.onBackToDetails,
  });

  final int questionNumber;
  final QuestionType selectedType;
  final ValueChanged<QuestionType> onSelectType;

  final int questionCount;
  final String timeLimitLabel;
  final String postingLabel;

  final bool isSaving;
  final VoidCallback? onSave;
  final VoidCallback onBackToDetails;

  static const _types = [
    (QuestionType.multipleChoice, Icons.radio_button_checked),
    (QuestionType.checkbox, Icons.check),
    (QuestionType.dropdown, Icons.keyboard_arrow_down),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Assessment',
                      style: AppFonts.title(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textMuted,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Select type',
                                style: AppFonts.title(fontSize: 14),
                              ),
                            ),
                            // Which question this is about. The web panel
                            // can rely on the open card being visible beside
                            // it; a drawer covers the questions, so it says.
                            Text(
                              'Question $questionNumber',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final (type, icon) in _types) ...[
                          _TypeOption(
                            label: type.label,
                            icon: icon,
                            selected: type == selectedType,
                            onTap: () => onSelectType(type),
                          ),
                          if (type != _types.last.$1) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assessment info',
                          style: AppFonts.title(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        _PanelStat(
                          icon: Icons.notes_outlined,
                          label: 'Questions',
                          value: '$questionCount',
                        ),
                        const Divider(height: 20),
                        _PanelStat(
                          icon: Icons.schedule,
                          label: 'Time limit',
                          value: timeLimitLabel,
                        ),
                        const Divider(height: 20),
                        _PanelStat(
                          icon: Icons.work_outline,
                          label: 'Posting',
                          value: postingLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: onSave == null
                          ? null
                          : () {
                              // Close first: saving pops this screen on
                              // success, and a drawer left open over a route
                              // that is going away flickers on the way out.
                              Navigator.of(context).pop();
                              onSave!();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Save assessment'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBackToDetails();
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three question types, laid out as the web panel lays them out:
/// an icon, the name, and a radio on the far right.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F0FE) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the assessment-info card: icon, label, and the value in blue
/// on the right, matching the web.
class _PanelStat extends StatelessWidget {
  const _PanelStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
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

/// One tickable posting in the linked-postings list.
class _PostingCheckbox extends StatelessWidget {
  const _PostingCheckbox({
    required this.posting,
    required this.selected,
    required this.onChanged,
  });

  final AssessmentPostingOption posting;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onChanged(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                posting.title,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        ),
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
