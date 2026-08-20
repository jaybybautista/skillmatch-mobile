import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A quiz in progress, restored after the app is backgrounded or killed.
class SavedQuizState {
  SavedQuizState({required this.step, required this.answers});

  final int step;
  final Map<int, Object> answers;
}

/// Local persistence for an in-progress attempt.
///
/// The web quiz keeps the same three things in localStorage — the current
/// question, the answers so far, and the wall-clock deadline — so a refresh
/// doesn't cost the student their progress *or* hand them a fresh timer. This
/// is the mobile equivalent, with matching key names.
///
/// Answers only ever live here until the attempt is submitted; grading is
/// server-side, so nothing here can affect a score.
class QuizStateStore {
  QuizStateStore(this.assessmentId);

  final int assessmentId;

  String get _stateKey => 'student_quiz_state_$assessmentId';
  String get _timerKey => 'student_quiz_timer_end_$assessmentId';

  Future<void> save({
    required int step,
    required Map<int, Object> answers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stateKey,
      jsonEncode({
        'step': step,
        'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
      }),
    );
  }

  Future<SavedQuizState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawAnswers =
          decoded['answers'] as Map<String, dynamic>? ?? const {};

      final answers = <int, Object>{};
      rawAnswers.forEach((key, value) {
        final questionId = int.tryParse(key);
        if (questionId == null || value == null) return;
        answers[questionId] = value is List
            ? value.map((e) => (e as num).toInt()).toList()
            : value as Object;
      });

      return SavedQuizState(
        step: (decoded['step'] as num?)?.toInt() ?? 0,
        answers: answers,
      );
    } catch (_) {
      // Corrupt or written by an older build — start clean rather than crash.
      return null;
    }
  }

  /// The attempt's deadline as epoch milliseconds, created on first call so
  /// closing and reopening the app doesn't restart the clock.
  Future<int> deadlineFor(Duration limit) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt(_timerKey);
    if (existing != null) return existing;

    final deadline =
        DateTime.now().millisecondsSinceEpoch + limit.inMilliseconds;
    await prefs.setInt(_timerKey, deadline);
    return deadline;
  }

  /// Called once the attempt has been submitted (or abandoned), so a retake
  /// after reassignment starts from scratch with a full clock.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await prefs.remove(_timerKey);
  }
}
