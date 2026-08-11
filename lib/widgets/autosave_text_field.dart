import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A labeled text field that saves itself a moment after the user stops
/// typing, used throughout Resume Builder's inline-editable entry cards
/// (Experience, Achievements, Projects, Education) so there's no separate
/// "Save" button per field.
class AutosaveTextField extends StatefulWidget {
  const AutosaveTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.hint,
    this.trailing,
  });

  final String label;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final String? hint;
  final Widget? trailing;

  @override
  State<AutosaveTextField> createState() => AutosaveTextFieldState();
}

class AutosaveTextFieldState extends State<AutosaveTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  Timer? _debounce;

  void _handleChange(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () => widget.onChanged(value));
  }

  /// Pushes text in from outside (e.g. an accepted AI Help suggestion) and
  /// saves it immediately, bypassing the usual typing debounce.
  void setText(String value) {
    _debounce?.cancel();
    _controller.text = value;
    widget.onChanged(value);
  }

  String get currentText => _controller.text;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          onChanged: _handleChange,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }
}
