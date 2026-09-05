import 'package:flutter/material.dart';

import 'app_text_field.dart';

/// Yung pinipili para makapagsulat ng sarili. Kapareho ito ng nasa server
/// (App\Support\Industries at App\Services\CampusProgramService), kaya
/// magkatugma ang web at ang app.
const String kOtherOption = 'Others';

/// Dropdown na may Others, at kapag Others ang napili, may kahong lalabas na
/// pagsusulatan nila ng sarili nila.
///
/// Dalawa ang inaayos nito:
///
/// Una, hindi na sila nakukulong sa listahan. May kompanyang wala sa alinman
/// sa mga larangan, at may estudyanteng iba ang tunay na programa kaysa sa
/// inaalok ng campus - dati wala silang magagawa doon.
///
/// Pangalawa, isinasama nito yung kasalukuyang laman kahit wala ito sa
/// listahan. May galing sa setup wizard, may galing sa nabasang dokumento, at
/// may sinulat na lang mismo. Kung hindi ito isasama, wala silang makikitang
/// napili, at mabubura yung tunay nilang sagot pagkasave nila.
///
/// Ang ibinabalik sa [onChanged], yung tunay na halaga - hindi kailanman ang
/// salitang Others. Kaya kahit ano pa ang pinili nila, iisa lang ang
/// ipinapadala sa server.
class SelectOrOtherField extends StatefulWidget {
  const SelectOrOtherField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.otherLabel = 'Type your own',
    this.otherHint,
    this.enabled = true,
    this.emptyHint,
    this.validator,
  });

  final String label;

  /// Kasalukuyang laman. Pwedeng wala sa [options].
  final String? value;

  /// Yung listahan. Hindi kasama dito ang Others, dinadagdag ito ng widget.
  final List<String> options;

  final ValueChanged<String?> onChanged;

  final String? hint;

  /// Pamagat ng kahong pagsusulatan.
  final String otherLabel;
  final String? otherHint;

  /// Pag hindi pa pwedeng pumili - halimbawa, wala pang campus na napipili.
  final bool enabled;

  /// Ipinapakita kapag walang laman ang [options].
  final String? emptyHint;

  final String? Function(String?)? validator;

  @override
  State<SelectOrOtherField> createState() => _SelectOrOtherFieldState();
}

class _SelectOrOtherFieldState extends State<SelectOrOtherField> {
  late final TextEditingController _other = TextEditingController();

  /// Nasa Others ba ngayon. Hiwalay ito sa laman - pwedeng Others ang napili
  /// pero wala pa siyang naisusulat.
  bool _isOther = false;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectOrOtherField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Nagpalit ng campus, kaya ibang listahan na. Kung hindi na kabilang yung
    // dating napili, bumabalik sa blangko - pero hindi pag sila mismo ang
    // sumulat nun, sagot pa rin nila yun.
    if (oldWidget.options != widget.options && !_isOther) {
      final current = widget.value?.trim() ?? '';
      if (current.isNotEmpty && !widget.options.contains(current)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged(null);
        });
      }
    }
  }

  /// Yung ilalagay sa dropdown, kasama yung kasalukuyang laman kahit wala ito
  /// sa listahan, at yung Others sa dulo.
  List<String> get _items {
    final items = List<String>.from(widget.options);

    final current = widget.value?.trim() ?? '';
    if (current.isNotEmpty && !items.contains(current)) {
      items.add(current);
    }

    items.add(kOtherOption);
    return items;
  }

  /// Ano ang dapat lumitaw na napili sa dropdown.
  String? get _selected {
    if (_isOther) return kOtherOption;

    final current = widget.value?.trim() ?? '';
    return current.isEmpty ? null : current;
  }

  @override
  Widget build(BuildContext context) {
    final hasOptions = widget.options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdownField<String>(
          label: widget.label,
          value: _selected,
          items: _items,
          itemLabel: (item) => item,
          hint: !widget.enabled
              ? (widget.emptyHint ?? widget.hint)
              : (hasOptions ? widget.hint : (widget.emptyHint ?? widget.hint)),
          validator: widget.validator,
          onChanged: !widget.enabled
              ? (_) {}
              : (picked) {
                  if (picked == kOtherOption) {
                    setState(() => _isOther = true);
                    // Yung nasa kahon na, yun agad ang sagot - para hindi
                    // maiwang blangko yung form kung may naisulat na siya.
                    widget.onChanged(
                      _other.text.trim().isEmpty ? null : _other.text.trim(),
                    );
                    return;
                  }

                  setState(() => _isOther = false);
                  widget.onChanged(picked);
                },
        ),
        if (_isOther) ...[
          const SizedBox(height: 14),
          AppTextField(
            label: widget.otherLabel,
            controller: _other,
            hintText: widget.otherHint,
            textInputAction: TextInputAction.next,
            onChanged: (text) =>
                widget.onChanged(text.trim().isEmpty ? null : text.trim()),
          ),
        ],
      ],
    );
  }
}
