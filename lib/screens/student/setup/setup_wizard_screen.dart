import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/profile_setup.dart';
import '../../../services/profile_setup_service.dart';
import '../home/home_screen.dart';
import 'setup_review_screen.dart';
import 'setup_scaffold.dart';

/// Steps 1–5 of the first-run wizard, in one screen so the answers stay
/// together as the student moves back and forth.
///
/// Each step saves to the server as it's left, matching the web wizard — so
/// abandoning halfway still leaves the profile partly filled rather than
/// losing everything.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({
    super.key,
    required this.parsed,
    this.service,
    this.resumeName,
  });

  /// What the resume scan found, or [ParsedResume.empty] when filling manually.
  final ParsedResume parsed;
  final ProfileSetupService? service;
  final String? resumeName;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  late final ProfileSetupService _service = widget.service ?? ProfileSetupService();

  static const _totalSteps = 5;
  int _step = 1;
  bool _isBusy = false;

  // Step 1
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _zip = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  // Step 2
  final _school = TextEditingController();
  final _schoolAddress = TextEditingController();
  final _degree = TextEditingController();
  final _major = TextEditingController();

  // Step 3
  final _technicalInput = TextEditingController();
  final _softInput = TextEditingController();
  final List<String> _technical = [];
  final List<String> _soft = [];

  // Steps 4 & 5 — saved server-side as they're added.
  final List<Certification> _certifications = [];
  final List<Experience> _experiences = [];

  @override
  void initState() {
    super.initState();
    _prefillFromResume();
  }

  /// Everything the scan understood goes straight into the fields, which the
  /// student then reviews — the web's "auto-fill, then confirm" promise.
  void _prefillFromResume() {
    final parsed = widget.parsed;

    _name.text = parsed.basicInfo.name ?? '';
    _address.text = parsed.basicInfo.address ?? '';
    _zip.text = parsed.basicInfo.zipCode ?? '';
    _phone.text = parsed.basicInfo.phoneNumber ?? '';
    _email.text = parsed.basicInfo.email ?? '';

    if (parsed.education.isNotEmpty) {
      final education = parsed.education.first;
      _school.text = education.schoolName ?? '';
      _degree.text = education.degree ?? '';
    }

    _technical.addAll(parsed.technicalSkills);
    _soft.addAll(parsed.softSkills);
  }

  @override
  void dispose() {
    for (final controller in [
      _name, _address, _zip, _phone, _email,
      _school, _schoolAddress, _degree, _major,
      _technicalInput, _softInput,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _next() => _guard(() async {
        switch (_step) {
          case 1:
            await _service.saveStep1(
              name: _name.text.trim(),
              address: _address.text.trim(),
              zipCode: _zip.text.trim(),
              phoneNumber: _phone.text.trim(),
              email: _email.text.trim(),
            );
          case 2:
            await _service.saveStep2(
              schoolName: _school.text.trim(),
              schoolAddress: _schoolAddress.text.trim(),
              degree: _degree.text.trim(),
              major: _major.text.trim(),
            );
          case 3:
            await _service.saveStep3(technicalSkills: _technical, softSkills: _soft);
        }

        if (!mounted) return;

        if (_step == _totalSteps) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SetupReviewScreen(service: _service)),
          );
          return;
        }

        setState(() => _step++);
      });

  void _back() {
    if (_step == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  /// Leaving the wizard early is allowed — the profile keeps whatever was
  /// saved and the student can finish it later from their profile page.
  Future<void> _skip() => _guard(() async {
        await _service.skip();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      });

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: _step,
      totalSteps: _totalSteps,
      stepLabel: _stepLabel,
      title: _stepTitle,
      subtitle: _stepSubtitle,
      isBusy: _isBusy,
      onBack: _back,
      onNext: _next,
      nextLabel: _step == _totalSteps ? 'Review' : 'Next',
      child: _buildStep(),
    );
  }

  String get _stepLabel => switch (_step) {
        1 => 'About you',
        2 => 'Education',
        3 => 'Skills',
        4 => 'Certifications',
        _ => 'Experience',
      };

  String get _stepTitle => switch (_step) {
        1 => 'About you',
        2 => 'Education',
        3 => 'Skills',
        4 => 'Certifications',
        _ => 'Experience',
      };

  String get _stepSubtitle => switch (_step) {
        1 => 'Your name and how employers can reach you.',
        2 => "Where you study and what you're taking.",
        3 => 'The skills that best describe you.',
        4 => "Certificates and credentials you've earned.",
        _ => "Jobs, internships or projects you've taken on.",
      };

  Widget _buildStep() => switch (_step) {
        1 => _buildAboutYou(),
        2 => _buildEducation(),
        3 => _buildSkills(),
        4 => _buildCertifications(),
        _ => _buildExperience(),
      };

  Widget _buildAboutYou() {
    return Column(
      children: [
        SetupField(label: 'Full Name', controller: _name),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: SetupField(label: 'Address', controller: _address)),
            const SizedBox(width: 12),
            Expanded(
              child: SetupField(
                label: 'Zip Code',
                controller: _zip,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SetupField(
          label: 'Phone Number',
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        SetupField(
          label: 'Email Address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        if (widget.resumeName != null) ...[
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Resume', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Color(0xFFE03E3E)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.resumeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _isBusy ? null : _skip,
            child: const Text("I'll do this later"),
          ),
        ),
      ],
    );
  }

  Widget _buildEducation() {
    return Column(
      children: [
        SetupField(label: 'School / University', controller: _school),
        const SizedBox(height: 14),
        SetupField(label: 'School Address', controller: _schoolAddress),
        const SizedBox(height: 14),
        SetupField(label: 'Degree program', controller: _degree),
        const SizedBox(height: 14),
        SetupField(label: 'Major', controller: _major),
      ],
    );
  }

  Widget _buildSkills() {
    return Column(
      children: [
        _SkillGroup(
          heading: 'TECHNICAL SKILLS',
          controller: _technicalInput,
          skills: _technical,
          chipColor: const Color(0xFFDCE7F7),
          textColor: AppColors.primary,
          onAdd: (skill) => setState(() => _technical.add(skill)),
          onRemove: (skill) => setState(() => _technical.remove(skill)),
        ),
        const SizedBox(height: 16),
        _SkillGroup(
          heading: 'SOFT SKILLS',
          controller: _softInput,
          skills: _soft,
          chipColor: const Color(0xFFE7DEF9),
          textColor: const Color(0xFF6C3DE0),
          onAdd: (skill) => setState(() => _soft.add(skill)),
          onRemove: (skill) => setState(() => _soft.remove(skill)),
        ),
      ],
    );
  }

  Widget _buildCertifications() {
    return Column(
      children: [
        for (final certification in _certifications)
          _EntryCard(
            title: certification.title,
            subtitle: certification.subtitle,
            onDelete: () => _guard(() async {
              await _service.deleteCertification(certification.id);
              if (mounted) setState(() => _certifications.remove(certification));
            }),
          ),
        _AddButton(
          label: 'Add Certification',
          onTap: () async {
            final result = await showModalBottomSheet<Certification>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _CertificationSheet(service: _service),
            );
            if (result != null && mounted) setState(() => _certifications.add(result));
          },
        ),
      ],
    );
  }

  Widget _buildExperience() {
    return Column(
      children: [
        for (final experience in _experiences)
          _EntryCard(
            title: experience.position,
            subtitle: [experience.organization, experience.period]
                .where((s) => s.isNotEmpty)
                .join(' • '),
            body: experience.description,
            onDelete: () => _guard(() async {
              await _service.deleteExperience(experience.id);
              if (mounted) setState(() => _experiences.remove(experience));
            }),
          ),
        _AddButton(
          label: 'Add experience',
          onTap: () async {
            final result = await showModalBottomSheet<Experience>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _ExperienceSheet(service: _service),
            );
            if (result != null && mounted) setState(() => _experiences.add(result));
          },
        ),
      ],
    );
  }
}

/// A titled box with a tag input and the chips added so far.
class _SkillGroup extends StatelessWidget {
  const _SkillGroup({
    required this.heading,
    required this.controller,
    required this.skills,
    required this.chipColor,
    required this.textColor,
    required this.onAdd,
    required this.onRemove,
  });

  final String heading;
  final TextEditingController controller;
  final List<String> skills;
  final Color chipColor;
  final Color textColor;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  void _add() {
    final value = controller.text.trim();
    // Case-insensitive, so "React" and "react" don't both end up on the profile.
    if (value.isEmpty || skills.any((s) => s.toLowerCase() == value.toLowerCase())) {
      controller.clear();
      return;
    }
    onAdd(value);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${skills.length} ${skills.length == 1 ? 'SKILL' : 'SKILLS'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Project Management',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(76, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in skills)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          skill,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => onRemove(skill),
                          child: Icon(Icons.close, size: 15, color: textColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.onDelete,
    this.body,
  });

  final String title;
  final String subtitle;
  final String? body;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet shell shared by the two add forms.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.children, required this.onSave, required this.isSaving});

  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppFonts.title(fontSize: 18, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificationSheet extends StatefulWidget {
  const _CertificationSheet({required this.service});

  final ProfileSetupService service;

  @override
  State<_CertificationSheet> createState() => _CertificationSheetState();
}

class _CertificationSheetState extends State<_CertificationSheet> {
  final _title = TextEditingController();
  final _organization = TextEditingController();
  final _issueDate = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _title.dispose();
    _organization.dispose();
    _issueDate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A certification name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final certification = await widget.service.addCertification(
        title: _title.text.trim(),
        issuingOrganization: _organization.text.trim(),
        issueDate: _issueDate.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(certification);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = e is ApiException ? e.message : 'Could not save that certification.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Add Certification',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        SetupField(label: 'Certification name', controller: _title),
        const SizedBox(height: 14),
        SetupField(label: 'Issuing organization', controller: _organization),
        const SizedBox(height: 14),
        SetupField(label: 'Issue date', controller: _issueDate, hintText: 'e.g. 2023'),
      ],
    );
  }
}

class _ExperienceSheet extends StatefulWidget {
  const _ExperienceSheet({required this.service});

  final ProfileSetupService service;

  @override
  State<_ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends State<_ExperienceSheet> {
  final _position = TextEditingController();
  final _organization = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _description = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in [_position, _organization, _start, _end, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_position.text.trim().isEmpty || _organization.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A job title and company are required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final experience = await widget.service.addExperience(
        position: _position.text.trim(),
        organization: _organization.text.trim(),
        startDate: _start.text.trim(),
        endDate: _end.text.trim(),
        description: _description.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(experience);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = e is ApiException ? e.message : 'Could not save that experience.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Add Experience',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        SetupField(label: 'Job title / role', controller: _position),
        const SizedBox(height: 14),
        SetupField(label: 'Company', controller: _organization),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SetupField(label: 'Start date', controller: _start, hintText: 'June 2021')),
            const SizedBox(width: 12),
            Expanded(child: SetupField(label: 'End date', controller: _end, hintText: 'Aug 2024')),
          ],
        ),
        const SizedBox(height: 14),
        SetupField(label: 'Description', controller: _description, maxLines: 3),
      ],
    );
  }
}
