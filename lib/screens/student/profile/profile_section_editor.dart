import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';

/// What kind of input a field needs.
enum EditorFieldType { text, multiline, date, year, choice, url }

/// One field in a profile section editor.
///
/// The sections differ only in which fields they ask for, so they are
/// described rather than hand-built: one sheet renders all six.
class EditorField {
  EditorField({
    required this.key,
    required this.label,
    this.initial,
    this.type = EditorFieldType.text,
    this.required = false,
    this.hint,
    this.choices = const [],
  });

  final String key;
  final String label;
  final String? initial;
  final EditorFieldType type;
  final bool required;
  final String? hint;

  /// Only for [EditorFieldType.choice]: the value stored and the label shown.
  final List<({String value, String label})> choices;
}

/// Opens the add or edit sheet for one profile section.
///
/// Returns true when something was saved, so the caller knows to reload. The
/// sheet does the saving itself through [onSave] and keeps the spinner and
/// the server's error message inside itself, which is why every section does
/// not need its own copy of that handling.
Future<bool> showProfileSectionEditor({
  required BuildContext context,
  required String title,
  required List<EditorField> fields,
  required Future<void> Function(Map<String, String?> values) onSave,
  String saveLabel = 'Save',
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _EditorSheet(
      title: title,
      fields: fields,
      onSave: onSave,
      saveLabel: saveLabel,
    ),
  );

  return saved ?? false;
}

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.saveLabel,
  });

  final String title;
  final List<EditorField> fields;
  final Future<void> Function(Map<String, String?> values) onSave;
  final String saveLabel;

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initial ?? ''),
  };

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(EditorField field) async {
    final controller = _controllers[field.key]!;
    final current = DateTime.tryParse(controller.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null) return;

    // Ang server, ISO ang hinihintay. Yun din ang ibinabalik nito sa form,
    // kaya walang pagkakaiba kung saan galing yung petsa.
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {});
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final values = <String, String?>{
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim().isEmpty
            ? null
            : entry.value.text.trim(),
    };

    try {
      await widget.onSave(values);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Yung sinasabi ng server ang ipinapakita, hindi yung sariling hula.
        // Iisa lang naman ang balidasyon ng web at ng app, kaya kaparehong
        // paliwanag din ang nababasa sa dalawa.
        _error = e is ApiException ? e.message : 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AppFonts.title(fontSize: 17),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final field in widget.fields) ...[
                          _buildField(field),
                          const SizedBox(height: 14),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.saveLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(EditorField field) {
    final controller = _controllers[field.key]!;

    String? validate(String? value) {
      if (field.required && (value == null || value.trim().isEmpty)) {
        return '${field.label} is required.';
      }
      return null;
    }

    if (field.type == EditorFieldType.choice) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final choice in field.choices)
            DropdownMenuItem(value: choice.value, child: Text(choice.label)),
        ],
        onChanged: (value) => controller.text = value ?? '',
        validator: validate,
      );
    }

    if (field.type == EditorFieldType.date) {
      return TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _pickDate(field),
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint ?? 'Tap to pick a date',
          border: const OutlineInputBorder(),
          suffixIcon: controller.text.isEmpty
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => controller.clear()),
                ),
        ),
        validator: validate,
      );
    }

    return TextFormField(
      controller: controller,
      maxLines: field.type == EditorFieldType.multiline ? 4 : 1,
      keyboardType: switch (field.type) {
        EditorFieldType.year => TextInputType.number,
        EditorFieldType.url => TextInputType.url,
        EditorFieldType.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      inputFormatters: field.type == EditorFieldType.year
          ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]
          : null,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: field.type == EditorFieldType.multiline,
      ),
      validator: validate,
    );
  }
}

/// The confirmation shown before a row is removed. One copy so every section
/// asks the same way.
Future<bool> confirmSectionDelete(BuildContext context, String what) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove entry'),
      content: Text('Remove "$what" from your profile? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Remove'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
