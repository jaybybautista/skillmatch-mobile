import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment.dart';
import '../../services/assessment_service.dart';

/// Outcome of an attempt — the mobile twin of the web's assessment-result page,
/// including its pass mark (50%) and wording, both of which come from the API.
///
/// [result] is passed straight through after submitting; when opened any other
/// way (e.g. reopening a completed test) the latest attempt is fetched.
class AssessmentResultScreen extends StatefulWidget {
  const AssessmentResultScreen({super.key, required this.assessmentId, this.result, this.service});

  final int assessmentId;
  final AssessmentAttemptResult? result;

  /// Injectable for tests; defaults to the real service.
  final AssessmentService? service;

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  late final AssessmentService _service = widget.service ?? AssessmentService();

  late bool _isLoading = widget.result == null;
  Object? _error;
  late AssessmentAttemptResult? _result = widget.result;

  @override
  void initState() {
    super.initState();
    if (_result == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.fetchResult(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  /// Everything below this screen belongs to the attempt that just finished, so
  /// leaving returns to Applications and reports that something was submitted.
  void _close() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            _Header(title: _result?.assessmentTitle ?? 'Assessment'),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildResult(_result!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(AssessmentAttemptResult result) {
    // Timing out is its own outcome — amber and a clock, so it never reads as
    // an ordinary fail (or, worse, gets mistaken for a pass).
    final accent = result.timedOut
        ? const Color(0xFFB87700)
        : result.passed
            ? const Color(0xFF1E4FD8)
            : const Color(0xFFE03E3E);
    final accentBackground = result.timedOut
        ? const Color(0xFFFFF4E5)
        : result.passed
            ? const Color(0xFFE8EEFF)
            : const Color(0xFFFFF1F1);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accentBackground, shape: BoxShape.circle),
                  child: Icon(
                    result.timedOut
                        ? Icons.timer_off_outlined
                        : result.passed
                            ? Icons.school_outlined
                            : Icons.close,
                    size: 42,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  result.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  'You scored ${result.score} out of ${result.totalPoints} points (${result.percentage}%)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                if (result.timedOut) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: accentBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Did not pass — time expired',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: accent),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.55),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: SafeArea(
            top: false,
            child: ElevatedButton(onPressed: _close, child: const Text('Back to Applications')),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final message = _error is ApiException
        ? (_error as ApiException).message
        : 'Could not load your result.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Retry')),
          TextButton(onPressed: _close, child: const Text('Back to Applications')),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
