import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment_answer_sheet.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/retake_open_tag.dart';

/// One student's answer sheet, the phone's copy of the website's
/// "View answers" page.
///
/// Reads the same `assessment_answers` rows, so the marks here and on the web
/// are the same marks. Written answers with no answer key are scored right on
/// this screen, and the server recomputes the total, which means a company can
/// finish grading from either place.
class AssessmentAnswerSheetScreen extends StatefulWidget {
  const AssessmentAnswerSheetScreen({
    super.key,
    required this.assessmentId,
    required this.resultId,
    required this.studentName,
    this.service,
  });

  final int assessmentId;
  final int resultId;
  final String studentName;
  final CompanyAssessmentService? service;

  @override
  State<AssessmentAnswerSheetScreen> createState() =>
      _AssessmentAnswerSheetScreenState();
}

class _AssessmentAnswerSheetScreenState
    extends State<AssessmentAnswerSheetScreen> {
  late final CompanyAssessmentService _service =
      widget.service ?? CompanyAssessmentService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRetaking = false;
  Object? _error;
  AssessmentAnswerSheet? _sheet;

  /// One controller per written answer, keyed by `assessment_answers` id.
  final Map<int, TextEditingController> _scores = {};

  /// True once anything was saved, so the list behind can refresh itself.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _scores.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sheet = await _service.fetchAnswerSheet(
        widget.assessmentId,
        widget.resultId,
      );
      if (!mounted) return;

      for (final c in _scores.values) {
        c.dispose();
      }
      _scores.clear();

      for (final row in sheet.gradable) {
        final id = row.answerId;
        if (id != null) {
          _scores[id] = TextEditingController(
            text: _trimZero(row.pointsAwarded),
          );
        }
      }

      setState(() {
        _sheet = sheet;
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

  /// 1.0 reads better as "1", 0.5 stays "0.5".
  static String _trimZero(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  Future<void> _save() async {
    final sheet = _sheet;
    if (sheet == null) return;

    final points = <int, double>{};
    for (final entry in _scores.entries) {
      points[entry.key] = double.tryParse(entry.value.text.trim()) ?? 0;
    }

    if (points.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await _service.gradeSubmission(
        widget.assessmentId,
        widget.resultId,
        points,
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scores saved.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not save the scores.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text(
            widget.studentName,
            style: AppFonts.title(fontSize: 17),
          ),
          actions: [
            if (_sheet?.applicationId != null)
              TextButton(
                onPressed: _isRetaking ? null : _retake,
                child: Text(
                  _isRetaking ? 'Retaking…' : 'Retake',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildSaveBar(),
      ),
    );
  }

  /// Re-runs the same reassignment the application's own Assign/Reassign
  /// action makes, on the application this attempt came through — the score
  /// already on record stays exactly as it is.
  Future<void> _retake() async {
    final sheet = _sheet;
    final applicationId = sheet?.applicationId;
    if (sheet == null || applicationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retake this assessment?'),
        content: Text(
          'Let ${sheet.studentName} retake "${sheet.assessmentTitle}"? '
          'Their current score is kept, and this opens a fresh attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRetaking = true);

    try {
      await _service.retake(
        applicationId: applicationId,
        assessmentId: widget.assessmentId,
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sheet.studentName} can now retake this assessment.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not open a retake.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRetaking = false);
    }
  }

  Widget? _buildSaveBar() {
    final sheet = _sheet;
    if (sheet == null || _scores.isEmpty) return null;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _isSaving
                ? 'Saving…'
                : (sheet.pendingReview ? 'Save scores' : 'Update scores'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load this answer sheet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final sheet = _sheet!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        _SummaryCard(sheet: sheet),
        const SizedBox(height: 16),
        if (!sheet.hasAnswers)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'This attempt was submitted before per-question answers were '
              'recorded, so only the score is available. Answer sheets are '
              'kept for every attempt from now on.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          )
        else
          for (var i = 0; i < sheet.rows.length; i++) ...[
            _QuestionCard(
              index: i + 1,
              row: sheet.rows[i],
              pendingReview: sheet.pendingReview,
              // Kailangan nito para masabi kung ilang bahagdan ng buong papel
              // ang tanong na ito.
              totalPoints: sheet.totalPoints,
              controller: sheet.rows[i].answerId == null
                  ? null
                  : _scores[sheet.rows[i].answerId],
            ),
            if (i != sheet.rows.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.sheet});

  final AssessmentAnswerSheet sheet;

  @override
  Widget build(BuildContext context) {
    final String verdict;
    final Color verdictColor;

    if (sheet.pendingReview) {
      verdict = 'Pending review';
      verdictColor = AppColors.warning;
    } else if (sheet.timedOut) {
      verdict = 'Timed out';
      verdictColor = AppColors.danger;
    } else if (sheet.passed) {
      verdict = 'Passed';
      verdictColor = const Color(0xFF1A7F4B);
    } else {
      verdict = 'Failed';
      verdictColor = AppColors.danger;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sheet.assessmentTitle,
                  style: AppFonts.title(fontSize: 16),
                ),
              ),
              // Nakabinbin pa ang bagong pagkakataong ibinigay mo.
              if (sheet.retakeOpen) const RetakeOpenTag(),
            ],
          ),
          if (sheet.submittedAtLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              'Submitted ${sheet.submittedAtLabel}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'SCORE',
                  value: '${sheet.percentage}%',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'POINTS',
                  value:
                      '${_AssessmentAnswerSheetScreenState._trimZero(sheet.score)}'
                      ' / ${sheet.totalPoints}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'RESULT',
                  value: verdict,
                  valueColor: verdictColor,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'TIME SPENT',
                  value: sheet.durationLabel ?? 'Not recorded',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.row,
    required this.pendingReview,
    required this.totalPoints,
    this.controller,
  });

  final int index;
  final AnswerSheetRow row;
  final bool pendingReview;

  /// The whole paper's total, used to say how much of it this question is.
  final int totalPoints;

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final gradable = row.manual && row.answered && row.isWritten;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question $index · '
                      '${_AssessmentAnswerSheetScreenState._trimZero(row.pointsAwarded)}'
                      ' of ${row.pointsPossible} points',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.questionText,
                      style: const TextStyle(fontSize: 14.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Mark(row: row, pendingReview: pendingReview),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'THEIR ANSWER',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          if (row.isWritten)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                row.answerText!,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            )
          else if (row.chosen.isNotEmpty)
            Text(
              row.chosen.join(', '),
              style: TextStyle(
                fontSize: 13.5,
                color: row.isCorrect == false
                    ? AppColors.danger
                    : AppColors.textDark,
              ),
            )
          else
            const Text(
              'Left blank',
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),

          // Manwal na tanong. Dito nilalagay yung puntos.
          if (gradable && controller != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'SCORE THIS ANSWER',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'of ${row.pointsPossible}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sinasabi nang tahasan ang hangganan. Ito yung itinakda nila sa
            // builder, kaya alam nila agad kung gaano kalaki ang sanaysay na
            // ito sa buong papel bago sila magbigay ng puntos.
            Text(
              'You set this question at ${row.pointsPossible} '
              '${row.pointsPossible == 1 ? 'point' : 'points'}, so anywhere '
              'from 0 to ${row.pointsPossible} is allowed.'
              '${totalPoints > 0 ? ' That is ${((row.pointsPossible / totalPoints) * 100).round()}% of the whole assessment.' : ''}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ] else if (row.isCorrect != true) ...[
            const SizedBox(height: 10),
            const Text(
              'CORRECT ANSWER',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              row.correct.isNotEmpty
                  ? row.correct.join(', ')
                  : 'No answer key was set for this question.',
              style: TextStyle(
                fontSize: 13.5,
                color: row.correct.isNotEmpty
                    ? const Color(0xFF1A7F4B)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.row, required this.pendingReview});

  final AnswerSheetRow row;
  final bool pendingReview;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    if (row.manual && row.answered && row.isWritten) {
      if (pendingReview) {
        label = 'Needs review';
        color = AppColors.warning;
      } else if (row.isCorrect == true) {
        label = 'Full marks';
        color = const Color(0xFF1A7F4B);
      } else {
        label = 'Scored';
        color = AppColors.primary;
      }
    } else if (!row.answered || row.isCorrect == null) {
      label = 'No answer';
      color = AppColors.textMuted;
    } else if (row.isCorrect == true) {
      label = 'Correct';
      color = const Color(0xFF1A7F4B);
    } else {
      label = 'Incorrect';
      color = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
