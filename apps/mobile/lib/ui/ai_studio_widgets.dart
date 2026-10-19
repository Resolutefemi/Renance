/// Renance AI Studio shared widgets: the thinking-phase ticker, the
/// playable quiz, the note / notebook / lesson-note views, PDF export
/// and the public share link. Used by the studio tabs and the
/// documents shelf (founder directive, 2026-09-30).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../api_client.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// The thinking-phase ticker
// ---------------------------------------------------------------------------

/// Cycles the visible phases ("Thinking", "Analysing", "Researching
/// past questions", "Composing") while the model works - the way the
/// big AI products surface their reasoning.
class AiPhaseTicker extends StatefulWidget {
  const AiPhaseTicker({super.key, required this.phases});
  final List<String> phases;

  @override
  State<AiPhaseTicker> createState() => _AiPhaseTickerState();
}

class _AiPhaseTickerState extends State<AiPhaseTicker> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    Stream<void>.periodic(const Duration(milliseconds: 2600)).listen((_) {
      if (!mounted) return;
      if (_i < widget.phases.length - 1) {
        setState(() => _i++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: context.primary,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${widget.phases[_i]}…',
                style: RenanceText.bodyBase.copyWith(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  for (int j = 0; j < widget.phases.length; j++)
                    Container(
                      width: 14,
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: j <= _i
                            ? context.ink
                            : context.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The playable quiz (canvas-style)
// ---------------------------------------------------------------------------

/// One generated question inside a quiz artifact.
class AiQuizQuestionData {
  AiQuizQuestionData.fromJson(Map<dynamic, dynamic> j)
      : stem = (j['stem'] ?? '') as String,
        answer = (j['answer'] ?? '') as String,
        explanation = (j['explanation'] ?? '') as String,
        options = _optionsOf(j['options']);

  static Map<String, String> _optionsOf(Object? opts) {
    if (opts is! Map) return <String, String>{};
    return <String, String>{
      for (final MapEntry<dynamic, dynamic> e in opts.entries)
        e.key.toString(): e.value.toString(),
    };
  }

  final String stem;
  final String answer;
  final String explanation;
  final Map<String, String> options;
}

/// Plays a quiz artifact: pick, submit, score, explanations.
class AiQuizPlayer extends StatefulWidget {
  const AiQuizPlayer({super.key, required this.artifact});
  final AiStudioArtifact artifact;

  @override
  State<AiQuizPlayer> createState() => _AiQuizPlayerState();
}

class _AiQuizPlayerState extends State<AiQuizPlayer> {
  final List<Map<String, String>> _picks = <Map<String, String>>[];
  int _idx = 0;
  bool _submitted = false;

  List<AiQuizQuestionData> get _questions => <AiQuizQuestionData>[
        for (final dynamic q in (widget.artifact.data['questions']
                as List<dynamic>? ??
            const <dynamic>[]))
          AiQuizQuestionData.fromJson((q as Map).cast<String, dynamic>()),
      ];

  int get _score {
    int s = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (i < _picks.length &&
          _questions[i].answer.isNotEmpty &&
          _picks[i].values.first == _questions[i].answer) {
        s++;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final List<AiQuizQuestionData> qs = _questions;
    if (qs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('This quiz is empty.',
            style: RenanceText.bodySecondary.copyWith(fontSize: 13.5)),
      );
    }
    if (_idx >= qs.length) _idx = qs.length - 1;
    while (_picks.length < qs.length) {
      _picks.add(<String, String>{});
    }
    final AiQuizQuestionData q = qs[_idx];
    final List<String> letters = q.options.keys.toList()..sort();
    final bool last = _idx == qs.length - 1;
    final String? picked =
        _picks[_idx].isEmpty ? null : _picks[_idx].values.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // progress
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_idx + 1) / qs.length,
                  minHeight: 6,
                  color: context.primary,
                  backgroundColor: context.surfaceContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${_idx + 1}/${qs.length}',
                style: RenanceText.labelMono.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(q.stem,
                  style: RenanceText.bodyBase.copyWith(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              for (final String l in letters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OptionTile(
                    letter: l,
                    text: q.options[l] ?? '',
                    picked: picked == l,
                    correct: _submitted && q.answer == l,
                    wrong: _submitted && picked == l && q.answer != l,
                    enabled: !_submitted,
                    onTap: () => setState(() => _picks[_idx] = <String, String>{l: l}),
                  ),
                ),
              if (_submitted && q.explanation.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Why: ${q.explanation}',
                    style: RenanceText.bodySecondary.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_submitted)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The score card rides the theme colour (founder directive
              // 2026-10-02: the old black card follows the seed).
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: context.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    Text('YOUR SCORE',
                        style: RenanceText.labelMono.copyWith(
                            fontSize: 10,
                            color: context.onPrimary.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text('$_score / ${qs.length}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: context.onPrimary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Review navigation (founder directive, 2026-10-02):
              // Previous AND Next flip through every question after
              // submitting - the student can walk back through what they
              // got wrong, not only forward. The old footer offered a
              // lone "Review next" that vanished on the last question.
              Row(
                children: <Widget>[
                  Expanded(
                    child: TactileButton(
                      onPressed:
                          _idx > 0 ? () => setState(() => _idx--) : null,
                      outline: context.outlineVariant,
                      edge: context.outlineVariant,
                      edgeWidth: 3,
                      height: 46,
                      fontSize: 14,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TactileButton(
                      onPressed: _idx < qs.length - 1
                          ? () => setState(() => _idx++)
                          : null,
                      height: 46,
                      fontSize: 14,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TactileButton(
                onPressed: () => setState(() {
                  _submitted = false;
                  _idx = 0;
                  for (final Map<String, String> p in _picks) {
                    p.clear();
                  }
                }),
                outline: context.outlineVariant,
                edge: context.outlineVariant,
                edgeWidth: 3,
                height: 46,
                fontSize: 14,
                child: const Text('Play again'),
              ),
            ],
          )
        else
          Row(
            children: <Widget>[
              if (_idx > 0) ...<Widget>[
                TactileButton(
                  onPressed: () => setState(() => _idx--),
                  outline: context.outlineVariant,
                  edge: context.outlineVariant,
                  edgeWidth: 3,
                  height: 46,
                  fontSize: 14,
                  expand: false,
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TactileButton(
                  onPressed: picked == null
                      ? null
                      : () => setState(() {
                            if (last) {
                              _submitted = true;
                            } else {
                              _idx++;
                            }
                          }),
                  height: 46,
                  fontSize: 14,
                  child: Text(last ? 'Submit and score me' : 'Next question'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.picked,
    required this.correct,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });
  final String letter;
  final String text;
  final bool picked;
  final bool correct;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = context.outlineVariant;
    Color bg = context.card;
    Color fg = context.ink;
    if (picked && !correct && !wrong) {
      border = context.ink;
      bg = context.surfaceContainer;
    }
    // Tier-aware status pastels (dark-mode polish 2026-10-06): the fixed
    // light-tier greens/reds read as glaring bright boxes on the dark
    // page - dark gets deep tinted wells with lifted foregrounds.
    if (correct) {
      border = context.isDarkTier
          ? const Color(0xFF2E7D4F)
          : const Color(0xFF16A34A);
      bg = context.isDarkTier
          ? const Color(0xFF12291D)
          : const Color(0xFFECFDF3);
      fg = context.isDarkTier
          ? const Color(0xFF8CE0B0)
          : const Color(0xFF0D5C37);
    }
    if (wrong) {
      border = context.isDarkTier
          ? const Color(0xFF8F4444)
          : const Color(0xFFFF4B4B);
      bg = context.isDarkTier
          ? const Color(0xFF331719)
          : const Color(0xFFFEF2F2);
      fg = context.isDarkTier
          ? const Color(0xFFF2A6A6)
          : const Color(0xFF8F1D1D);
    }
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked || correct ? context.ink : context.surfaceContainer,
              ),
              child: Text(
                letter,
                style: RenanceText.labelMono.copyWith(
                  fontSize: 11,
                  color: picked || correct ? context.onPrimary : context.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: RenanceText.bodyBase.copyWith(fontSize: 13.5, color: fg)),
            ),
            if (correct)
              MsIcon('check_circle',
                  size: 18,
                  color: context.isDarkTier
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF16A34A)),
            if (wrong)
              MsIcon('cancel',
                  size: 18,
                  color: context.isDarkTier
                      ? const Color(0xFFF87171)
                      : const Color(0xFFFF4B4B)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document views
// ---------------------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: RenanceText.labelMono.copyWith(
              fontSize: 10, color: context.textSecondary),
        ),
      );
}

Widget _bullets(BuildContext context, List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: context.ink),
                ),
                Expanded(
                  child: Text(it,
                      style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
                ),
              ],
            ),
          ),
      ],
    );

List<Map<dynamic, dynamic>> _mapList(dynamic v) => v is List
    ? <Map<dynamic, dynamic>>[
        for (final dynamic e in v)
          if (e is Map) e,
      ]
    : <Map<dynamic, dynamic>>[];

List<String> _strList(dynamic v) => v is List
    ? <String>[for (final dynamic e in v) e.toString()]
    : <String>[];

String _str(dynamic v, String fallback) =>
    v == null ? fallback : v.toString();

/// A generated study note, rendered with the house template.
class AiNoteView extends StatelessWidget {
  const AiNoteView({super.key, required this.data});
  final Map<dynamic, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String summary = _str(data['summary'], '');
    final List<Map<dynamic, dynamic>> sections = _mapList(data['sections']);
    final List<String> keyPoints = _strList(data['keyPoints']);
    final List<String> examTips = _strList(data['examTips']);
    final List<Map<dynamic, dynamic>> practice = _mapList(data['practiceQuestions']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (summary.isNotEmpty) ...<Widget>[
          const _SectionHeading('Overview'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(summary,
                style: RenanceText.bodyBase.copyWith(
                    fontSize: 13.5, color: context.onPrimary)),
          ),
        ],
        for (final Map<dynamic, dynamic> s in sections) ...<Widget>[
          _SectionHeading(_str(s['heading'], '')),
          Text(_str(s['body'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.5)),
        ],
        if (keyPoints.isNotEmpty) ...<Widget>[
          const _SectionHeading('Key points'),
          _bullets(context, keyPoints),
        ],
        if (examTips.isNotEmpty) ...<Widget>[
          const _SectionHeading('Exam tips'),
          _bullets(context, examTips),
        ],
        if (practice.isNotEmpty) ...<Widget>[
          const _SectionHeading('Practice questions'),
          for (final Map<dynamic, dynamic> q in practice)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_str(q['stem'], ''),
                        style: RenanceText.bodyBase
                            .copyWith(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(
                      'Answer: ${_str(q['answer'], '')}'
                      '${q['explanation'] != null && q['explanation'].toString().isNotEmpty ? ' - ${q['explanation']}' : ''}',
                      style: RenanceText.bodySecondary.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A NotebookLM-style notebook, rendered with the fixed arrangement.
class AiNotebookView extends StatelessWidget {
  const AiNotebookView({super.key, required this.data});
  final Map<dynamic, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final List<Map<dynamic, dynamic>> topicNotes = _mapList(data['topicNotes']);
    final List<Map<dynamic, dynamic>> glossary = _mapList(data['glossary']);
    final List<String> examFocus = _strList(data['examFocus']);
    final List<String> studyPlan = _strList(data['studyPlan']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading('Overview'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(_str(data['overview'], ''),
              style: RenanceText.bodyBase
                  .copyWith(fontSize: 13.5, color: context.onPrimary)),
        ),
        for (final Map<dynamic, dynamic> tn in topicNotes) ...<Widget>[
          _SectionHeading(_str(tn['topic'], '')),
          Text(_str(tn['summary'], ''),
              style:
                  RenanceText.bodyBase.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_str(tn['deepDive'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.5)),
          ...<Widget>[
            for (final Map<dynamic, dynamic> k in _mapList(tn['keyTerms']))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${k['term']}: ${k['meaning']}',
                  style: RenanceText.bodySecondary.copyWith(fontSize: 12.5),
                ),
              ),
            for (final String e in _strList(tn['examples']))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Example: $e',
                    style: RenanceText.bodySecondary.copyWith(fontSize: 12.5)),
              ),
          ],
        ],
        if (glossary.isNotEmpty) ...<Widget>[
          const _SectionHeading('Glossary'),
          _bullets(context, <String>[
            for (final Map<dynamic, dynamic> k in glossary) '${k['term']}: ${k['meaning']}',
          ]),
        ],
        if (examFocus.isNotEmpty) ...<Widget>[
          const _SectionHeading('Exam focus'),
          _bullets(context, examFocus),
        ],
        if (studyPlan.isNotEmpty) ...<Widget>[
          const _SectionHeading('Study plan'),
          _bullets(context, studyPlan),
        ],
      ],
    );
  }
}

/// A Nigerian-format lesson note.
class AiLessonNoteView extends StatelessWidget {
  const AiLessonNoteView({super.key, required this.data});
  final Map<dynamic, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final List<String> objectives = _strList(data['objectives']);
    final List<String> materials = _strList(data['materials']);
    final List<Map<dynamic, dynamic>> content = _mapList(data['content']);
    final List<String> evaluation = _strList(data['evaluation']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading('Lesson information'),
        _bullets(context, <String>[
          'Subject: ${_str(data['subject'], '')}',
          'Class: ${_str(data['classLevel'], '')}',
          'Topic: ${_str(data['topic'], '')}',
          if (data['term'] != null) 'Term: ${data['term']}',
          if (data['duration'] != null) 'Duration: ${data['duration']} minutes',
          if (data['ageGroup'] != null && data['ageGroup'].toString().isNotEmpty)
            'Age group: ${data['ageGroup']}',
        ]),
        if (objectives.isNotEmpty) ...<Widget>[
          const _SectionHeading('Objectives'),
          _bullets(context, objectives),
        ],
        if (materials.isNotEmpty) ...<Widget>[
          const _SectionHeading('Instructional materials'),
          _bullets(context, materials),
        ],
        if (data['entryBehaviour'] != null &&
            data['entryBehaviour'].toString().isNotEmpty) ...<Widget>[
          const _SectionHeading('Entry behaviour'),
          Text(_str(data['entryBehaviour'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
        ],
        if (data['previousKnowledge'] != null &&
            data['previousKnowledge'].toString().isNotEmpty) ...<Widget>[
          const _SectionHeading('Previous knowledge'),
          Text(_str(data['previousKnowledge'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
        ],
        for (final Map<dynamic, dynamic> s in content) ...<Widget>[
          _SectionHeading(_str(s['heading'], '')),
          Text(_str(s['body'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.5)),
        ],
        if (evaluation.isNotEmpty) ...<Widget>[
          const _SectionHeading('Evaluation'),
          _bullets(context, evaluation),
        ],
        if (data['summary'] != null && data['summary'].toString().isNotEmpty) ...<Widget>[
          const _SectionHeading('Summary'),
          Text(_str(data['summary'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
        ],
        if (data['assignment'] != null &&
            data['assignment'].toString().isNotEmpty) ...<Widget>[
          const _SectionHeading('Assignment'),
          Text(_str(data['assignment'], ''),
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PDF export + share
// ---------------------------------------------------------------------------

pw.Widget _pdfSection(String heading) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
      child: pw.Text(
        heading.toUpperCase(),
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor(0.55, 0.58, 0.62)),
      ),
    );

pw.Widget _pdfPara(pw.Document doc, String text, {double size = 11.5}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text, style: pw.TextStyle(fontSize: size, lineSpacing: 1.4)),
    );

/// Builds the artifact's PDF and hands it to the system share sheet
/// (which offers Save to Files / Drive / WhatsApp on Android).
Future<void> shareArtifactPdf(AiStudioArtifact art) async {
  final pw.Document doc = pw.Document();
  final List<pw.Widget> body = <pw.Widget>[];

  body.add(_pdfSection(art.kind == 'quiz'
      ? 'Questions'
      : art.kind == 'notebook'
          ? 'Notebook'
          : art.kind == 'lesson_note'
              ? 'Lesson note'
              : 'Study note'));

  if (art.kind == 'quiz') {
    final List<Map<dynamic, dynamic>> qs = _mapList(art.data['questions']);
    for (int i = 0; i < qs.length; i++) {
      final Map<dynamic, dynamic> q = qs[i];
      body.add(_pdfPara(doc, '${i + 1}. ${_str(q['stem'], '')}'));
      final Map<dynamic, dynamic>? opts = q['options'] is Map
          ? q['options'] as Map<dynamic, dynamic>
          : null;
      if (opts != null) {
        final List<String> letters = opts.keys.map((dynamic k) => k.toString()).toList()..sort();
        for (final String l in letters) {
          body.add(_pdfPara(doc, '    $l. ${opts[l]}', size: 11));
        }
      }
      if (q['answer'] != null && q['answer'].toString().isNotEmpty) {
        body.add(_pdfPara(
            doc,
            'Answer: ${q['answer']}'
            '${q['explanation'] != null && q['explanation'].toString().isNotEmpty ? ' - ${q['explanation']}' : ''}',
            size: 11));
      }
    }
  } else if (art.kind == 'note') {
    final Map<dynamic, dynamic> d = art.data;
    if (d['summary'] != null && d['summary'].toString().isNotEmpty) {
      body.add(_pdfPara(doc, _str(d['summary'], '')));
    }
    for (final Map<dynamic, dynamic> s in _mapList(d['sections'])) {
      body.add(_pdfSection(_str(s['heading'], '')));
      body.add(_pdfPara(doc, _str(s['body'], '')));
    }
    for (final String k in _strList(d['keyPoints'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
    for (final String k in _strList(d['examTips'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
    for (final Map<dynamic, dynamic> q in _mapList(d['practiceQuestions'])) {
      body.add(_pdfPara(doc, _str(q['stem'], '')));
      body.add(_pdfPara(doc, 'Answer: ${_str(q['answer'], '')}', size: 11));
    }
  } else if (art.kind == 'notebook') {
    final Map<dynamic, dynamic> d = art.data;
    body.add(_pdfPara(doc, _str(d['overview'], '')));
    for (final Map<dynamic, dynamic> tn in _mapList(d['topicNotes'])) {
      body.add(_pdfSection(_str(tn['topic'], '')));
      body.add(_pdfPara(doc, _str(tn['deepDive'], '')));
      for (final Map<dynamic, dynamic> k in _mapList(tn['keyTerms'])) {
        body.add(_pdfPara(doc, '${k['term']}: ${k['meaning']}', size: 11));
      }
    }
    for (final Map<dynamic, dynamic> k in _mapList(d['glossary'])) {
      body.add(_pdfPara(doc, '${k['term']}: ${k['meaning']}'));
    }
    for (final String k in _strList(d['examFocus'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
    for (final String k in _strList(d['studyPlan'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
  } else {
    final Map<dynamic, dynamic> d = art.data;
    for (final String line in <String>[
      'Subject: ${_str(d['subject'], '')}',
      'Class: ${_str(d['classLevel'], '')}',
      'Topic: ${_str(d['topic'], '')}',
      if (d['term'] != null) 'Term: ${d['term']}',
      if (d['duration'] != null) 'Duration: ${d['duration']} minutes',
    ]) {
      body.add(_pdfPara(doc, line));
    }
    body.add(_pdfSection('Objectives'));
    for (final String k in _strList(d['objectives'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
    for (final Map<dynamic, dynamic> s in _mapList(d['content'])) {
      body.add(_pdfSection(_str(s['heading'], '')));
      body.add(_pdfPara(doc, _str(s['body'], '')));
    }
    for (final String k in _strList(d['evaluation'])) {
      body.add(_pdfPara(doc, '- $k'));
    }
    if (d['summary'] != null) {
      body.add(_pdfSection('Summary'));
      body.add(_pdfPara(doc, _str(d['summary'], '')));
    }
    if (d['assignment'] != null) {
      body.add(_pdfSection('Assignment'));
      body.add(_pdfPara(doc, _str(d['assignment'], '')));
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      header: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            art.title.isEmpty ? 'Renance AI' : art.title,
            style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            <String>[
              'Renance AI',
              if (art.subject.isNotEmpty) art.subject,
              if (art.classLevel.isNotEmpty) art.classLevel,
            ].join('  |  '),
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColor(0.55, 0.58, 0.62)),
          ),
          pw.Container(height: 8),
        ],
      ),
      footer: (pw.Context ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text('Generated with Renance AI - renance.app',
              style: pw.TextStyle(fontSize: 8.5, color: const PdfColor(0.6, 0.63, 0.67))),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8.5, color: const PdfColor(0.6, 0.63, 0.67))),
        ],
      ),
      build: (pw.Context ctx) => body,
    ),
  );

  final Directory tmp = await getTemporaryDirectory();
  final String safe = art.title
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  final File file = File('${tmp.path}/${safe.isEmpty ? 'renance-ai' : safe}.pdf');
  await file.writeAsBytes(await doc.save());
  await Share.shareXFiles(
    <XFile>[XFile(file.path)],
    text: art.title,
    subject: art.title,
  );
}

/// Copies / shares the quiz's public link (its own name is the tag).
Future<void> shareQuizLink(AiStudioArtifact quiz, ApiClient api) async {
  String slug = quiz.shareSlug;
  if (slug.isEmpty) {
    slug = await api.aiShareArtifact(quiz.id);
  }
  final String url = 'https://renance.app/quiz/?q=$slug';
  await Share.share(
    'Play "${quiz.title}" on Renance - $url',
    subject: quiz.title,
  );
}
