import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment.dart';
import '../../services/assessment_service.dart';
import 'assessment_quiz_screen.dart';
import 'assessment_result_screen.dart';

/// The overview a student sees before starting a competency test — the mobile
/// twin of the web's assessment-intro page.
///
/// Pops `true` if an attempt was submitted, so the Applications list knows to
/// reload and show the completed status.
class AssessmentIntroScreen extends StatefulWidget {
  const AssessmentIntroScreen({super.key, required this.assessmentId});

  final int assessmentId;

  @override
  State<AssessmentIntroScreen> createState() => _AssessmentIntroScreenState();
}

class _AssessmentIntroScreenState extends State<AssessmentIntroScreen> {
  final _service = AssessmentService();

  bool _isLoading = true;
  Object? _error;
  AssessmentIntro? _intro;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final intro = await _service.fetchIntro(widget.assessmentId);
      if (!mounted) return;

      // Already attempted within the current assignment window — the web
      // redirects to the result here, so do the same rather than letting a
      // student retake something that's already recorded.
      if (intro.alreadyCompleted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AssessmentResultScreen(assessmentId: widget.assessmentId)),
        );
        return;
      }

      setState(() {
        _intro = intro;
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

  Future<void> _start() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssessmentQuizScreen(assessmentId: widget.assessmentId)),
    );

    if (submitted == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _buildContent(_intro!),
    );
  }

  Widget _buildContent(AssessmentIntro intro) {
    return Column(
      children: [
        _Hero(title: intro.title, subtitle: intro.subtitle),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            children: [
              if (intro.isRetake) ...[
                const _ReassignedNotice(),
                const SizedBox(height: 18),
              ],
              const Text(
                'Brief explanation about the assessment',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 20),
              _SpecRow(
                icon: Icons.description_outlined,
                label: '${intro.questionCount} '
                    '${intro.questionCount == 1 ? 'Question' : 'Questions'}',
                sub: '${intro.totalPoints} ${intro.totalPoints == 1 ? 'point' : 'points'} in total',
              ),
              const SizedBox(height: 18),
              _SpecRow(
                icon: Icons.access_time,
                label: intro.timeLimitMinutes != null
                    ? _formatDuration(intro.timeLimitMinutes!)
                    : 'No time limit',
                sub: 'Total duration of the quiz',
              ),
              const SizedBox(height: 24),
              const Text(
                'Please read the text below carefully so you can understand it:',
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              for (final instruction in intro.instructions) _Bullet(text: instruction),
              if (intro.attemptHistory.isNotEmpty) ...[
                const SizedBox(height: 22),
                _AttemptHistory(attempts: intro.attemptHistory),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _start,
                style: intro.isRetake
                    ? ElevatedButton.styleFrom(backgroundColor: _retakeButton)
                    : null,
                child: Text(intro.isRetake ? 'Retake Assessment' : 'Start'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 75 minutes reads better as "1 hour 15 min", matching the web's intent of
  /// showing the whole duration at a glance.
  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    final hourLabel = '$hours ${hours == 1 ? 'hour' : 'hours'}';

    return remainder == 0 ? hourLabel : '$hourLabel $remainder min';
  }
}

/// Green palette shared with the Applications card's retake button.
const _retakeSurface = Color(0xFFF0FDF4);
const _retakeText = Color(0xFF15803D);
const _retakeBorder = Color(0xFFBBF7D0);
const _retakeButton = Color(0xFF16A34A);

/// Explains why the student is seeing a test they already answered.
class _ReassignedNotice extends StatelessWidget {
  const _ReassignedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _retakeSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _retakeBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.refresh, size: 17, color: _retakeText),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'This assessment was reassigned to you. Your new attempt replaces the previous result.',
              style: TextStyle(color: _retakeText, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Past attempts, newest first — the student-facing version of the attempt
/// history the coordinator sees, including its "Before reassignment" note.
class _AttemptHistory extends StatelessWidget {
  const _AttemptHistory({required this.attempts});

  final List<AssessmentAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your previous attempts',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        for (final attempt in attempts)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${attempt.score}/${attempt.totalPoints} (${attempt.percentage}%)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        attempt.isCurrent
                            ? attempt.submittedAtLabel
                            : '${attempt.submittedAtLabel} · Before reassignment',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  attempt.timedOut
                      ? 'Time expired'
                      : attempt.passed
                          ? 'Passed'
                          : 'Did not pass',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: attempt.passed ? _retakeText : const Color(0xFFE03E3E),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dark banner with the back/cancel row, mirroring the web's `.intro-hero`.
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1A5E), Color(0xFF1E4FD8)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleBackButton(onTap: () => Navigator.of(context).pop()),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, height: 1.25),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.icon, required this.label, required this.sub});

  final IconData icon;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFE8EEFF), shape: BoxShape.circle),
          child: Icon(icon, size: 21, color: const Color(0xFF1E4FD8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(decoration: BoxDecoration(color: AppColors.textDark, shape: BoxShape.circle)),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Could not open this assessment.';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
