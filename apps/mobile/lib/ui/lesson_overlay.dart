/// The LessonOverlay - the full-screen lesson player, the Flutter twin
/// of the web's components/learn/lesson-overlay.tsx: study phase (intro
/// -> notes -> drawings -> key points), the mixed quiz (AI items + real
/// past questions, letters, reveals, type-in blanks, combo toasts,
/// hearts), the done screen with reward chips, and the celebration
/// queue (chest -> streak -> milestone). Polls the 202 generating state
/// exactly like the web (3s beats, up to 110s).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_controller.dart';
import '../learn_models.dart';
import '../qtext.dart';
import 'celebrations.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

enum LessonMode { lesson, practice, review, revision }

/// Opens the full-screen player.
class LessonOverlay extends StatelessWidget {
  const LessonOverlay({
    super.key,
    required this.mode,
    this.topicId,
    this.courseId,
    this.unit,
    this.courseCode = '',
    this.onFinished,
  });

  final LessonMode mode;
  final String? topicId;
  final String? courseId;
  final int? unit;
  final String courseCode;
  final VoidCallback? onFinished;

  static Future<void> open(
    BuildContext context, {
    required LessonMode mode,
    String? topicId,
    String? courseId,
    int? unit,
    String courseCode = '',
    VoidCallback? onFinished,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LessonOverlay(
          mode: mode,
          topicId: topicId,
          courseId: courseId,
          unit: unit,
          courseCode: courseCode,
          onFinished: onFinished,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _LessonOverlayScreen(
      mode: mode,
      topicId: topicId,
      courseId: courseId,
      unit: unit,
      courseCode: courseCode,
      onFinished: onFinished,
    );
  }
}

class _LessonOverlayScreen extends StatefulWidget {
  const _LessonOverlayScreen({
    required this.mode,
    required this.topicId,
    required this.courseId,
    required this.unit,
    required this.courseCode,
    required this.onFinished,
  });

  final LessonMode mode;
  final String? topicId;
  final String? courseId;
  final int? unit;
  final String courseCode;
  final VoidCallback? onFinished;

  @override
  State<_LessonOverlayScreen> createState() => _LessonOverlayScreenState();
}

enum _Phase { loading, error, study, quiz, done, banking }

class _LessonOverlayScreenState extends State<_LessonOverlayScreen> {
  _Phase _phase = _Phase.loading;
  int _loadAttempts = 0;
  Timer? _retryTimer;

  LessonDoc? _doc;
  List<LessonQuizQ> _questions = <LessonQuizQ>[];

  // study paging
  int _page = 0;

  // quiz state
  int _qIndex = 0;
  String? _picked;
  String? _typed;
  bool _revealed = false;
  bool _checked = false;
  int _correct = 0;
  int _combo = 0;
  int _maxCombo = 0;
  final List<String> _mistakes = <String>[];
  bool _comboToastVisible = false;
  Timer? _comboToastTimer;

  CompleteResult? _result;

  // The rotating loader copy (web: every 2.6s).
  static const List<String> _loadingLines = <String>[
    'Sharpening the explanation…',
    'Picking real past questions…',
    'Drawing the diagrams…',
    'Stacking your XP…',
    'Almost there…',
  ];
  int _loadingLine = 0;
  Timer? _loadingTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _loadingTicker = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && _phase == _Phase.loading) {
        setState(() => _loadingLine = (_loadingLine + 1) % _loadingLines.length);
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _loadingTicker?.cancel();
    _comboToastTimer?.cancel();
    _abandoned = false;
    super.dispose();
  }

  bool _abandoned = true;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.loading);
    final ApiClient api = context.read<ApiClient>();
    try {
      switch (widget.mode) {
        case LessonMode.lesson:
          LessonDoc? doc;
          // Poll the 202 generating state: 3s beats, up to ~110s.
          final DateTime deadline =
              DateTime.now().add(const Duration(seconds: 110));
          while (DateTime.now().isBefore(deadline)) {
            doc = await api.learnLessonContent(widget.topicId!);
            if (doc != null) break;
            await Future<void>.delayed(const Duration(seconds: 3));
            if (!mounted) return;
          }
          if (doc == null) {
            throw const NetworkException(
              'The generator is still writing this lesson - reopen it in a '
              'few seconds.',
            );
          }
          _doc = doc;
          _questions = doc.quiz;
          if (!mounted) return;
          setState(() => _phase = _Phase.study);
          return;
        case LessonMode.practice:
          final PracticeSet set = await api.learnPractice();
          _questions = set.questions;
        case LessonMode.review:
          final PracticeSet set =
              await api.learnReviewSet(widget.courseId!, widget.unit ?? 1);
          _questions = set.questions;
        case LessonMode.revision:
          final PracticeSet set =
              await api.learnRevisionSet(widget.courseId!, widget.unit ?? 1);
          _questions = set.questions;
      }
      if (!mounted) return;
      if (_questions.isEmpty) {
        setState(() => _phase = _Phase.error);
        return;
      }
      setState(() => _phase = _Phase.quiz);
    } on ApiException catch (e) {
      _failLoad(e.message);
    } on NetworkException catch (e) {
      _failLoad(e.message);
    }
  }

  void _failLoad(String message) {
    if (!mounted) return;
    _loadAttempts += 1;
    if (_loadAttempts >= 4) {
      setState(() => _phase = _Phase.error);
      return;
    }
    // Quiet self-retry after 5s (the web's retry loop).
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), _load);
  }

  // ----------------------------------------------------------- study

  int get _studyPageCount {
    // intro + notes + drawings? + keypoints
    final LessonDoc d = _doc!;
    int n = 1 + d.notes.length + 1;
    if (d.drawings.isNotEmpty) n += 1;
    return n;
  }

  void _nextPage() {
    if (_page < _studyPageCount - 1) {
      setState(() => _page += 1);
    } else {
      setState(() => _phase = _Phase.quiz);
    }
  }

  // ------------------------------------------------------------ quiz

  void _pick(String option) {
    if (_revealed) return;
    setState(() => _picked = option);
  }

  void _check() {
    if (_revealed) return;
    final LessonQuizQ q = _questions[_qIndex];
    final String answer = _typed?.trim() ?? _picked ?? '';
    if (answer.isEmpty) return;
    final bool ok = answer.toLowerCase() == q.answer.toLowerCase().trim() ||
        (q.options[answer]?.toLowerCase() == q.answer.toLowerCase());
    setState(() {
      _revealed = true;
      _checked = ok;
      if (ok) {
        _correct += 1;
        _combo += 1;
        if (_combo > _maxCombo) _maxCombo = _combo;
        if (_combo > 0 && _combo % 3 == 0) {
          _comboToastVisible = true;
          _comboToastTimer?.cancel();
          _comboToastTimer = Timer(const Duration(milliseconds: 1600), () {
            if (mounted) setState(() => _comboToastVisible = false);
          });
        }
      } else {
        _combo = 0;
        if (!_mistakes.contains(q.id)) _mistakes.add(q.id);
      }
    });
  }

  void _advance() {
    if (_qIndex < _questions.length - 1) {
      setState(() {
        _qIndex += 1;
        _picked = null;
        _typed = null;
        _revealed = false;
        _checked = false;
      });
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.banking);
    final ApiClient api = context.read<ApiClient>();
    final LearnController learn = context.read<LearnController>();
    try {
      switch (widget.mode) {
        case LessonMode.lesson:
          _result = await api.learnProgress(
            topicId: widget.topicId!,
            correct: _correct,
            total: _questions.length,
            maxCombo: _maxCombo,
            mistakes: _mistakes,
          );
        case LessonMode.practice:
        case LessonMode.review:
        case LessonMode.revision:
          _result = await api.learnSubmitPractice(
            correct: _correct,
            total: _questions.length,
            resolvedIds: _mistakes,
          );
      }
      _abandoned = false;
      await learn.refresh();
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
      showConfetti(context);
      await _playCelebrationQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => _phase = _Phase.done);
    } on NetworkException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => _phase = _Phase.done);
    }
  }

  /// The web's queue: chest, then streak, then milestone - one at a
  /// time, each driven by the CompleteResult flags.
  Future<void> _playCelebrationQueue() async {
    final CompleteResult? res = _result;
    if (res == null) return;
    if (res.chest != null) {
      await showChestCelebration(
        context,
        kind: res.chest!.kind,
        amount: res.chest!.amount,
        label: res.chest!.label,
      );
    }
    if (res.streakUp && res.streak > 0) {
      await showStreakCelebration(
        context,
        streak: res.streak,
        forgiven: res.streakForgiven,
        forgivesLeft: res.streakForgivesLeft,
      );
    }
    if (res.milestone != null) {
      await showMilestoneCelebration(
        context,
        milestone: res.milestone!,
        onViewFeed: () {
          Navigator.of(context).popUntil((Route<Object?> r) => r.isFirst);
        },
      );
    }
  }

  void _close() async {
    // Abandoned runs still bank their mistakes (Supreme parity).
    if (_phase == _Phase.quiz && _mistakes.isNotEmpty && _abandoned) {
      final ApiClient api = context.read<ApiClient>();
      if (widget.mode == LessonMode.lesson) {
        try {
          await api.learnProgress(
            topicId: widget.topicId!,
            correct: _correct,
            total: _questions.length - _qIndex + _correct,
            maxCombo: _maxCombo,
            mistakes: _mistakes,
            abandoned: true,
          );
        } catch (_) {}
      }
    }
    if (mounted) {
      widget.onFinished?.call();
      Navigator.of(context).pop();
    }
  }

  // ----------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _body(context)),
            if (_comboToastVisible)
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(child: ComboToast(count: _combo)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (_phase) {
      _Phase.loading => _LoadingView(
          line: _loadingLines[_loadingLine],
        ),
      _Phase.error => _ErrorView(onBack: _close),
      _Phase.study => _StudyView(
          doc: _doc!,
          page: _page,
          pageCount: _studyPageCount,
          onNext: _nextPage,
          onBack: _page > 0 ? () => setState(() => _page -= 1) : null,
          onStartQuiz: () => setState(() => _phase = _Phase.quiz),
          onClose: _close,
        ),
      _Phase.quiz => _QuizView(
          questions: _questions,
          index: _qIndex,
          picked: _picked,
          typed: _typed,
          revealed: _revealed,
          checked: _checked,
          courseCode: widget.courseCode,
          onPick: _pick,
          onTyped: (String v) => setState(() => _typed = v),
          onCheck: _check,
          onAdvance: _advance,
          onClose: _close,
        ),
      _Phase.banking => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const RenanceMark(size: 40, busy: true),
              const SizedBox(height: 12),
              Text(
                'Banking your XP…',
                style: RenanceText.caption.copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
      _Phase.done => _DoneView(
          result: _result,
          correct: _correct,
          total: _questions.length,
          mode: widget.mode,
          onContinue: () {
            widget.onFinished?.call();
            Navigator.of(context).pop();
          },
        ),
    };
  }
}

// ------------------------------------------------------------ loading

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const RenanceMark(size: 64, busy: true),
          const SizedBox(height: 18),
          Text(
            line,
            style: RenanceText.bodyMedium.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MsIcon('cloud_off', size: 44, color: context.textSecondary),
            const SizedBox(height: 14),
            const Text(
              'This lesson could not load',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The generator may be busy - close and reopen in a few seconds. '
              'Everything else on your account is safe.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 18),
            TactileButton(
              onPressed: onBack,
              height: 46,
              child: const Text('Back to my course'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- study

class _StudyView extends StatelessWidget {
  const _StudyView({
    required this.doc,
    required this.page,
    required this.pageCount,
    required this.onNext,
    required this.onBack,
    required this.onStartQuiz,
    required this.onClose,
  });

  final LessonDoc doc;
  final int page;
  final int pageCount;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onStartQuiz;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _LessonHeader(
          progress: (page + 1) / pageCount,
          onClose: onClose,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
              const Spacer(),
              Text(
                'Part ${page + 1} of $pageCount',
                style: RenanceText.labelMono.copyWith(
                  fontSize: 11.5,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey<int>(page),
                child: _pageBody(context, page),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: _footer(context),
        ),
      ],
    );
  }

  Widget _pageBody(BuildContext context, int page) {
    // Page 0: the intro card.
    if (page == 0) {
      final int notesLeft =
          doc.notes.length + (doc.drawings.isNotEmpty ? 1 : 0) + 1 - 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            doc.course.toUpperCase(),
            style: RenanceText.overline.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            doc.title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          QuestionText(
            doc.summary,
            style: RenanceText.bodyBase.copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          Text(
            notesLeft > 0
                ? '$notesLeft more section${notesLeft == 1 ? '' : 's'} to '
                    'read, then ${doc.quiz.length} questions. Tap Next to keep '
                    'going.'
                : '${doc.quiz.length} questions are waiting. Tap Next to keep '
                    'going.',
            style: RenanceText.caption.copyWith(color: context.textSecondary),
          ),
        ],
      );
    }
    // Notes pages.
    int cursor = 1;
    if (page < cursor + doc.notes.length) {
      final LessonNote note = doc.notes[page - cursor];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${page - cursor + 1}. ${note.heading}',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          QuestionText(
            note.body,
            style: RenanceText.bodyBase.copyWith(height: 1.6, fontSize: 15),
          ),
        ],
      );
    }
    cursor += doc.notes.length;
    // Drawings page.
    if (doc.drawings.isNotEmpty && page == cursor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Real drawings for this topic',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final LearnDrawing d in doc.drawings)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DrawingFigure(drawing: d),
            ),
        ],
      );
    }
    cursor += doc.drawings.isNotEmpty ? 1 : 0;
    // Key points page (last).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Key points',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String k in doc.keyPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: MsIcon(
                          'check_circle',
                          size: 17,
                          color: context.primary,
                          fill: true,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: QuestionText(
                          k,
                          style: RenanceText.bodyBase.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final bool last = page == pageCount - 1;
    return Row(
      children: <Widget>[
        if (onBack != null)
          Expanded(
            child: TactileButton(
              onPressed: onBack,
              height: 48,
              face: context.card,
              onFace: context.ink,
              edge: mixTowardBlack(context.outlineVariant, 0.62),
              child: const Text('Back'),
            ),
          ),
        if (onBack != null) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TactileButton(
            onPressed: last ? onStartQuiz : onNext,
            height: 48,
            child: Text(last ? 'Start quiz (${doc.quiz.length})' : 'Next section'),
          ),
        ),
      ],
    );
  }
}

/// One server SVG drawing, currentColor resolved to the theme ink.
class _DrawingFigure extends StatelessWidget {
  const _DrawingFigure({required this.drawing});

  final LearnDrawing drawing;

  @override
  Widget build(BuildContext context) {
    final String ink =
        context.darkChrome ? '#F0F3F6' : '#3C3C46';
    final String svg = drawing.svg
        .replaceAll('currentColor', ink)
        .replaceAll(' font-family="inherit"', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.outlineVariant, width: 2),
          ),
          child: SvgPicture.string(
            svg,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox(height: 120),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          drawing.title,
          style: RenanceText.caption.copyWith(
            color: context.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- quiz

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.questions,
    required this.index,
    required this.picked,
    required this.typed,
    required this.revealed,
    required this.checked,
    required this.courseCode,
    required this.onPick,
    required this.onTyped,
    required this.onCheck,
    required this.onAdvance,
    required this.onClose,
  });

  final List<LessonQuizQ> questions;
  final int index;
  final String? picked;
  final String? typed;
  final bool revealed;
  final bool checked;
  final String courseCode;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onTyped;
  final VoidCallback onCheck;
  final VoidCallback onAdvance;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final LessonQuizQ q = questions[index];
    return Column(
      children: <Widget>[
        _LessonHeader(
          progress: (index + 1) / questions.length,
          onClose: onClose,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Question ${index + 1} of ${questions.length}',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    _FlagButton(question: q, courseCode: courseCode),
                  ],
                ),
                const SizedBox(height: 12),
                if (q.fromBank)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: RenanceColors.macawLight,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: RenanceColors.macawRing),
                    ),
                    child: Text(
                      q.year > 0 ? 'Past question ${q.year}' : 'Real past question',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                  ),
                QuestionText(
                  q.stem,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (q.isTypeIn)
                  _TypeInAnswer(
                    enabled: !revealed,
                    onTyped: onTyped,
                    onCheck: onCheck,
                  )
                else
                  for (final MapEntry<String, String> opt in q.options.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuizOption(
                        letter: opt.key,
                        text: opt.value,
                        state: _optionState(q, opt.key),
                        onTap: () => onPick(opt.key),
                      ),
                    ),
                if (revealed) ...<Widget>[
                  const SizedBox(height: 6),
                  _RevealBanner(q: q, ok: checked),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: TactileButton(
            onPressed: revealed ? onAdvance : onCheck,
            height: 50,
            child: Text(
              revealed
                  ? (index == questions.length - 1 ? 'Finish' : 'Continue')
                  : 'Check',
            ),
          ),
        ),
      ],
    );
  }

  KeyCardState _optionState(LessonQuizQ q, String letter) {
    if (!revealed) {
      return picked == letter ? KeyCardState.selected : KeyCardState.rest;
    }
    final String answerText = q.options[letter] ?? letter;
    if (answerText.toLowerCase() == q.answer.toLowerCase()) {
      return KeyCardState.correct;
    }
    if (picked == letter) {
      return KeyCardState.wrong;
    }
    return KeyCardState.rest;
  }
}

/// The lesson header: close key, the progress bar, hearts and gems.
class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.progress, this.onClose});

  final double progress;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final LearnController learn = context.watch<LearnController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: <Widget>[
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.card,
                  border: Border.all(color: context.outlineVariant),
                ),
                child: MsIcon('close', size: 20, color: context.ink),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: LearnProgressBar(value: progress, height: 10),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MsIcon(
                'favorite',
                size: 17,
                fill: true,
                color: RenanceColors.cardinal,
              ),
              const SizedBox(width: 3),
              Text('${learn.hearts}', style: RenanceText.labelMono),
              const SizedBox(width: 8),
              const GemIcon(size: 15),
              const SizedBox(width: 3),
              Text('${learn.gems}', style: RenanceText.labelMono),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final KeyCardState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool done = state == KeyCardState.correct || state == KeyCardState.wrong;
    return TactileKeyCard(
      label: text,
      badge: letter,
      state: state,
      onTap: done ? () {} : onTap,
    );
  }
}

class _TypeInAnswer extends StatefulWidget {
  const _TypeInAnswer({
    required this.enabled,
    required this.onTyped,
    required this.onCheck,
  });

  final bool enabled;
  final ValueChanged<String> onTyped;
  final VoidCallback onCheck;

  @override
  State<_TypeInAnswer> createState() => _TypeInAnswerState();
}

class _TypeInAnswerState extends State<_TypeInAnswer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      onChanged: widget.onTyped,
      onSubmitted: (_) => widget.onCheck(),
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'Type your answer…',
      ),
    );
  }
}

class _RevealBanner extends StatelessWidget {
  const _RevealBanner({required this.q, required this.ok});

  final LessonQuizQ q;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    if (ok) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.primary),
        ),
        child: Row(
          children: <Widget>[
            MsIcon('check_circle',
                size: 20, color: context.primary, fill: true),
            const SizedBox(width: 8),
            const Text(
              'Correct!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Answer: ${q.answer}',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.onErrorContainer,
            ),
          ),
          if (q.explanation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            QuestionText(
              q.explanation,
              style: RenanceText.caption.copyWith(
                color: context.onErrorContainer,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The flag (report) affordance on one quiz question.
class _FlagButton extends StatelessWidget {
  const _FlagButton({required this.question, required this.courseCode});

  final LessonQuizQ question;
  final String courseCode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showFlagQuestionSheet(
        context,
        question: question,
        courseCode: courseCode,
        source: 'lesson',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MsIcon('flag', size: 14, color: context.textSecondary),
            const SizedBox(width: 5),
            Text(
              'Report',
              style: RenanceText.caption.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// The report-a-broken-question bottom sheet (FlagQuestionModal).
Future<void> showFlagQuestionSheet(
  BuildContext context, {
  required LessonQuizQ question,
  required String courseCode,
  required String source,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FlagQuestionSheet(
      question: question,
      courseCode: courseCode,
      source: source,
    ),
  );
}

class _FlagQuestionSheet extends StatefulWidget {
  const _FlagQuestionSheet({
    required this.question,
    required this.courseCode,
    required this.source,
  });

  final LessonQuizQ question;
  final String courseCode;
  final String source;

  @override
  State<_FlagQuestionSheet> createState() => _FlagQuestionSheetState();
}

class _FlagQuestionSheetState extends State<_FlagQuestionSheet> {
  static const List<String> _reasons = <String>[
    'Wrong answer key',
    'Question is unclear',
    'Options are broken/duplicated',
    'Image or media missing',
    'Wrong course/topic',
  ];

  String? _reason;
  final TextEditingController _details = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _reason == null) return;
    setState(() => _busy = true);
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnFlagQuestion(
        source: widget.source,
        questionId: widget.question.id,
        courseCode: widget.courseCode,
        reason: _reason!,
        details: _details.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _busy = false);
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.pageBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MsIcon('mark_email_read',
                          size: 44, color: context.primary, fill: true),
                      const SizedBox(height: 12),
                      const Text(
                        'Report sent',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thank you - the desk reviews every report. Your '
                        'account keeps studying while it waits.',
                        textAlign: TextAlign.center,
                        style: RenanceText.bodySecondary
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TactileButton(
                        onPressed: () => Navigator.of(context).pop(),
                        height: 46,
                        child: const Text('Back to the quiz'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Report this question',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.courseCode.isEmpty
                            ? 'the question on screen'
                            : '${widget.courseCode} · question ${widget.question.id}',
                        style: RenanceText.caption
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      for (final String r in _reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ReasonRow(
                            label: r,
                            selected: _reason == r,
                            onTap: () => setState(() => _reason = r),
                          ),
                        ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _details,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Optional: what exactly is wrong?',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TactileButton(
                              onPressed: () => Navigator.of(context).pop(),
                              height: 46,
                              face: context.card,
                              onFace: context.ink,
                              edge: mixTowardBlack(context.outlineVariant, 0.62),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TactileButton(
                              onPressed: _reason == null ? null : _send,
                              height: 46,
                              child: Text(_busy ? 'Sending…' : 'Send report'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? context.primary.withValues(alpha: 0.08)
              : context.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? context.primary : context.outlineVariant,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? context.primary : context.cardLow,
                border: Border.all(
                  color: selected ? context.primary : context.outlineVariant,
                  width: 2,
                ),
              ),
              child: selected
                  ? const MsIcon('check', size: 14, color: Colors.white, fill: true)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- done

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.result,
    required this.correct,
    required this.total,
    required this.mode,
    required this.onContinue,
  });

  final CompleteResult? result;
  final int correct;
  final int total;
  final LessonMode mode;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final int accuracy = total == 0 ? 0 : (correct * 100 ~/ total);
    final String heading = switch (mode) {
      LessonMode.lesson => 'Topic complete!',
      LessonMode.review => 'Unit review done!',
      LessonMode.revision => 'Unit revision done!',
      LessonMode.practice => 'Practice done!',
    };
    final CompleteResult? r = result;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: RenanceColors.bee.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const MsIcon(
                'emoji_events',
                size: 44,
                color: Color(0xFFE6AC00),
                fill: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              heading,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$correct/$total correct · $accuracy% accuracy',
              style: RenanceText.bodySecondary.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _RewardChip(
                  icon: 'bolt',
                  tint: const Color(0xFFF59E0B),
                  label: '+${r?.xpEarned ?? 0} XP',
                ),
                _RewardChip(
                  icon: 'diamond',
                  tint: RenanceColors.macawDark,
                  label: '+${r?.gemsEarned ?? 0} gems',
                ),
                _RewardChip(
                  icon: 'local_fire_department',
                  tint: RenanceColors.fox,
                  label: '${r?.streak ?? 0} day streak',
                ),
                if (r?.boosted ?? false)
                  const _RewardChip(
                    icon: 'bolt',
                    tint: RenanceColors.macawDark,
                    label: 'Boosted 2×',
                  ),
                if (r?.perfect ?? false)
                  const _RewardChip(
                    icon: 'star',
                    tint: Color(0xFFE6AC00),
                    label: 'Perfect score!',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TactileButton(
              onPressed: onContinue,
              height: 50,
              child: Text(mode == LessonMode.lesson ? 'Continue' : 'Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.tint,
    required this.label,
  });

  final String icon;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          icon == 'diamond'
              ? GemIcon(size: 15)
              : MsIcon(icon, size: 16, color: tint, fill: true),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
