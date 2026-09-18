import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../services/auth_service.dart';

/// The "I agree to the Terms and consent to data collection" checkbox from
/// the web sign-up forms. "Terms and Conditions" opens the full text in a
/// sheet whose "I agree and consent" button ticks the box.
class TermsConsentField extends StatelessWidget {
  const TermsConsentField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  Future<void> _openTerms(BuildContext context) async {
    final agreed = await showTermsSheet(context);
    if (agreed == true) onChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.45),
                      children: [
                        const TextSpan(text: 'I have read and agree to the '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openTerms(context),
                            child: const Text(
                              'Terms and Conditions',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(
                          text: ', and I consent to SkillMatch collecting and processing my personal data as described in its Data Privacy Notice.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
      ],
    );
  }
}

/// Shows the Terms and Conditions. Resolves true when "I agree and consent"
/// was pressed, false / null when dismissed.
Future<bool?> showTermsSheet(BuildContext context) {
  final auth = context.read<AuthService>();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => _TermsSheet(auth: auth, controller: controller),
    ),
  );
}

class _TermsSheet extends StatefulWidget {
  const _TermsSheet({required this.auth, required this.controller});

  final AuthService auth;
  final ScrollController controller;

  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  late final Future<TermsText> _terms = widget.auth.fetchTerms();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TermsText>(
      future: _terms,
      builder: (context, snapshot) {
        final terms = snapshot.data;
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(child: Text(terms?.title ?? 'Terms and Conditions', style: AppFonts.title(fontSize: 18))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: switch (snapshot.connectionState) {
                ConnectionState.done when snapshot.hasError => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'Could not load the terms. Please check your connection.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ConnectionState.done => SingleChildScrollView(
                    controller: widget.controller,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _TermsBody(text: terms?.text ?? ''),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            if (terms != null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(terms.button),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Plain-text terms, with numbered section headings drawn bold and the
/// "- " bullet lines indented.
class _TermsBody extends StatelessWidget {
  const _TermsBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final headingPattern = RegExp(r'^\d+(\.\d+)*\.\s');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: 8)
          else if (headingPattern.hasMatch(line.trim()) || line.trim() == line.trim().toUpperCase() && line.trim().length > 3 && line.trim().length < 80)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(line.trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            )
          else if (line.trim().startsWith('- '))
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textMuted)),
                  Expanded(child: Text(line.trim().substring(2), style: const TextStyle(fontSize: 13, height: 1.5))),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line.trim(), style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
      ],
    );
  }
}
