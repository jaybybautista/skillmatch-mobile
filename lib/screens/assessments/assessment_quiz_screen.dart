import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment.dart';
import '../../services/assessment_service.dart';
import '../../services/quiz_state_store.dart';
import 'assessment_result_screen.dart';

/// One question at a time, with the countdown and progress header from the
/// mockup.
///
/// Behaviour deliberately matches the web quiz: answers and the current
/// question survive leaving the app, the deadline is wall-clock (so closing
/// the app doesn't buy extra time), time expiring auto-submits, and backing
/// out warns first. Grading is entirely server-side — nothing here decides a
/// score.
///
/// Pops `true` once an attempt has been submitted.
class AssessmentQuizScreen extends StatefulWidget {
  const AssessmentQuizScreen({super.key, required this.assessmentId, this.service});

  final int assessmentId;

  /// Injectable so tests can drive the submit/lock paths without a server.
  final AssessmentService? service;

  @override
  State<AssessmentQuizScreen> createState() => _AssessmentQuizScreenState();
}

/// How often the quiz checks that its attempt window is still open. Short
/// enough that finishing the same test on the web stops this one promptly.
const _statedPollInterval = Duration(seconds: 8);

class _AssessmentQuizScreenState extends State<AssessmentQuizScreen> with WidgetsBindingObserver {
  late final AssessmentService _service = widget.service ?? AssessmentService();
  late final QuizStateStore _store = QuizStateStore(widget.assessmentId);
  final _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Object? _error;

  AssessmentQuiz? _quiz;
  int _step = 0;

  /// Question id -> choice id, list of choice ids, or free text.
  final Map<int, Object> _answers = {};

  Timer? _ticker;
  int? _deadlineMs;

  /// The countdown lives in a notifier rather than in setState: rebuilding the
  /// whole page once a second re-laid-out the question card (and re-decoded its
  /// image) every tick, which is what made answering feel janky. Only the clock
  /// listens now.
  final ValueNotifier<Duration?> _remaining = ValueNotifier<Duration?>(null);

  /// Watches for the same assessment being submitted on another device.
  Timer? _statePoll;
  bool _isClosedElsewhere = false;

  /// Free-text questions keep their own controllers so typing doesn't lose the
  /// caret when the step rebuilds.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _statePoll = Timer.periodic(_statedPollInterval, (_) => _checkAttemptStillOpen());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app is exactly when the attempt is most likely to have
    // been finished somewhere else in the meantime.
    if (state == AppLifecycleState.resumed) _checkAttemptStillOpen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _statePoll?.cancel();
    _remaining.dispose();
    _scrollController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quiz = await _service.fetchQuiz(widget.assessmentId);
      final saved = await _store.load();
      if (!mounted) return;

      _answers.clear();
      if (saved != null) {
        // Drop answers for questions that no longer exist — the company may
        // have edited the paper since the attempt was started.
        final validIds = quiz.questions.map((q) => q.id).toSet();
        saved.answers.forEach((questionId, value) {
          if (validIds.contains(questionId)) _answers[questionId] = value;
        });
      }

      for (final question in quiz.questions) {
        if (question.type.isFreeText) {
          _textControllers[question.id] =
              TextEditingController(text: _answers[question.id] as String? ?? '');
        }
      }

      final restoredStep = saved?.step ?? 0;

      setState(() {
        _quiz = quiz;
        _step = restoredStep >= 0 && restoredStep < quiz.questions.length ? restoredStep : 0;
        _isLoading = false;
      });

      await _startTimer(quiz);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _startTimer(AssessmentQuiz quiz) async {
    final limit = quiz.timeLimitMinutes;
    if (limit == null) return;

    // Stored on first use, so reopening the app resumes the same deadline
    // instead of handing out a fresh allowance.
    final deadline = await _store.deadlineFor(Duration(minutes: limit));
    if (!mounted) return;

    _deadlineMs = deadline;
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final deadline = _deadlineMs;
    if (deadline == null) return;

    final remainingMs = deadline - DateTime.now().millisecondsSinceEpoch;

    if (remainingMs <= 0) {
      _ticker?.cancel();
      _remaining.value = Duration.zero;
      _submit(timedOut: true);
      return;
    }

    _remaining.value = Duration(milliseconds: remainingMs);
  }

  Future<void> _persist() => _store.save(step: _step, answers: _answers);

  /// Asks the server whether this attempt window is still open. It closes the
  /// moment an attempt is recorded — which happens if the student submitted the
  /// same assessment on the web while this screen was open. Whoever submits
  /// first wins; this side is shut down rather than allowed to bank a second
  /// score against one assignment.
  Future<void> _checkAttemptStillOpen() async {
    if (_isSubmitting || _isClosedElsewhere || _quiz == null) return;

    try {
      final isOpen = await _service.isAttemptOpen(widget.assessmentId);
      if (!mounted || isOpen) return;
      await _lockAsSubmittedElsewhere();
    } catch (_) {
      // Offline or a blip — never lock a student out on a failed request; the
      // next tick (and the server-side guard on submit) will catch it.
    }
  }

  /// Stops the quiz dead and sends the student to the recorded result.
  ///
  /// The screen switches to a terminal "closed" state *before* anything async
  /// happens, so there is no window in which a half-dismantled quiz (frozen
  /// clock, live Submit button) is still on screen and tappable.
  Future<void> _lockAsSubmittedElsewhere() async {
    if (_isClosedElsewhere) return;

    _ticker?.cancel();
    _statePoll?.cancel();

    if (mounted) {
      setState(() {
        _isClosedElsewhere = true;
        _isSubmitting = false;
      });
    } else {
      _isClosedElsewhere = true;
    }

    await _store.clear();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Already submitted'),
        content: const Text(
          'This assessment was just submitted on another device. That attempt has been '
          'recorded, so this one has been closed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('View result')),
        ],
      ),
    );

    await _goToRecordedResult();
  }

  /// Replaces this route with the recorded result. The quiz is dropped from the
  /// stack, so backing out of the result can never land on the paper again.
  Future<void> _goToRecordedResult() async {
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AssessmentResultScreen(assessmentId: widget.assessmentId, service: _service),
      ),
    );
  }

  void _goToStep(int index) {
    final quiz = _quiz;
    if (quiz == null || index < 0 || index >= quiz.questions.length) return;

    setState(() => _step = index);
    _persist();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _setAnswer(AssessmentQuestion question, Object? value) {
    setState(() {
      if (value == null || (value is List && value.isEmpty) || (value is String && value.trim().isEmpty)) {
        _answers.remove(question.id);
      } else {
        _answers[question.id] = value;
      }
    });
    _persist();
  }

  Future<void> _submit({bool timedOut = false}) async {
    if (_isSubmitting || _isClosedElsewhere) return;
    setState(() => _isSubmitting = true);

    try {
      final result = await _service.submit(widget.assessmentId, _answers, timedOut: timedOut);
      await _store.clear();
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssessmentResultScreen(assessmentId: widget.assessmentId, result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // The server refused because the window closed between our last poll and
      // this request — the other device won the race by a hair.
      if (e is ApiException && e.statusCode == 409) {
        await _store.clear();
        await _lockAsSubmittedElsewhere();
        return;
      }

      final message = e is ApiException ? e.message : 'Could not submit your assessment.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timedOut ? 'Time is up, but submitting failed: $message' : message),
          action: SnackBarAction(label: 'Retry', onPressed: () => _submit(timedOut: timedOut)),
        ),
      );
    }
  }

  Future<void> _confirmSubmit() async {
    final unanswered = (_quiz?.questions.length ?? 0) - _answers.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit assessment?'),
        content: Text(
          unanswered > 0
              ? "You still have $unanswered ${unanswered == 1 ? 'question' : 'questions'} unanswered. "
                  'They will be marked as incorrect.'
              : 'Your answers will be sent to the employer and cannot be changed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Submit')),
        ],
      ),
    );

    if (confirmed == true) await _submit();
  }

  /// The web warns before unload while the timer is running; same idea here.
  Future<bool> _confirmLeave() async {
    // Nothing left to lose once the attempt is closed or on its way in.
    if (_isSubmitting || _isClosedElsewhere || _quiz == null) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the assessment?'),
        content: Text(
          _deadlineMs != null
              ? 'Your answers are saved, but the timer keeps running while you are away.'
              : 'Your answers are saved and you can come back to finish later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Leave')),
        ],
      ),
    );

    return leave ?? false;
  }

  Future<void> _handleBackRequest() async {
    if (await _confirmLeave() && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackRequest();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isClosedElsewhere
            // Terminal state: once the attempt is recorded elsewhere the paper
            // is gone. Nothing here can be answered or re-submitted, even if
            // the student sits on this screen.
            ? _ClosedElsewhere(onViewResult: _goToRecordedResult)
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _QuizError(error: _error!, onRetry: _load)
                    : quiz == null || quiz.questions.isEmpty
                        ? const _EmptyQuiz()
                        : _buildQuiz(quiz),
      ),
    );
  }

  Widget _buildQuiz(AssessmentQuiz quiz) {
    final question = quiz.questions[_step];
    final isLast = _step == quiz.questions.length - 1;

    return Column(
      children: [
        _QuizHeader(
          title: quiz.title,
          remaining: _deadlineMs == null ? null : _remaining,
          current: _step + 1,
          total: quiz.questions.length,
          key: const ValueKey('quiz-header'),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              _QuestionCard(
                question: question,
                answer: _answers[question.id],
                textController: _textControllers[question.id],
                onChanged: (value) => _setAnswer(question, value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _goToStep(_step - 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: _step > 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (isLast ? _confirmSubmit : () => _goToStep(_step + 1)),
                      style: isLast
                          ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A7F4B))
                          : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(isLast ? 'Submit Assessment' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Blue header: title, countdown pill and "Question n / N".
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    super.key,
    required this.title,
    required this.remaining,
    required this.current,
    required this.total,
  });

  final String title;

  /// Null when the assessment is untimed — the pill then shows `--:--`, as the
  /// web does. Otherwise only the pill rebuilds each second, not the page.
  final ValueNotifier<Duration?>? remaining;
  final int current;
  final int total;

  /// Stand-in listenable for an untimed assessment, so the builder doesn't
  /// allocate a throwaway notifier on every build.
  static final ValueNotifier<Duration?> _untimed = ValueNotifier<Duration?>(null);

  static String _clock(Duration? value) {
    if (value == null) return '--:--';
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('TIME REMAINING'),
                        const SizedBox(height: 6),
                        // Rebuilds on its own each second; the questions below
                        // are untouched by the tick.
                        ValueListenableBuilder<Duration?>(
                          valueListenable: remaining ?? _untimed,
                          builder: (context, value, _) {
                            // Under a minute left, the pill turns red.
                            final isUrgent =
                                remaining != null && value != null && value.inSeconds <= 60;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isUrgent ? const Color(0xFFE03E3E) : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 15,
                                    color: isUrgent ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _clock(remaining == null ? null : value),
                                    style: TextStyle(
                                      color: isUrgent ? Colors.white : AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Label('PROGRESS'),
                      const SizedBox(height: 8),
                      Text(
                        'Question $current / $total',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// The white card holding the question, its optional image, and the answer
/// widget for its type.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.answer,
    required this.textController,
    required this.onChanged,
  });

  final AssessmentQuestion question;
  final Object? answer;
  final TextEditingController? textController;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.45),
          ),
          if (question.description != null && question.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              question.description!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
            ),
          ],
          if (question.imageUrl != null) ...[
            const SizedBox(height: 14),
            _QuestionImage(url: question.imageUrl!),
          ],
          const SizedBox(height: 18),
          _AnswerInput(question: question, answer: answer, textController: textController, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Renders the right control for the question type. Companies author
/// multiple choice, checkboxes and dropdowns today; the rest are handled so a
/// question authored later never renders as a dead card.
class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.question,
    required this.answer,
    required this.textController,
    required this.onChanged,
  });

  final AssessmentQuestion question;
  final Object? answer;
  final TextEditingController? textController;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.checkbox:
        final selected = (answer as List?)?.cast<int>().toSet() ?? <int>{};
        return Column(
          children: [
            for (final choice in question.choices)
              _ChoiceTile(
                text: choice.text,
                selected: selected.contains(choice.id),
                isCheckbox: true,
                onTap: () {
                  final next = Set<int>.from(selected);
                  next.contains(choice.id) ? next.remove(choice.id) : next.add(choice.id);
                  onChanged(next.toList()..sort());
                },
              ),
          ],
        );

      case QuestionType.dropdown:
        return DropdownButtonFormField<int>(
          initialValue: answer is int ? answer as int : null,
          isExpanded: true,
          hint: const Text('Select an answer'),
          items: [
            for (final choice in question.choices)
              DropdownMenuItem(value: choice.id, child: Text(choice.text, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        );

      case QuestionType.shortAnswer:
        return TextField(
          controller: textController,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Type your answer'),
        );

      case QuestionType.longAnswer:
        return TextField(
          controller: textController,
          onChanged: onChanged,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Type your answer'),
        );

      case QuestionType.multipleChoice:
      case QuestionType.identification:
        return Column(
          children: [
            for (final choice in question.choices)
              _ChoiceTile(
                text: choice.text,
                selected: answer == choice.id,
                isCheckbox: false,
                onTap: () => onChanged(choice.id),
              ),
          ],
        );
    }
  }
}

/// The bordered option row from the mockup — square indicator for checkboxes,
/// round for single-answer questions.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.text,
    required this.selected,
    required this.isCheckbox,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool isCheckbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF5F9FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Indicator(selected: selected, isCheckbox: isCheckbox),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: AppColors.textDark,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.isCheckbox});

  final bool selected;
  final bool isCheckbox;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: isCheckbox ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isCheckbox ? BorderRadius.circular(5) : null,
        border: Border.all(color: selected ? AppColors.primary : const Color(0xFFC5CBD8), width: 2),
        color: selected && isCheckbox ? AppColors.primary : Colors.transparent,
      ),
      child: selected
          ? (isCheckbox
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : const DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: SizedBox(width: 11, height: 11),
                ))
          : null,
    );
  }
}

/// Question illustration, tappable to enlarge — the web's lightbox. Handles
/// both hosted images and the inline `data:` URIs the question builder saves.
class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.url});

  final String url;

  /// Question images arrive as inline `data:` URIs that can run to tens of
  /// kilobytes of base64. Decoding is memoised per URL — doing it inside build
  /// meant re-decoding the same image on every rebuild, which is expensive
  /// enough to stutter while a student is tapping through answers.
  static final Map<String, Uint8List?> _decodedCache = {};

  static Uint8List? _decodeDataUri(String value) {
    if (!value.startsWith('data:')) return null;

    return _decodedCache.putIfAbsent(value, () {
      final separator = value.indexOf(',');
      if (separator == -1) return null;

      try {
        return base64Decode(value.substring(separator + 1));
      } catch (_) {
        return null;
      }
    });
  }

  Widget _buildImage({BoxFit fit = BoxFit.cover}) {
    final bytes = _decodeDataUri(url);
    const broken = Padding(
      padding: EdgeInsets.all(12),
      child: Text('Image unavailable', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    );

    if (bytes != null) {
      return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => broken);
    }
    return Image.network(url, fit: fit, errorBuilder: (_, _, _) => broken);
  }

  void _openLightbox(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (dialogContext, _, _) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(child: _buildImage(fit: BoxFit.contain)),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(dialogContext).padding.top + 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLightbox(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          color: AppColors.background,
          child: _buildImage(),
        ),
      ),
    );
  }
}

class _QuizError extends StatelessWidget {
  const _QuizError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    // A 409 means an attempt already landed for this assignment window — the
    // student can't retake it, so send them to the result instead of retrying.
    final apiError = error is ApiException ? error as ApiException : null;
    final alreadyCompleted = apiError?.statusCode == 409;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              apiError?.message ?? 'Could not load this assessment.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (alreadyCompleted)
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Back to Applications'),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// What the quiz becomes once the attempt is recorded somewhere else. There is
/// deliberately no way back into the questions from here.
class _ClosedElsewhere extends StatelessWidget {
  const _ClosedElsewhere({required this.onViewResult});

  final Future<void> Function() onViewResult;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text(
              'Assessment already submitted',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'This assessment was submitted on another device. That attempt has been recorded, '
              'so this one is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton(onPressed: onViewResult, child: const Text('View result')),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuiz extends StatelessWidget {
  const _EmptyQuiz();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'This assessment has no questions yet. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
