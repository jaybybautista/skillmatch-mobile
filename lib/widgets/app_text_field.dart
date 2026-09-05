import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A labeled text field matching the prototype style: a small label above a
/// rounded outlined box.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.hintText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  /// Yung maputlang pahiwatig sa loob ng kahon habang wala pang laman.
  final String? hintText;

  /// Kada tipa. Ginagamit ito ng Others, para agad-agad na masundan yung
  /// isinusulat nila.
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// A labeled dropdown matching the same visual language as [AppTextField].
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.hint,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          // Pinapayagang tumangkad yung hilera kaysa sa nakatakdang 48.
          //
          // Dito nagkakaproblema yung mahahabang pangalan ng programa.
          // "Bachelor of Science in Information Technology major in Web and
          // Mobile Technologies" - hindi yun kasya sa isang linya sa telepono,
          // at dati pinuputol ito ng ellipsis, kaya hindi nila mabasa kung
          // alin ang pinipili nila. Ngayon, bumababa na lang ito sa susunod
          // na linya.
          itemHeight: null,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textMuted,
          ),
          hint: hint != null ? Text(hint!) : null,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(itemLabel(item), softWrap: true),
                  ),
                ),
              )
              .toList(),
          // Yung nakikita sa loob ng kahon pag nakasara na. Kailangan itong
          // sabihin nang hiwalay - kung hindi, yung mismong hilera ang
          // ipinapakita nito, at kasama yung padding para sa listahan.
          selectedItemBuilder: (context) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(itemLabel(item), softWrap: true),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
