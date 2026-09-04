import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../models/assessment.dart';

/// Ang mga kulay ng basahan ng code. Kaparehong-kapareho ng nasa web
/// (resources/views/components/code-viewer.blade.php), kaya iisa ang itsura
/// ng isang tanong kahit saan ito buksan.
///
/// Madilim ito kahit maliwanag ang buong app. Sinadya: ganito ang editor na
/// pinagmulan ng code, kaya ganito rin dapat ang basahan nito.
class CodeColors {
  CodeColors._();

  static const shell = Color(0xFF131A2B);
  static const bar = Color(0xFF1B2338);
  static const barBorder = Color(0xFF2A3550);
  static const gutter = Color(0xFF161E31);
  static const gutterBorder = Color(0xFF232C45);
  static const gutterText = Color(0xFF4E5A78);
  static const code = Color(0xFFD8E0F5);
  static const output = Color(0xFF0F1524);
  static const note = Color(0xFF7D8AA8);
  static const chip = Color(0xFF232C45);
  static const chipBorder = Color(0xFF313D5C);
  static const chipText = Color(0xFFD6DEF2);
  static const accent = Color(0xFF1D4ED8);
}

/// Yung font ng code. Nauna yung mga nakalagay na sa telepono, tapos monospace
/// na lang pag wala ni isa - ang mahalaga, pantay-pantay ang lapad ng letra
/// para tumapat ang indent sa itinuturo ng bilang ng linya.
const List<String> kCodeFontFallback = <String>[
  'monospace',
  'Roboto Mono',
  'Droid Sans Mono',
  'Courier New',
];

const TextStyle kCodeTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: kCodeFontFallback,
  fontSize: 12.5,
  height: 1.55,
  color: CodeColors.code,
);

/// Hex na galing sa server papuntang Color. Pag pumalpak, abo na lang - mas
/// mabuti nang may tanda kaysa sumabog ang buong tanong.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null || cleaned.length != 6) return const Color(0xFF6B7A99);
  return Color(0xFF000000 | value);
}

/// Maitim na letra sa maliwanag na kulay, puti sa madilim. Kung hindi,
/// nawawala yung letra ng JavaScript at ng Swift. Luminance ang basehan,
/// hindi average - mas mabigat ang berde sa mata kaysa asul.
Color inkOn(Color background) {
  final r = (background.r * 255).round();
  final g = (background.g * 255).round();
  final b = (background.b * 255).round();
  return (0.299 * r + 0.587 * g + 0.114 * b) > 150
      ? const Color(0xFF12161F)
      : const Color(0xFFFFFFFF);
}

/// Yung logo ng wika sa tabi ng pangalan nito.
///
/// Tunay na logo galing sa Devicon, nakabalot sa assets/devicon. Hindi ito
/// kinukuha sa internet, kaya lumalabas pa rin kahit mahina ang signal habang
/// nag-eexam - at dahil SVG ito, hindi nagiging malabo kahit palakihin.
///
/// May dalawang walang logo, ang SQL at ang Pseudocode. Wala kasi sila sa
/// Devicon, at mali namang ilagay ang dolphin ng MySQL sa isang tanong na
/// plain SQL. Kulay at letra na lang sila, gaya ng ginagawa ng mga editor sa
/// file tree nila. Ganun din ang wikang naidagdag sa server pero wala pang
/// kopya ng logo dito sa app.
class LanguageTile extends StatefulWidget {
  const LanguageTile({super.key, required this.badge, this.size = 20});

  final LanguageBadge badge;
  final double size;

  @override
  State<LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<LanguageTile> {
  /// Yung nabasa nang logo, itinatabi habang buhay ang app. Isang listahan
  /// ng wika, tatlumpu't walo ang hilera - masakit kung tuwina itong bumabasa
  /// sa asset bundle habang nag-i-scroll siya.
  static final Map<String, String?> _cache = {};

  String? _markup;
  bool _looked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LanguageTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Pumalit ang wika habang nakabukas pa rin ang parehong kahon.
    if (oldWidget.badge.slug != widget.badge.slug) {
      _looked = false;
      _markup = null;
      _load();
    }
  }

  Future<void> _load() async {
    final slug = widget.badge.slug;

    // Sinabi na ng server na walang logo ito, kaya hindi na hahanapin pa.
    if (slug.isEmpty || !widget.badge.hasIcon) {
      setState(() => _looked = true);
      return;
    }

    if (_cache.containsKey(slug)) {
      setState(() {
        _markup = _cache[slug];
        _looked = true;
      });
      return;
    }

    String? markup;
    try {
      markup = await rootBundle.loadString('assets/devicon/$slug.svg');
    } catch (_) {
      // Walang kopya ng logo para sa wikang ito. Hindi ito mali - tanda na
      // lang ang lalabas, at buo pa rin ang tanong.
      markup = null;
    }

    _cache[slug] = markup;
    if (!mounted) return;

    setState(() {
      _markup = markup;
      _looked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    // Habang hinahanap pa yung logo, blangkong kahon muna. Sandali lang ito,
    // at mas mabuti nang blangko kaysa kumurap yung tanda mula letra papuntang
    // logo sa harap niya.
    if (!_looked) {
      return SizedBox(width: size, height: size);
    }

    final markup = _markup;

    if (markup != null) {
      // Maputi ang plato sa likod. May ilang logo kasing itim - ang Rust, ang
      // Express, ang Flask at ang Next.js - at nawawala sila sa madilim na bar
      // kapag wala nito.
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all((size * 0.1).clamp(1, 3)),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5FA),
          borderRadius: BorderRadius.circular(3),
        ),
        child: SvgPicture.string(
          markup,
          fit: BoxFit.contain,
          semanticsLabel: widget.badge.label,
        ),
      );
    }

    final background = colorFromHex(widget.badge.color);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        widget.badge.mono,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: kCodeFontFallback,
          fontSize: size * 0.46,
          fontWeight: FontWeight.w700,
          height: 1,
          color: inkOn(background),
        ),
      ),
    );
  }
}

/// Yung tanda ng wika na may pangalan sa tabi, gaya ng nasa kaliwang taas ng
/// editor. Pag may [onTap], nagiging pindutan ito para palitan ang wika.
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key, required this.badge, this.onTap});

  final LanguageBadge badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
      decoration: BoxDecoration(
        color: CodeColors.chip,
        border: Border.all(color: CodeColors.chipBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LanguageTile(badge: badge),
          const SizedBox(width: 7),
          Text(
            badge.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: CodeColors.chipText,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: CodeColors.note,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: content,
    );
  }
}

/// Ang buong kahon ng code. Bar sa taas, bilang ng linya sa gilid, tapos yung
/// code mismo. Ang [children] naman, yung mga panel sa ilalim - dito
/// nakadikit yung sinasagutang output o yung susi, depende kung sino ang
/// tumitingin.
class CodeViewer extends StatelessWidget {
  const CodeViewer({
    super.key,
    required this.badge,
    required this.code,
    this.note,
    this.onLanguageTap,
    this.children = const [],
  });

  final LanguageBadge badge;
  final String code;

  /// Yung nakasulat sa kanan ng bar.
  final String? note;

  /// Pag may nito, mapipindot yung tanda ng wika para palitan ito.
  final VoidCallback? onLanguageTap;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CodeColors.shell,
        border: Border.all(color: CodeColors.barBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
            decoration: const BoxDecoration(
              color: CodeColors.bar,
              border: Border(
                bottom: BorderSide(color: CodeColors.barBorder),
              ),
            ),
            child: Row(
              children: [
                LanguageChip(badge: badge, onTap: onLanguageTap),
                if (note != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: CodeColors.note,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CodeBody(code: code),
          ...children,
        ],
      ),
    );
  }
}

/// Yung bilang ng linya at yung code sa tabi nito.
///
/// Hiwalay ang bilang sa code. Pag pinindot nang matagal ng estudyante yung
/// snippet para kopyahin, code lang ang nakuha niya - walang kasamang bilang.
class CodeBody extends StatelessWidget {
  const CodeBody({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final lines = code.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final gutter = List.generate(lines.length, (i) => '${i + 1}').join('\n');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 38,
            padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
            decoration: const BoxDecoration(
              color: CodeColors.gutter,
              border: Border(
                right: BorderSide(color: CodeColors.gutterBorder),
              ),
            ),
            child: Text(
              gutter,
              textAlign: TextAlign.right,
              style: kCodeTextStyle.copyWith(color: CodeColors.gutterText),
            ),
          ),
          Expanded(
            // Hindi binabali ang mahahabang linya. Bumabaligtad kasi ang
            // ibig sabihin ng code pag binali sa maling lugar, kaya kinakaladkad
            // na lang pahalang gaya ng ginagawa ng editor.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: SelectableText(code, style: kCodeTextStyle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yung guhit na naghahati sa ilalim ng code - "YOUR OUTPUT", "EXPECTED
/// OUTPUT", ganun.
class CodePanelHeader extends StatelessWidget {
  const CodePanelHeader({super.key, required this.label, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: const BoxDecoration(
        color: CodeColors.bar,
        border: Border(top: BorderSide(color: CodeColors.barBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CodeColors.accent, width: 2),
              ),
            ),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: CodeColors.chipText,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: CodeColors.note,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Basahan lang, hindi masusulatan. Dito napupunta yung sinagot ng estudyante
/// at yung susi pag tinitingnan na ng kompanya ang papel.
class CodeOutputText extends StatelessWidget {
  const CodeOutputText({super.key, required this.text, this.placeholder});

  final String text;

  /// Ipinapakita pag walang laman ang [text].
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;

    return Container(
      width: double.infinity,
      color: CodeColors.output,
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          empty ? (placeholder ?? 'Nothing was typed.') : text,
          style: kCodeTextStyle.copyWith(
            color: empty ? CodeColors.gutterText : CodeColors.code,
            fontStyle: empty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}

/// Yung masusulatang kahon sa loob ng code viewer. Dito tinitipa ng estudyante
/// yung output, at dito rin isinusulat ng kompanya yung code at yung susi.
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines = 3,
    this.maxLines = 12,
    this.gutter = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;

  /// Pag totoo, may bilang ng linya sa gilid - para sa code. Yung output,
  /// wala, iisa hanggang tatlong linya lang naman yun kadalasan.
  final bool gutter;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Kaparehong-kapareho ng likod ng basahan sa itaas nito. Yung may bilang
    // ng linya, katabi ng code kaya kulay ng code. Yung wala, output kaya
    // kulay ng output.
    final background = gutter ? CodeColors.shell : CodeColors.output;

    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: kCodeTextStyle,
      cursorColor: CodeColors.code,
      // Walang autocorrect at walang malaking letra sa simula. Sinisira ng
      // dalawang ito ang code at ang output, at hindi agad napapansin.
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        isDense: true,
        // Sinasabi nang tahasan ang likod. Puti kasi ang itinatakda ng
        // inputDecorationTheme ng buong app, at pinipintahan nito ang lahat ng
        // TextField - kaya nagiging puti ang loob ng basahan ng code, at
        // halos hindi na mabasa ang maputlang letra doon.
        filled: true,
        fillColor: background,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintText: hintText,
        hintStyle: kCodeTextStyle.copyWith(color: CodeColors.gutterText),
      ),
    );

    if (!gutter) {
      return Container(color: background, child: field);
    }

    // Yung bilang ng linya, sumusunod habang tinitipa. Nakikinig ito sa
    // controller mismo, kaya tama pa rin ang bilang kahit nag-paste siya ng
    // buong function nang minsanan.
    return Container(
      color: background,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final count = '\n'.allMatches(value.text).length + 1;
                return Container(
                  width: 38,
                  padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                  decoration: const BoxDecoration(
                    color: CodeColors.gutter,
                    border: Border(
                      right: BorderSide(color: CodeColors.gutterBorder),
                    ),
                  ),
                  child: Text(
                    List.generate(count, (i) => '${i + 1}').join('\n'),
                    textAlign: TextAlign.right,
                    style: kCodeTextStyle.copyWith(
                      color: CodeColors.gutterText,
                    ),
                  ),
                );
              },
            ),
            Expanded(child: field),
          ],
        ),
      ),
    );
  }
}

/// Yung maliit na paalala sa pinakailalim ng kahon.
class CodeFoot extends StatelessWidget {
  const CodeFoot({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: const BoxDecoration(
        color: CodeColors.gutter,
        border: Border(top: BorderSide(color: CodeColors.gutterBorder)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.45,
          color: Color(0xFF6E7B99),
        ),
      ),
    );
  }
}
