import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/resume_service.dart';

/// Mirrors the web app's "AI Help" button: sends the current text to the
/// same Groq-backed rewrite endpoint, then shows a Current vs Suggested
/// compare sheet (like the web's ai-suggestion-box) before applying anything
/// — nothing is overwritten without the student explicitly accepting it.
class AiHelpButton extends StatefulWidget {
  const AiHelpButton({
    super.key,
    required this.fieldLabel,
    required this.getText,
    required this.onAccept,
    this.aiContext = const {},
  });

  final String fieldLabel;
  final String Function() getText;
  final ValueChanged<String> onAccept;
  final Map<String, String> aiContext;

  @override
  State<AiHelpButton> createState() => _AiHelpButtonState();
}

class _AiHelpButtonState extends State<AiHelpButton> {
  final _service = ResumeService();
  bool _isLoading = false;

  Future<void> _requestHelp() async {
    final text = widget.getText().trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Write something first, then tap AI Help to improve it.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final suggestion = await _service.improveText(
        widget.fieldLabel,
        text,
        context: widget.aiContext,
      );
      if (!mounted) return;
      final accepted = await showAiSuggestionSheet(
        context,
        original: text,
        suggested: suggestion,
      );
      if (accepted == true) widget.onAccept(suggestion);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Something went wrong reaching the AI service. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _requestHelp,
      icon: _isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.auto_fix_high, size: 14),
      label: Text(
        _isLoading ? 'Thinking…' : 'AI Help',
        style: const TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
      ),
    );
  }
}

/// Returns true if the student tapped "Use this", false/null on dismiss.
Future<bool?> showAiSuggestionSheet(
  BuildContext context, {
  required String original,
  required String suggested,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_fix_high,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Suggestion',
                    style: AppFonts.title(
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'CURRENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    original,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SUGGESTED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    suggested,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Use this'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
