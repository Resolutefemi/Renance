import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import 'theme.dart';

/// Tutor entry (ROADMAP #9): pick a graded paper, then a question, then
/// chat. The Socratic tutor only coaches on GRADED attempts, the same
/// doctrine the API enforces.
class TutorEntryScreen extends StatefulWidget {
  const TutorEntryScreen({super.key});

  @override
  State<TutorEntryScreen> createState() => _TutorEntryScreenState();
}

class _TutorEntryScreenState extends State<TutorEntryScreen> {
  List<AttemptRow> _papers = <AttemptRow>[];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final ApiClient api = context.read<ApiClient>();
    Future<void>.microtask(() async {
      try {
        final List<AttemptRow> rows = await api.attempts();
        if (!mounted) return;
        setState(() {
          _papers = rows.where((AttemptRow a) => a.status == 'graded').toList();
          _loading = false;
        });
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text('Ask the Tutor'),
        backgroundColor: context.pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13),
                ),
              ),
            )
          : _papers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.smart_toy,
                      size: 40,
                      color: context.ink,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'The tutor coaches on papers you have already taken.\nFinish your first mock and come back.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, 
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Which paper should we work through?',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13),
                  ),
                ),
                ..._papers.map(
                  (AttemptRow a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PaperRow(paper: a),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({required this.paper});

  final AttemptRow paper;

  @override
  Widget build(BuildContext context) {
    final int? pct = paper.pct;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TutorQuestionsScreen(paper: paper),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.outlineVariant, width: 0.6),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.smart_toy,
                size: 20,
                color: context.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  paper.code,
                  style: RenanceText.bodyBase.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                pct == null ? 'graded' : '$pct%',
                style: RenanceText.labelMono.copyWith(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One graded paper's questions, filtered to answer-keyed ones.
class TutorQuestionsScreen extends StatefulWidget {
  const TutorQuestionsScreen({super.key, required this.paper});

  final AttemptRow paper;

  @override
  State<TutorQuestionsScreen> createState() => _TutorQuestionsScreenState();
}

class _TutorQuestionsScreenState extends State<TutorQuestionsScreen> {
  AttemptReview? _review;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final ApiClient api = context.read<ApiClient>();
    Future<void>.microtask(() async {
      try {
        final AttemptReview r = await api.attemptReview(widget.paper.attemptId);
        if (!mounted) return;
        setState(() {
          _review = r;
          _loading = false;
        });
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(
          widget.paper.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: context.pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Which question is bothering you?',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13),
                  ),
                ),
                ..._review!.questions.asMap().entries.map(
                  (MapEntry<int, ReviewQuestion> e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QuestionRow(
                      index: e.key + 1,
                      question: e.value,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TutorChatScreen(
                            attemptId: widget.paper.attemptId,
                            paperCode: widget.paper.code,
                            questions: _review!.questions,
                            initialQuestionId: e.value.questionId,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.index,
    required this.question,
    required this.onTap,
  });

  final int index;
  final ReviewQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool wrong = question.selected.isNotEmpty && !question.correctly;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.outlineVariant, width: 0.6),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: question.selected.isEmpty
                      ? context.cardLow
                      : wrong
                      ? context.errorContainer
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 13,
                    color: wrong ? context.error : context.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.stem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.bodyBase.copyWith(
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Socratic chat itself. Anchored to one attempt + question; the
/// server decides between AI mode and deterministic technique hints and
/// badges the reply so the student always knows which voice they hear.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({
    super.key,
    required this.attemptId,
    required this.paperCode,
    required this.questions,
    required this.initialQuestionId,
  });

  final String attemptId;
  final String paperCode;
  final List<ReviewQuestion> questions;
  final String initialQuestionId;

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  late String _qid;
  late final TextEditingController _input;
  final ScrollController _scroll = ScrollController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qid = widget.initialQuestionId;
    _input = TextEditingController();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ReviewQuestion get _question =>
      widget.questions.firstWhere((ReviewQuestion q) => q.questionId == _qid);

  Future<void> _send(String text) async {
    final String content = text.trim();
    if (content.isEmpty || _busy) return;
    final ApiClient api = context.read<ApiClient>();
    final ReviewQuestion q = _question;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The conversation is reconstructed server-side per send: each call
      // carries the full turn list, so refresh-safe by construction.
      final List<TutorTurn> history = _history[q.questionId] ?? <TutorTurn>[];
      final List<TutorTurn> outgoing = List<TutorTurn>.of(history)
        ..add(TutorTurn(role: 'user', content: content));
      _history[q.questionId] = outgoing;
      final TutorReply reply = await api.tutorChat(
        attemptId: widget.attemptId,
        questionId: q.questionId,
        messages: outgoing,
      );
      _history[q.questionId]!.add(
        TutorTurn(role: 'assistant', content: reply.text),
      );
      _modes[q.questionId] = reply.mode;
      _input.clear();
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        Future<void>.microtask(() {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  final Map<String, List<TutorTurn>> _history = <String, List<TutorTurn>>{};
  final Map<String, String> _modes = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final ReviewQuestion q = _question;
    final List<TutorTurn> turns = _history[_qid] ?? <TutorTurn>[];
    final String mode = _modes[_qid] ?? 'hint';
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Ask the Tutor'),
            Text(
              widget.paperCode,
              style: RenanceText.caption.copyWith(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: context.pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: <Widget>[
          // question picker
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: <Widget>[
                for (var i = 0; i < widget.questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Q${i + 1}'),
                      selected: widget.questions[i].questionId == _qid,
                      onSelected: (_) =>
                          setState(() => _qid = widget.questions[i].questionId),
                      selectedColor: context.ink,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: widget.questions[i].questionId == _qid
                            ? Colors.white
                            : context.textSecondary,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          // question context card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.cardLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (q.topic.isNotEmpty)
                  Text(
                    'Topic: ${q.topic}',
                    style: RenanceText.labelMono.copyWith(fontSize: 11),
                  ),
                const SizedBox(height: 4),
                Text(
                  q.stem,
                  style: RenanceText.bodyBase.copyWith(
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          // conversation
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (turns.isEmpty) ...<Widget>[
                  _Bubble(
                    role: 'assistant',
                    text:
                        'I have your question and your answer in front of me. '
                        'Ask me anything, I coach with questions first and answers last.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String s in const <String>[
                        'Why is my answer wrong?',
                        'Give me a hint without the answer',
                        'Explain the topic simply',
                      ])
                        ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: _busy ? null : () => _send(s),
                        ),
                    ],
                  ),
                ],
                for (final TutorTurn t in turns) ...<Widget>[
                  _Bubble(role: t.role, text: t.content),
                  const SizedBox(height: 8),
                ],
                if (_busy)
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'The tutor is thinking…',
                        style: RenanceText.caption.copyWith(color: context.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: RenanceText.caption.copyWith( 
                        fontSize: 12,
                         color: context.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // mode badge + composer
          SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: mode == 'ai'
                              ? context.ink
                              : context.cardLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          mode == 'ai' ? 'AI Coach' : 'Technique Hints',
                          style: RenanceText.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mode == 'ai'
                                ? Colors.white
                                : context.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Socratic mode, guided first',
                        style: RenanceText.caption.copyWith(color: context.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.outlineVariant,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Ask why this answer is wrong…',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          onSubmitted: (String v) => _send(v),
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : () => _send(_input.text),
                        icon: Icon(
                          Icons.send,
                          size: 20,
                          color: context.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.role, required this.text});

  final String role;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool user = role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(left: user ? 44 : 0, right: user ? 0 : 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: user ? context.ink : const Color(0x14111C2D),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: RenanceText.bodyBase.copyWith(
            fontSize: 13.5,
            height: 1.45,
            color: user ? Colors.white : context.ink,
          ),
        ),
      ),
    );
  }
}
