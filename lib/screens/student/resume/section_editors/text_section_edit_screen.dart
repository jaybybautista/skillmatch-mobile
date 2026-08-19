import 'package:flutter/material.dart';

import '../../../../core/api_client.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/resume.dart';
import '../../../../services/resume_service.dart';
import '../../../../widgets/ai_help_button.dart';
import '../../../../widgets/primary_button.dart';

/// Editor for a free-text section — professional_summary, or a custom
/// section (text_field/text_area/dropdown/bullet_points all edit the same
/// way here; input_type only affects how the web renders it on export).
class TextSectionEditScreen extends StatefulWidget {
  const TextSectionEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<TextSectionEditScreen> createState() => _TextSectionEditScreenState();
}

class _TextSectionEditScreenState extends State<TextSectionEditScreen> {
  final _service = ResumeService();
  late final _controller = TextEditingController(text: widget.section.content ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.updateTextSection(widget.section.id, _controller.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBulletPoints = widget.section.inputType == 'bullet_points';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.section.title, style: AppFonts.title(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.section.description != null && widget.section.description!.isNotEmpty) ...[
            Text(widget.section.description!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            maxLines: 10,
            minLines: 6,
            decoration: InputDecoration(
              hintText: isBulletPoints ? 'One point per line...' : 'Write here...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AiHelpButton(
              fieldLabel: widget.section.type == 'professional_summary' ? 'Professional Summary' : widget.section.title,
              getText: () => _controller.text,
              onAccept: (suggestion) => setState(() => _controller.text = suggestion),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Save', isLoading: _isSaving, onPressed: _save),
        ],
      ),
    );
  }
}
