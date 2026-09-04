import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/assessment.dart';
import '../../../services/assessment_service.dart';

/// Outcome of an attempt — the mobile twin of the web's assessment-result page,
/// including its pass mark (50%) and wording, both of which come from the API.
///
/// [result] is passed straight through after submitting; when opened any other
/// way (e.g. reopening a completed test) the latest attempt is fetched.
class AssessmentResultScreen extends StatefulWidget {
  const AssessmentResultScreen({
    super.key,
    required this.assessmentId,
    this.result,
    this.service,
  });

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

  static const _amber = Color(0xFFB87700);
  static const _amberBackground = Color(0xFFFFF4E5);
  static const _green = Color(0xFF15803D);

  Widget _buildResult(AssessmentAttemptResult result) {
    // Waiting on a person is its own outcome, and it is neither blue nor red:
    // nothing has been decided, so nothing should look decided.
    //
    // Timing out is its own outcome too, so it never reads as an ordinary fail
    // (or, worse, gets mistaken for a pass).
    final underReview = result.isUnderReview;

    final accent = underReview || result.timedOut
        ? _amber
        : result.passed == true
        ? const Color(0xFF1E4FD8)
        : const Color(0xFFE03E3E);
    final accentBackground = underReview || result.timedOut
        ? _amberBackground
        : result.passed == true
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
                  decoration: BoxDecoration(
                    color: accentBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    underReview
                        ? Icons.hourglass_top_outlined
                        : result.timedOut
                        ? Icons.timer_off_outlined
                        : result.passed == true
                        ? Icons.school_outlined
                        : Icons.close,
                    size: 42,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 20),
                if (underReview)
                  _Pill(
                    label: 'Under review',
                    icon: Icons.schedule,
                    color: _amber,
                    background: _amberBackground,
                  )
                else if (result.wasReviewed)
                  const _Pill(
                    label: 'Final score',
                    icon: Icons.check_circle_outline,
                    color: _green,
                    background: Color(0xFFECFDF5),
                  ),
                if (underReview || result.wasReviewed)
                  const SizedBox(height: 14),
                Text(
                  result.headline,
                  textAlign: TextAlign.center,
                  style: AppFonts.title(
                    fontSize: 21,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Walang bilang habang hinihintay pa. Kalahati lang naman ang
                // natsek, kaya mukhang bagsak yung marka kahit hindi pa
                // nabibilang yung mga sinulat niya.
                if (underReview)
                  Text(
                    'Your score will appear here once ${result.companyName} '
                    'finishes reviewing.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    'You scored ${result.score} out of ${result.totalPoints} '
                    'points (${result.percentage}%)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),

                if (!underReview && result.timedOut) ...[
                  const SizedBox(height: 12),
                  _Pill(
                    label: 'Did not pass, time expired',
                    icon: Icons.timer_off_outlined,
                    color: accent,
                    background: accentBackground,
                  ),
                ],

                const SizedBox(height: 20),

                if (underReview)
                  _ReviewSteps(result: result)
                else
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                      height: 1.55,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: SafeArea(
            top: false,
            child: ElevatedButton(
              onPressed: _close,
              child: const Text('Back to Applications'),
            ),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Retry')),
          TextButton(
            onPressed: _close,
            child: const Text('Back to Applications'),
          ),
        ],
      ),
    );
  }
}

/// What was settled already and what is still owed, one line each.
///
/// Left aligned rather than centred: this is a list of facts, not a sentence,
/// and each line answers a different question the student has.
class _ReviewSteps extends StatelessWidget {
  const _ReviewSteps({required this.result});

  final AssessmentAttemptResult result;

  @override
  Widget build(BuildContext context) {
    final counts = result.reviewCounts;
    final rows = <(IconData, Color, String)>[];

    if (counts.autoChecked > 0) {
      rows.add((
        Icons.check_circle_outline,
        const Color(0xFF16A34A),
        '${counts.autoChecked} of ${counts.total} '
            '${counts.total == 1 ? 'question' : 'questions'} '
            '${counts.autoChecked == 1 ? 'was' : 'were'} checked automatically.',
      ));
    }

    rows.add((
      Icons.schedule,
      _AssessmentResultScreenState._amber,
      '${counts.awaiting} written '
          '${counts.awaiting == 1 ? 'answer' : 'answers'} still '
          '${counts.awaiting == 1 ? 'needs' : 'need'} to be read by '
          '${result.companyName}.',
    ));

    // Tiyak na ito kahit hindi pa tapos yung repaso, kaya sinasabi na rin
    // ngayon. Yung score lang ang hinihintay dito.
    if (result.timedOut) {
      rows.add((
        Icons.info_outline,
        AppColors.textMuted,
        'This attempt was submitted automatically when the time ran out, so it '
            'will not count as a pass.',
      ));
    }

    rows.add((
      Icons.notifications_none,
      AppColors.textMuted,
      "We'll notify you as soon as your result is ready. You can leave this "
          'screen.',
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, color, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
            style: AppFonts.title(color: Colors.white, fontSize: 19),
          ),
        ),
      ),
    );
  }
}
