// CBT Pacing & Panic Forensics Engine for the Renance app.
// Port of the web's `apps/web/lib/pacing.ts` (the contributor feature
// from Ayoola-tech2024's PR #1) so the phone trains the same clock
// discipline the site does: avoid time traps, never panic the last
// stretch of a JAMB/WAEC/NECO paper.
// Pure, zero-dependency logic, runs 100% offline-first.

enum PacingState { onTrack, lingering, trapRisk }

/// Live read-out for the question currently on screen.
class LivePacingInfo {
  const LivePacingInfo({
    required this.elapsedSec,
    required this.targetSec,
    required this.ratio,
    required this.state,
    required this.label,
    required this.advice,
  });

  final int elapsedSec;
  final int targetSec;
  final double ratio;
  final PacingState state;
  final String label;
  final String advice;
}

/// Per-question time record harvested while a paper was played.
class QuestionTimeRecord {
  const QuestionTimeRecord({
    required this.questionId,
    required this.index,
    this.stem = '',
    this.topic = '',
    required this.durationMs,
    this.selected = '',
    this.correct = false,
  });

  final String questionId;
  final int index;
  final String stem;
  final String topic;
  final int durationMs;
  final String selected;
  final bool correct;
}

/// One question that ate far more than its fair share of the clock.
class TimeTrap {
  const TimeTrap({
    required this.questionId,
    required this.index,
    required this.topic,
    required this.durationSec,
    required this.targetSec,
    required this.excessSec,
    required this.correct,
  });

  final String questionId;
  final int index;
  final String topic;
  final int durationSec;
  final int targetSec;
  final int excessSec;
  final bool correct;
}

/// The post-sitting pacing report shown under the score.
class PacingForensicsReport {
  const PacingForensicsReport({
    required this.targetSecPerQuestion,
    required this.averageSecPerQuestion,
    required this.pacingEfficiencyPct,
    required this.timeTraps,
    required this.totalTimeTrapsDurationSec,
    required this.hasPanicZone,
    required this.panicQuestionsCount,
    required this.panicZoneStartIndex,
    required this.estimatedRecoverableMarks,
    required this.summaryFeedback,
  });

  final int targetSecPerQuestion;
  final int averageSecPerQuestion;
  final int pacingEfficiencyPct;
  final List<TimeTrap> timeTraps;
  final int totalTimeTrapsDurationSec;
  final bool hasPanicZone;
  final int panicQuestionsCount;
  final int panicZoneStartIndex;
  final int estimatedRecoverableMarks;
  final String summaryFeedback;
}

const int _kMinTargetSec = 10;

int _targetSecFor(int totalDurationMinutes, int questionCount) {
  final int safeCount = questionCount < 1 ? 1 : questionCount;
  final int totalSec = (totalDurationMinutes * 60) < 1 ? 1 : totalDurationMinutes * 60;
  final int raw = (totalSec / safeCount).round();
  return raw < _kMinTargetSec ? _kMinTargetSec : raw;
}

/// Evaluates live pacing for the question currently on screen.
LivePacingInfo assessLivePacing(
  int currentQuestionMs,
  int totalDurationMinutes,
  int questionCount,
) {
  final int targetSec = _targetSecFor(totalDurationMinutes, questionCount);
  final int elapsedSec = (currentQuestionMs ~/ 1000).clamp(0, 1 << 31);
  final double ratio = elapsedSec / targetSec;

  if (ratio >= 2.0) {
    return LivePacingInfo(
      elapsedSec: elapsedSec,
      targetSec: targetSec,
      ratio: ratio,
      state: PacingState.trapRisk,
      label: 'Time Trap Risk',
      advice: 'You have spent double the target time. Flag this question and move on!',
    );
  }
  if (ratio >= 1.25) {
    return LivePacingInfo(
      elapsedSec: elapsedSec,
      targetSec: targetSec,
      ratio: ratio,
      state: PacingState.lingering,
      label: 'Lingering',
      advice: 'Pace is slowing down. Narrow your options and pick your best guess.',
    );
  }
  return LivePacingInfo(
    elapsedSec: elapsedSec,
    targetSec: targetSec,
    ratio: ratio,
    state: PacingState.onTrack,
    label: 'On Track',
    advice: 'Good steady speed. Keep moving through the paper.',
  );
}

/// Computes the post-sitting panic and time-mismanagement forensics.
PacingForensicsReport computePacingForensics(
  List<QuestionTimeRecord> records,
  int totalDurationMinutes,
  int questionCount,
) {
  final int targetSec = _targetSecFor(totalDurationMinutes, questionCount);

  if (records.isEmpty) {
    return PacingForensicsReport(
      targetSecPerQuestion: targetSec,
      averageSecPerQuestion: 0,
      pacingEfficiencyPct: 100,
      timeTraps: const <TimeTrap>[],
      totalTimeTrapsDurationSec: 0,
      hasPanicZone: false,
      panicQuestionsCount: 0,
      panicZoneStartIndex: 0,
      estimatedRecoverableMarks: 0,
      summaryFeedback: 'No pacing records recorded for this sitting.',
    );
  }

  final int totalUsedMs = records.fold<int>(0, (int acc, QuestionTimeRecord r) => acc + r.durationMs);
  final int avgSec = (totalUsedMs / records.length / 1000).round();

  // 1. Time traps: anything that ate 1.8x its target share of the clock.
  final List<TimeTrap> timeTraps = <TimeTrap>[];
  int totalTrapSec = 0;
  for (final QuestionTimeRecord r in records) {
    final int sec = (r.durationMs / 1000).round();
    if (sec >= (targetSec * 1.8).round()) {
      final int excess = sec - targetSec;
      totalTrapSec += excess;
      timeTraps.add(TimeTrap(
        questionId: r.questionId,
        index: r.index,
        topic: r.topic.isEmpty ? 'General Question' : r.topic,
        durationSec: sec,
        targetSec: targetSec,
        excessSec: excess,
        correct: r.correct,
      ));
    }
  }
  timeTraps.sort((TimeTrap a, TimeTrap b) => b.durationSec.compareTo(a.durationSec));

  // 2. End-of-paper panic zone: the last fifth of the paper rushed
  //    under 14 seconds per question after time was burned early.
  final int finalFifthCount = (records.length * 0.2).floor() < 3 ? 3 : (records.length * 0.2).floor();
  final int finalFifthStartIndex = records.length - finalFifthCount < 0 ? 0 : records.length - finalFifthCount;
  final List<QuestionTimeRecord> finalQuestions = records.sublist(finalFifthStartIndex);

  final List<QuestionTimeRecord> rushedInEnd =
      finalQuestions.where((QuestionTimeRecord q) => q.durationMs / 1000 < 14).toList();
  final bool hasPanicZone = finalQuestions.length >= 3 &&
      rushedInEnd.length >= (finalQuestions.length * 0.6).ceil() &&
      totalTrapSec > targetSec * 2;

  final int panicCount = hasPanicZone ? rushedInEnd.length : 0;

  // 3. Pacing efficiency: share of questions answered within 1.5x target.
  final int onTimeCount =
      records.where((QuestionTimeRecord r) => r.durationMs / 1000 <= targetSec * 1.5).length;
  final int pacingEfficiencyPct = ((onTimeCount / records.length) * 100).round();

  // 4. Estimated recoverable marks: time burned and still wrong, plus
  //    the panic-rush losses at the tail of the paper.
  final int trapLosses = timeTraps.where((TimeTrap t) => !t.correct).length;
  final int panicLosses = hasPanicZone
      ? finalQuestions.where((QuestionTimeRecord q) => q.durationMs / 1000 < 14 && !q.correct).length
      : 0;
  final int estimatedRecoverableMarks =
      ((trapLosses * 1.0 + panicLosses * 0.8).round()).clamp(0, records.length);

  // 5. Summary feedback.
  String feedback = 'Your pacing was well-balanced across the entire paper.';
  if (timeTraps.isNotEmpty && hasPanicZone) {
    feedback =
        'You spent ${(totalTrapSec / 60).round()} extra minutes battling ${timeTraps.length} tough questions, '
        'which forced you to rush the last ${rushedInEnd.length} questions in under 14 seconds each.';
  } else if (timeTraps.isNotEmpty) {
    feedback =
        'You spent extended time on ${timeTraps.length} questions. In real CBT, flagging these early '
        'protects your points on easier questions down the road.';
  } else if (hasPanicZone) {
    feedback = 'You had to rush through the final questions. Try budgeting slightly less time for the early questions.';
  }

  return PacingForensicsReport(
    targetSecPerQuestion: targetSec,
    averageSecPerQuestion: avgSec,
    pacingEfficiencyPct: pacingEfficiencyPct,
    timeTraps: timeTraps,
    totalTimeTrapsDurationSec: totalTrapSec,
    hasPanicZone: hasPanicZone,
    panicQuestionsCount: panicCount,
    panicZoneStartIndex: finalFifthStartIndex,
    estimatedRecoverableMarks: estimatedRecoverableMarks,
    summaryFeedback: feedback,
  );
}
