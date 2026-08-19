import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_assessment.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/company_screen_header.dart';
import 'assessment_draft.dart';

/// The paper as written — the phone's version of the website's "View
/// assessment" page.
///
/// Correct answers start hidden behind a reveal toggle, exactly as the web
/// page does it: a company often opens this with a candidate or colleague
/// looking on, and the answers shouldn't be the first thing on screen.
class AssessmentPreviewScreen extends StatefulWidget {
  const AssessmentPreviewScreen({
    super.key,
    required this.assessmentId,
    this.initialTitle,
    this.service,
  });

  final int assessmentId;

  /// Shown in the header while the paper loads, so the screen doesn't open
  /// on an anonymous "Assessment".
  final String? initialTitle;

  final CompanyAssessmentService? service;

  @override
  State<AssessmentPreviewScreen> createState() => _AssessmentPreviewScreenState();
}

class _AssessmentPreviewScreenState extends State<AssessmentPreviewScreen> {
  late final CompanyAssessmentService _service = widget.service ?? CompanyAssessmentService();

  bool _isLoading = true;
  Object? _error;
  CompanyAssessment? _assessment;

  /// Which questions currently have their answer revealed.
  final Set<int> _revealed = {};

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
      final assessment = await _service.fetchAssessment(widget.assessmentId);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
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

  void _toggleAll() {
    final questions = _assessment?.questions ?? const <CompanyAssessmentQuestion>[];
    setState(() {
      if (_revealed.length == questions.length) {
        _revealed.clear();
      } else {
        _revealed
          ..clear()
          ..addAll(questions.map((q) => q.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final questions = assessment?.questions ?? const <CompanyAssessmentQuestion>[];
    final allRevealed = questions.isNotEmpty && _revealed.length == questions.length;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyScreenHeader(
            title: assessment?.title ?? widget.initialTitle ?? 'Assessment',
            subtitle: assessment?.internshipTitle,
            onBack: () => Navigator.of(context).pop(),
            trailing: questions.isEmpty
                ? null
                : IconButton(
                    onPressed: _toggleAll,
                    icon: Icon(
                      allRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white,
                    ),
                    tooltip: allRevealed ? 'Hide all answers' : 'Reveal all answers',
                  ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _assessment == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load this assessment.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final assessment = _assessment!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaPill(
              icon: Icons.quiz_outlined,
              label: '${assessment.questionCount} '
                  'Question${assessment.questionCount == 1 ? '' : 's'}',
            ),
            if (assessment.timeLimitMinutes != null)
              _MetaPill(
                icon: Icons.access_time_rounded,
                label: '${assessment.timeLimitMinutes} Minutes',
              ),
            _MetaPill(
              icon: Icons.assignment_turned_in_outlined,
              label: '${assessment.submissionCount} '
                  'Submission${assessment.submissionCount == 1 ? '' : 's'}',
            ),
            _MetaPill(
              icon: assessment.isPublished ? Icons.check_circle_outline : Icons.edit_note,
              label: assessment.isPublished ? 'Published' : 'Draft',
            ),
          ],
        ),
        if (assessment.description != null && assessment.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            assessment.description!,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.45),
          ),
        ],
        const SizedBox(height: 20),
        if (assessment.questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No questions found for this assessment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          for (var i = 0; i < assessment.questions.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == assessment.questions.length - 1 ? 0 : 14,
              ),
              child: _QuestionPreviewCard(
                index: i,
                question: assessment.questions[i],
                isRevealed: _revealed.contains(assessment.questions[i].id),
                onToggleReveal: () => setState(() {
                  final id = assessment.questions[i].id;
                  if (!_revealed.remove(id)) _revealed.add(id);
                }),
              ),
            ),
      ],
    );
  }
}

class _QuestionPreviewCard extends StatelessWidget {
  const _QuestionPreviewCard({
    required this.index,
    required this.question,
    required this.isRevealed,
    required this.onToggleReveal,
  });

  final int index;
  final CompanyAssessmentQuestion question;
  final bool isRevealed;
  final VoidCallback onToggleReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${index + 1}', style: AppFonts.title(fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  question.type.label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.35,
            ),
          ),
          if (question.description != null && question.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              question.description!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
          ],
          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              // Inline images are stored as `data:` URIs by both builders,
              // which Image.network handles alongside real http URLs.
              child: Image.network(
                question.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < question.choices.length; i++)
            _ChoiceRow(
              letter: i < 26 ? String.fromCharCode(65 + i) : '${i + 1}',
              choice: question.choices[i],
              isRevealed: isRevealed,
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleReveal,
              icon: Icon(
                isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(isRevealed ? 'Hide correct answer' : 'Show correct answer'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.letter,
    required this.choice,
    required this.isRevealed,
  });

  final String letter;
  final CompanyAssessmentChoice choice;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    final highlight = isRevealed && choice.isCorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEAFAF1) : AppColors.background,
        border: Border.all(
          color: highlight ? const Color(0xFF1A7F4B) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: highlight ? const Color(0xFF1A7F4B) : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              choice.text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.3),
            ),
          ),
          if (highlight) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF1A7F4B)),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
