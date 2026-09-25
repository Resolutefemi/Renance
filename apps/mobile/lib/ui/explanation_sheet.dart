/// The explanation sheet - Myschool's explanation modal, Renance edition.
///
/// Layout mirrors the school app the founder asked to copy: a rounded
/// bottom sheet with the red-circle close + "Question N" title + Save
/// pill, the stem, the option stack with the green check on the correct
/// option, the "Explanation" section with the "Correct Option C" pill,
/// the Report link, the Previous/Next pair - and, floating in the same
/// position Myschool puts theirs, the AI pill: "Get Renance's AI
/// Explanation", which opens the AI Generated Explanation sheet with
/// the amber can-make-mistakes notice.
///
/// Every colour stays inside the founder's two defaults: white ground,
/// black chrome; green/red only as the honest right/wrong signals.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../scenarios.dart';
import '../models.dart';
import '../qtext.dart';
import 'theme.dart';

class ExplanationSheet extends StatefulWidget {
  const ExplanationSheet({
    super.key,
    required this.title,
    required this.stem,
    required this.options,
    required this.correct,
    required this.explanation,
    required this.questionId,
    required this.saved,
    required this.onToggleSave,
    this.questionNumber,
    this.passage = '',
    this.image = '',
    this.topic = '',
    this.year = 0,
    this.selected = '',
    this.attemptId = '',
    this.onPrevious,
    this.onNext,
    this.onReport,
  });

  /// "Question" / "Saved Question".
  final String title;

  /// Null renders the bare title (saved reader); a number renders
  /// "Question N" like the school app.
  final int? questionNumber;

  final String stem;
  final String passage;
  final String image;
  final String topic;
  final int year;
  final Map<String, String> options;

  /// The correct option letter ('' when unknown - pre-grade saves).
  final String correct;

  /// What the student picked ('' when reviewing an untouched paper).
  final String selected;
  final String explanation;
  final String questionId;

  /// Graded-attempt context: the AI pill needs it (the server anchors
  /// explanations to graded attempts). Empty = AI pill hidden.
  final String attemptId;

  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReport;

  @override
  State<ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<ExplanationSheet> {
  bool _saving = false;

  Future<void> _toggleSave() async {
    if (_saving) return;
    _saving = true;
    HapticFeedback.lightImpact();
    try {
      widget.onToggleSave();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool graded = widget.correct.isNotEmpty;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.6,
      builder: (BuildContext context, ScrollController scroll) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              // ---- header: X + title + Save ---------------------------
              Container(
                decoration: BoxDecoration(
                  color: context.cardLowest,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: context.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top * 0.4 + 12,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.error),
                        ),
                        child:
                            Icon(Icons.close, size: 19, color: context.error),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.questionNumber == null
                            ? widget.title
                            : '${widget.title} ${widget.questionNumber}',
                        style: RenanceText.sectionTitle.copyWith(fontSize: 19),
                      ),
                    ),
                    // The Save pill - Myschool's bookmark position.
                    InkWell(
                      onTap: _toggleSave,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: context.error),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              widget.saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 16,
                              color: context.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.saved ? 'Saved' : 'Save',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ---- scrollable body ------------------------------------
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: <Widget>[
                    if (widget.topic.isNotEmpty ||
                        widget.year > 0 ||
                        widget.passage.isEmpty)
                      const SizedBox.shrink(),
                    if (widget.passage.isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardLow.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: QuestionText(
                            widget.passage,
                            style: RenanceText.bodyBase.copyWith(
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    QuestionText(
                      widget.stem,
                      style: RenanceText.bodyMedium.copyWith(
                        fontSize: 16.5,
                        height: 1.5,
                      ),
                    ),
                    if (widget.image.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          resolveQImageUrl(widget.image),
                          fit: BoxFit.contain,
                          height: 180,
                          errorBuilder: (_, Object __, StackTrace? ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    // Options - green check on the correct one, red X on
                    // a wrong pick, exactly the school app's grammar.
                    ...widget.options.entries.map<Widget>(
                      (MapEntry<String, String> opt) {
                        final bool isCorrect =
                            graded && opt.key == widget.correct;
                        final bool isWrongPick =
                            graded &&
                                widget.selected.isNotEmpty &&
                                opt.key == widget.selected &&
                                opt.key != widget.correct;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ReviewOption(
                            letter: opt.key,
                            text: opt.value,
                            isCorrect: isCorrect,
                            isWrongPick: isWrongPick,
                          ),
                        );
                      },
                    ),
                    // ---- Explanation section ----------------------------
                    if (graded) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.cardLow.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                ShaderMask(
                                  shaderCallback: (Rect bounds) =>
                                      const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF2563EB),
                                      Color(0xFF7C3AED),
                                    ],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcIn,
                                  child: const Text(
                                    'Explanation',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (widget.correct.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: context.cardLowest,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: const <BoxShadow>[
                                        BoxShadow(
                                          color: Color(0x14141C2D),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(Icons.auto_awesome,
                                            size: 13,
                                            color: context.textSecondary),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Correct Option ${widget.correct}',
                                          style:
                                              RenanceText.caption.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: context.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (widget.explanation.trim().isEmpty)
                              Text(
                                'No written explanation ships with this '
                                'question yet - try the AI explanation below.',
                                style: RenanceText.bodySecondary.copyWith(
                                  fontSize: 13.5,
                                  color: context.textSecondary,
                                  height: 1.55,
                                ),
                              )
                            else
                              QuestionText(
                                widget.explanation,
                                style: RenanceText.bodySecondary.copyWith(
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardLow.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.lock_outline,
                                size: 17, color: context.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Submit the paper to unlock the correct '
                                'option and its explanation.',
                                style: RenanceText.caption.copyWith(
                                  color: context.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // ---- Everyday scenario ----------------------------------
              Builder(builder: (BuildContext context) {
                final EverydayScenario? scenario = findEverydayScenario(
                  topic: widget.topic,
                  stem: widget.stem,
                );
                if (scenario == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.cardLow.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.lightbulb_outline,
                              size: 16, color: context.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Everyday scenario: ${scenario.scenarioTitle}',
                              style: RenanceText.caption.copyWith(
                                color: context.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scenario.scenario,
                        style: RenanceText.caption.copyWith(
                          color: context.textSecondary,
                          height: 1.5,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Takeaway: ${scenario.takeaway}',
                        style: RenanceText.caption.copyWith(
                          color: context.ink,
                          height: 1.5,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // ---- AI pill + footer ----------------------------------
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // The AI pill - the same floating position Myschool
                    // puts "Get Myschool's AI Explanation".
                    if (widget.attemptId.isNotEmpty && graded)
                      Align(
                        alignment: Alignment.center,
                        child: Material(
                          color: context.cardLowest,
                          elevation: 4,
                          shadowColor: const Color(0x22141C2D),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => AiExplanationSheet(
                                  attemptId: widget.attemptId,
                                  questionId: widget.questionId,
                                  stem: widget.stem,
                                  options: widget.options,
                                  correct: widget.correct,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: context.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.auto_awesome, size: 16),
                                  const SizedBox(width: 7),
                                  Text(
                                    "Get Renance's AI Explanation",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.attemptId.isNotEmpty && graded)
                      const SizedBox(height: 12),
                    // Report + Previous/Next - the school app's footer.
                    Row(
                      children: <Widget>[
                        if (widget.onReport != null)
                          InkWell(
                            onTap: widget.onReport,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.flag_outlined,
                                      size: 17, color: context.error),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Report',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (widget.onPrevious != null)
                          FilledButton(
                            onPressed: widget.onPrevious,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(108, 46),
                              backgroundColor: context.inverseChip,
                              foregroundColor: context.onInverseChip,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Previous',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(width: 10),
                        if (widget.onNext != null)
                          FilledButton(
                            onPressed: widget.onNext,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(96, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Next',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One option row of the graded reader: correct = emerald ring + check,
/// wrong pick = red ring + close, everything else = quiet outline.
class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isWrongPick,
  });

  final String letter;
  final String text;
  final bool isCorrect;
  final bool isWrongPick;

  @override
  Widget build(BuildContext context) {
    final Color ring = isCorrect
        ? RenanceColors.emerald
        : isWrongPick
            ? context.error
            : context.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isCorrect
            ? RenanceColors.emerald.withValues(alpha: 0.06)
            : isWrongPick
                ? context.error.withValues(alpha: 0.05)
                : context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ring, width: isCorrect || isWrongPick ? 1.4 : 1),
      ),
      child: Row(
        children: <Widget>[
          Text(
            letter,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isCorrect
                  ? RenanceColors.emerald
                  : isWrongPick
                      ? context.error
                      : context.error.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: context.outlineVariant),
          const SizedBox(width: 12),
          Expanded(
            child: QuestionText(
              text,
              style: RenanceText.bodyBase.copyWith(
                fontSize: 14.5,
                fontWeight:
                    isCorrect || isWrongPick ? FontWeight.w600 : FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle, size: 19, color: RenanceColors.emerald),
          if (isWrongPick)
            Icon(Icons.cancel, size: 19, color: context.error),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- AI sheet

/// The AI Generated Explanation sheet - Myschool's cut: red close +
/// sparkle title, the amber "AI can make mistakes" notice, the solution
/// walkthrough, the answer line. Content comes from the graded-attempt
/// tutor endpoint; while it streams the sheet shows the thinking state.
class AiExplanationSheet extends StatefulWidget {
  const AiExplanationSheet({
    super.key,
    required this.attemptId,
    required this.questionId,
    required this.stem,
    required this.options,
    required this.correct,
  });

  final String attemptId;
  final String questionId;
  final String stem;
  final Map<String, String> options;
  final String correct;

  @override
  State<AiExplanationSheet> createState() => _AiExplanationSheetState();
}

class _AiExplanationSheetState extends State<AiExplanationSheet> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final TutorReply reply = await api.tutorChat(
        attemptId: widget.attemptId,
        questionId: widget.questionId,
        messages: <TutorTurn>[
          TutorTurn(
            role: 'user',
            content: 'Explain this past question step by step: '
                '"${widget.stem}" Options: '
                '${widget.options.entries.map((MapEntry<String, String> e) => "${e.key}) ${e.value}").join("; ")}. '
                'End with the correct option (${widget.correct}) and why the '
                'others are wrong.',
          ),
        ],
      );
      if (!mounted) return;
      setState(() => _text = reply.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController scroll) {
        return Container(
          decoration: BoxDecoration(
            color: context.cardLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top * 0.4 + 12,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.error),
                        ),
                        child: Icon(Icons.close,
                            size: 19, color: context.error),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI Generated Explanation',
                        style: RenanceText.sectionTitle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    // The amber can-make-mistakes notice, Myschool's copy.
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        'AI can make mistakes. Kindly review and confirm '
                        'using other explanations provided for this '
                        'question. Feel free to use the "Report" button to '
                        'let us know of any errors.',
                        style: RenanceText.bodySecondary.copyWith(
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Solution', style: RenanceText.sectionTitle),
                    const SizedBox(height: 10),
                    if (_text == null && _error == null) ...<Widget>[
                      const SizedBox(height: 26),
                      const Center(
                        child: Column(
                          children: <Widget>[
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(height: 14),
                          ],
                        ),
                      ),
                      Center(
                        child: Text(
                          'Renance AI is working through the question…',
                          style: RenanceText.caption.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ] else if (_error != null)
                      Column(
                        children: <Widget>[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: RenanceText.bodySecondary.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _error = null;
                                _text = null;
                              });
                              _ask();
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    else ...<Widget>[
                      SelectableText(
                        _text!,
                        style: RenanceText.bodySecondary.copyWith(
                          fontSize: 14.5,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.correct.isNotEmpty)
                        Text(
                          'Answer: ${widget.correct}',
                          style: RenanceText.bodyMedium.copyWith(fontSize: 15),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
