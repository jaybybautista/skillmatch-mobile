import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/resume_service.dart';
import '../../widgets/primary_button.dart';

const _inputTypeOptions = [
  ('text_field', 'Text Field'),
  ('text_area', 'Text Area'),
  ('dropdown', 'Dropdown'),
  ('bullet_points', 'Bullet Points'),
];

/// Add a custom resume section — POST /api/resumes/{id}/sections. Pops with
/// `true` when a section was added so the caller knows to refresh.
class AddSectionScreen extends StatefulWidget {
  const AddSectionScreen({super.key, required this.resumeId});

  final int resumeId;

  @override
  State<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends State<AddSectionScreen> {
  final _service = ResumeService();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  String _inputType = 'text_field';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a section title.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.addSection(
        resumeId: widget.resumeId,
        title: title,
        description: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
        inputType: _inputType,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Add New Section', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Title', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g., Certifications')),
          const SizedBox(height: 18),
          const Text('Details', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Short description shown under the section title'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Input Field Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Choose the best way to present this information.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                for (final option in _inputTypeOptions) ...[
                  _TypeOption(
                    label: option.$2,
                    selected: _inputType == option.$1,
                    onTap: () => setState(() => _inputType = option.$1),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', isLoading: _isSaving, onPressed: _save),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipBackground : AppColors.background,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
