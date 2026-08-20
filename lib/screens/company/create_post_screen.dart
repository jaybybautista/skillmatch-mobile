import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import 'company_posting.dart';

/// The company's 3-step posting flow - Basic Info, Responsibilities, Skills -
/// reached from [CompanyPostingsScreen]'s "New Post" button.
///
/// Saves through POST/PUT /api/company/postings, which go through the shared
/// CompanyPostingService: the same `internships` row, the same deduplicated
/// responsibility and skill rows, and the same mirrored `required_skills`
/// column the website's own posting form writes. So a posting created on the
/// phone is editable on the web, and the matcher sees it either way.
///
/// Pass [posting] to edit an existing one instead of creating a new one.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.posting, this.service});

  /// The posting being edited, or null when creating a new one.
  final CompanyPosting? posting;

  final CompanyService? service;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _totalSteps = 3;

  late final CompanyService _service = widget.service ?? CompanyService();

  int _step = 1;
  bool _isSaving = false;

  final _jobRole = TextEditingController();
  final _slot = TextEditingController();

  final _responsibilityInput = TextEditingController();
  final _responsibilities = <String>[];

  final _skillInput = TextEditingController();
  final _skills = <String>[];

  bool get _isEditing => widget.posting != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.posting;
    if (existing == null) return;
    _jobRole.text = existing.title;
    _slot.text = existing.openSlots.toString();
    _responsibilities.addAll(existing.responsibilities);
    _skills.addAll(existing.skills);
  }

  @override
  void dispose() {
    _jobRole.dispose();
    _slot.dispose();
    _responsibilityInput.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether the step on screen is ready, saying why when it isn't.
  ///
  /// These are the same three requirements CompanyPostingService::rules()
  /// enforces server-side, checked here so a company isn't walked through the
  /// whole wizard only to be rejected at the end of it.
  bool _validateStep() {
    switch (_step) {
      case 1:
        if (_jobRole.text.trim().isEmpty) {
          _notify('Give the posting a job role first.');
          return false;
        }
        final slots = int.tryParse(_slot.text.trim());
        if (slots == null || slots < 1) {
          _notify('Enter how many slots are open - at least 1.');
          return false;
        }
        return true;
      case 2:
        // Anything typed but not yet added with "+" still counts: losing it
        // silently at the step boundary is the easiest way to be told a step
        // is empty when it visibly isn't.
        _addResponsibility();
        if (_responsibilities.isEmpty) {
          _notify('Add at least one responsibility.');
          return false;
        }
        return true;
      default:
        _addSkill();
        if (_skills.isEmpty) {
          _notify('Add at least one required skill.');
          return false;
        }
        return true;
    }
  }

  Future<void> _next() async {
    if (_isSaving) return;
    if (!_validateStep()) return;

    if (_step < _totalSteps) {
      setState(() => _step++);
      return;
    }

    await _save();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    // Resolved before the await: once the screen pops, this State's context
    // is gone, but the app-level messenger the snack bar lands on is not.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final slots = int.parse(_slot.text.trim());

    try {
      final saved = _isEditing
          ? await _service.updatePosting(
              id: widget.posting!.id,
              jobRole: _jobRole.text.trim(),
              slots: slots,
              responsibilities: _responsibilities,
              skills: _skills,
            )
          : await _service.createPosting(
              jobRole: _jobRole.text.trim(),
              slots: slots,
              responsibilities: _responsibilities,
              skills: _skills,
            );

      if (!mounted) return;
      navigator.pop(saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '"${saved.title}" updated.'
                : '"${saved.title}" has been posted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _notify(
        messageForError(
          e,
          _isEditing
              ? 'Could not save your changes. Check your connection and try again.'
              : 'Could not post this internship. Check your connection and try again.',
        ),
      );
    }
  }

  void _back() {
    if (_isSaving) return;
    if (_step == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  void _addResponsibility() {
    final text = _responsibilityInput.text.trim();
    if (text.isEmpty || _responsibilities.contains(text)) {
      // Duplicates are dropped server-side anyway, so don't let one look
      // added here and then quietly vanish on save.
      _responsibilityInput.clear();
      return;
    }
    setState(() {
      _responsibilities.add(text);
      _responsibilityInput.clear();
    });
  }

  void _removeResponsibility(int index) =>
      setState(() => _responsibilities.removeAt(index));

  void _addSkill() {
    final text = _skillInput.text.trim();
    if (text.isEmpty || _skills.contains(text)) {
      _skillInput.clear();
      return;
    }
    setState(() {
      _skills.add(text);
      _skillInput.clear();
    });
  }

  void _removeSkill(String skill) => setState(() => _skills.remove(skill));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: _isEditing ? 'Edit Post' : 'Create Post',
            onBack: _back,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                Text(
                  _stepTitle,
                  style: AppFonts.title(
                    fontSize: 19,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stepSubtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStep(),
              ],
            ),
          ),
          _CreatePostFooter(
            showPrevious: _step > 1,
            onPrevious: _back,
            onNext: _next,
            isBusy: _isSaving,
            nextLabel: _step == _totalSteps
                ? (_isEditing ? 'Save changes' : 'Post')
                : 'Next',
          ),
        ],
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    1 => 'Basic Info',
    2 => 'Responsibilities',
    _ => 'Skills',
  };

  String get _stepSubtitle => switch (_step) {
    1 => "Let's start with the core details.",
    2 => 'Outlining responsibilities.',
    _ =>
      'Specify the technical expertise and soft skills required for this internship.',
  };

  Widget _buildStep() => switch (_step) {
    1 => _BasicInfoStep(jobRoleController: _jobRole, slotController: _slot),
    2 => _ResponsibilitiesStep(
      controller: _responsibilityInput,
      items: _responsibilities,
      onAdd: _addResponsibility,
      onRemove: _removeResponsibility,
    ),
    _ => _SkillsStep(
      controller: _skillInput,
      items: _skills,
      onAdd: _addSkill,
      onRemove: _removeSkill,
    ),
  };
}

class _CreatePostFooter extends StatelessWidget {
  const _CreatePostFooter({
    required this.showPrevious,
    required this.onPrevious,
    required this.onNext,
    required this.nextLabel,
    this.isBusy = false,
  });

  final bool showPrevious;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String nextLabel;

  /// True while the posting is being saved: both buttons go dead so a second
  /// tap can't create the posting twice.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            if (showPrevious) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onPrevious,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy ? null : onNext,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isBusy
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
          ],
        ),
      ),
    );
  }
}

class _BasicInfoStep extends StatelessWidget {
  const _BasicInfoStep({
    required this.jobRoleController,
    required this.slotController,
  });

  final TextEditingController jobRoleController;
  final TextEditingController slotController;

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
          const _FieldLabel('JOB ROLE'),
          const SizedBox(height: 8),
          _GreyTextField(
            controller: jobRoleController,
            hintText: 'e.g. Product Design Intern',
          ),
          const SizedBox(height: 16),
          const _FieldLabel('SLOT'),
          const SizedBox(height: 8),
          _GreyTextField(
            controller: slotController,
            hintText: 'e.g. 10',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

class _ResponsibilitiesStep extends StatelessWidget {
  const _ResponsibilitiesStep({
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText:
                        'Define what the intern will be doing on a day-to-day basis…',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _AddSquareButton(onTap: onAdd),
            ],
          ),
        ),
        for (var i = 0; i < items.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onRemove(i),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SkillsStep extends StatelessWidget {
  const _SkillsStep({
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(String skill) onRemove;

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
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onAdd(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'e.g. React, UI Design, Python…',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _AddSquareButton(onTap: onAdd),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final skill in items)
                  _SkillPill(label: skill, onDelete: () => onRemove(skill)),
              ],
            ),
          ],
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

class _AddSquareButton extends StatelessWidget {
  const _AddSquareButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SkillPill extends StatelessWidget {
  const _SkillPill({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E9EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDelete,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
