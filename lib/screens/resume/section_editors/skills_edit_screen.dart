import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';

class SkillsEditScreen extends StatefulWidget {
  const SkillsEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<SkillsEditScreen> createState() => _SkillsEditScreenState();
}

class _SkillsEditScreenState extends State<SkillsEditScreen> {
  final _service = ResumeService();
  late List<ResumeSkillEntry> _technical = List.of(widget.section.technicalSkills);
  late List<ResumeSkillEntry> _soft = List.of(widget.section.softSkills);

  final _technicalController = TextEditingController();
  final _softController = TextEditingController();
  bool _isAddingTechnical = false;
  bool _isAddingSoft = false;

  @override
  void dispose() {
    _technicalController.dispose();
    _softController.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(String category) async {
    final controller = category == 'technical' ? _technicalController : _softController;
    final skillName = controller.text.trim();
    if (skillName.isEmpty) return;

    setState(() => category == 'technical' ? _isAddingTechnical = true : _isAddingSoft = true);
    try {
      final section = await _service.addSkill(widget.section.id, category: category, skillName: skillName);
      if (!mounted) return;
      setState(() {
        _technical = section.technicalSkills;
        _soft = section.softSkills;
        controller.clear();
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => category == 'technical' ? _isAddingTechnical = false : _isAddingSoft = false);
    }
  }

  Future<void> _remove(ResumeSkillEntry skill, String category) async {
    try {
      await _service.deleteSkill(skill.id);
      if (!mounted) return;
      setState(() {
        if (category == 'technical') {
          _technical.removeWhere((s) => s.id == skill.id);
        } else {
          _soft.removeWhere((s) => s.id == skill.id);
        }
      });
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Skills', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SkillGroup(
            title: 'Technical Skills',
            skills: _technical,
            controller: _technicalController,
            isAdding: _isAddingTechnical,
            onAdd: () => _add('technical'),
            onRemove: (s) => _remove(s, 'technical'),
          ),
          const SizedBox(height: 20),
          _SkillGroup(
            title: 'Soft Skills',
            skills: _soft,
            controller: _softController,
            isAdding: _isAddingSoft,
            onAdd: () => _add('soft'),
            onRemove: (s) => _remove(s, 'soft'),
          ),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({
    required this.title,
    required this.skills,
    required this.controller,
    required this.isAdding,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<ResumeSkillEntry> skills;
  final TextEditingController controller;
  final bool isAdding;
  final VoidCallback onAdd;
  final void Function(ResumeSkillEntry) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.4),
              ),
              Text('${skills.length} SKILLS', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(hintText: 'e.g. Project Management', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: isAdding ? null : onAdd,
                child: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add'),
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
                  Chip(
                    label: Text(skill.skillName),
                    backgroundColor: AppColors.chipBackground,
                    labelStyle: const TextStyle(color: AppColors.primary, fontSize: 13),
                    deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.primary),
                    onDeleted: () => onRemove(skill),
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
