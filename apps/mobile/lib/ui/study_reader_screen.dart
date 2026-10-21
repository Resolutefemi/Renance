/// The Past-Questions reader - the school app's study reading surface,
/// Renance edition, 1:1 with the website's /study-past-questions/reader.
///
/// Opens over one bank (the study setup resolves subject + bank code +
/// year), filters applied client-side from the same bundle: year,
/// question type, topic and a live search. Every card carries its
/// options and a "View Explanation" button that opens the shared
/// ExplanationSheet (Save · correct-option check · Report · Prev/Next
/// · AI Explanation) - the same grammar the website ships.
///
/// This screen is a READER, not an exam: untimed, nothing submits, no
/// grading ceremony - reading past questions is the point here. The
/// bottom "N Questions" strip jumps between cards the way the school
/// app's navigator does. The bank loads LOCAL first (PackStore), so
/// every downloaded bank reads fully offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../qtext.dart';
import '../storage.dart';
import 'explanation_sheet.dart';
import 'msymbols.dart';
import 'saved_questions.dart';
import 'tactile.dart';
import 'theme.dart';

/// One page size step, exactly the web's "Show 25 more".
const int _pageSize = 25;

class StudyReaderScreen extends StatefulWidget {
  const StudyReaderScreen({
    super.key,
    required this.bank,
    required this.sha,
    required this.title,
    this.initialYear,
    this.initialTopic = '',
    this.initialQt = 'all',
  });

  /// The backing bank code ("jamb-biology-bank", a uni course pack, a
  /// post-utme bank) - the reader reads that pack directly.
  final String bank;

  /// The manifest's bundleSha256 (PackStore sha check).
  final String sha;

  /// "Biology · Study" - composed by the setup (or the caller).
  final String title;

  /// Year pinned from the setup's Year picker (null = all years).
  final int? initialYear;

  /// Topic pinned from the setup's Topic picker ('' = all topics).
  final String initialTopic;

  /// 'all' | 'objective' | 'theory'.
  final String initialQt;

  @override
  State<StudyReaderScreen> createState() => _StudyReaderScreenState();
}

class _StudyReaderScreenState extends State<StudyReaderScreen> {
  Bundle? _bundle;
  bool _loading = true;
  bool _failed = false;
  SavedStore? _saved;

  late int? _yearFilter = widget.initialYear;
  late String _qtFilter = widget.initialQt;
  late String _topicFilter = widget.initialTopic;
  String _search = '';
  int _limit = _pageSize;
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SessionStore session = context.read<SessionStore>();
      setState(() => _saved = SavedStore(session.prefs));
      _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final Bundle? bundle =
        await context.read<SyncController>().loadBank(widget.bank, widget.sha);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _loading = false;
      _failed = bundle == null;
      _limit = _pageSize;
    });
  }

  bool isSaved(String questionId) => _saved?.isSaved(questionId) ?? false;

  Future<void> _toggleSave(BundleQuestion q) async {
    final SavedStore? store = _saved;
    if (store == null) return;
    final bool wasSaved = store.isSaved(q.id);
    await store.toggle(
      SavedQuestion(
        id: q.id,
        code: _bundle?.code ?? widget.bank,
        title: widget.title,
        stem: q.stem,
        options: q.options,
        savedAt: DateTime.now(),
        topic: q.topic,
        year: q.year,
        image: q.image,
        passage: q.passage,
        correct: q.answer,
        explanation: q.explanation,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(wasSaved ? 'Removed from Saved' : 'Question saved'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    setState(() {});
  }

  /// Years actually present in the bank - the honest chip set (the
  /// setup's manifest years stay the shortcut; here the data speaks).
  List<int> get _bankYears {
    final Set<int> years = <int>{};
    for (final BundleQuestion q
        in _bundle?.questions ?? const <BundleQuestion>[]) {
      if (q.year > 0) years.add(q.year);
    }
    final List<int> sorted = years.toList()
      ..sort((int a, int b) => b.compareTo(a));
    return sorted;
  }

  List<String> get _topics {
    final Set<String> set = <String>{};
    for (final BundleQuestion q
        in _bundle?.questions ?? const <BundleQuestion>[]) {
      if (q.topic.isNotEmpty) set.add(q.topic);
    }
    final List<String> list = set.toList()..sort();
    return list;
  }

  List<BundleQuestion> get _filtered {
    final List<BundleQuestion> all =
        _bundle?.questions ?? const <BundleQuestion>[];
    final String needle = _search.trim().toLowerCase();
    return all.where((BundleQuestion q) {
      if (_yearFilter != null && q.year != _yearFilter) return false;
      if (_qtFilter == 'theory' && q.type != 'theory') return false;
      if (_qtFilter == 'objective' && q.type == 'theory') return false;
      if (_topicFilter.isNotEmpty && q.topic != _topicFilter) return false;
      if (needle.isNotEmpty && !q.stem.toLowerCase().contains(needle)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Bottom-strip jump: reveal the card, then scroll it into view.
  void _jumpTo(int index, int filteredCount) {
    setState(() {
      if (_limit < index + 1) _limit = index + 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = _cardKeys[index]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      }
    });
  }

  /// Opens the explanation as a REAL modal bottom sheet (the review
  /// screen's pattern): the DraggableScrollableSheet anchors to the
  /// bottom with a scrim behind it, its inner ListView scrolls the
  /// question + options + explanation, and the footer buttons stay
  /// pinned - the old inline Stack overlay used to hang from the top
  /// and drags resized the panel instead of scrolling it.
  Future<void> _openExplanation(int index, List<BundleQuestion> filtered) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _ExplanationPager(
        state: this,
        questions: filtered,
        initialIndex: index,
      ),
    );
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_failed || _bundle == null) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MsIcon('cloud_off',
                    size: 40, color: context.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Could not load this question bank. Update your questions and try again.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary
                      .copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: _load,
                  outline: context.outlineVariant,
                  edge: context.outlineVariant,
                  edgeWidth: 3,
                  height: 46,
                  fontSize: 14,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<BundleQuestion> filtered = _filtered;
    final int total = _bundle!.questionCount;
    final int shown = filtered.length < _limit ? filtered.length : _limit;
    final List<BundleQuestion> visible =
        filtered.take(_limit).toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildHeader(total, filtered.length),
            Expanded(
              child: Stack(
                children: <Widget>[
                  visible.isEmpty
                      ? Center(
                          child: Text(
                            'No questions match these filters yet.',
                            style: RenanceText.bodySecondary
                                .copyWith(color: context.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
                          itemCount: shown + (filtered.length > shown ? 1 : 0),
                          itemBuilder: (BuildContext context, int i) {
                            if (i >= shown) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: TactileButton(
                                  onPressed: () => setState(
                                      () => _limit = _limit + _pageSize),
                                  outline: context.outlineVariant,
                                  edge: context.outlineVariant,
                                  edgeWidth: 3,
                                  height: 46,
                                  fontSize: 14,
                                  child: Text(
                                    'Show $_pageSize more · '
                                    '${filtered.length - shown} left',
                                  ),
                                ),
                              );
                            }
                            return Container(
                              key: _cardKeys[i] ??= GlobalKey(),
                              child: _ReaderCard(
                                q: visible[i],
                                n: i + 1,
                                saved: isSaved(visible[i].id),
                                onExplain: () => _openExplanation(i, filtered),
                                onToggleSave: () => _toggleSave(visible[i]),
                              ),
                            );
                          },
                        ),
                  // ---- bottom N-Questions strip ----------------------
                  if (filtered.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomStrip(filtered),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sticky header band: back + title + live count, then the chip
  /// row (type chips + year + topic) and the search field - the web
  /// reader's header, mobile cut.
  Widget _buildHeader(int total, int filteredCount) {
    final List<int> years = _bankYears;
    final List<String> topics = _topics;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          bottom: BorderSide(color: context.outlineVariant, width: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: <Widget>[
                TactileBackKey(
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.sectionTitle
                            .copyWith(fontSize: 17, color: context.ink),
                      ),
                      Text(
                        '${_fmt(filteredCount)} of ${_fmt(total)} questions',
                        style: RenanceText.caption
                            .copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---- chip row -------------------------------------------
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: <Widget>[
                _chip(
                  'All (${_fmt(total)})',
                  active: _qtFilter == 'all',
                  onTap: () => setState(() {
                    _qtFilter = 'all';
                    _limit = _pageSize;
                  }),
                ),
                const SizedBox(width: 8),
                _chip(
                  'Objectives',
                  active: _qtFilter == 'objective',
                  onTap: () => setState(() {
                    _qtFilter = 'objective';
                    _limit = _pageSize;
                  }),
                ),
                const SizedBox(width: 8),
                _chip(
                  'Theory',
                  active: _qtFilter == 'theory',
                  onTap: () => setState(() {
                    _qtFilter = 'theory';
                    _limit = _pageSize;
                  }),
                ),
                if (years.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  _selectChip<int?>(
                    value: _yearFilter,
                    hint: 'All years',
                    items: <MapEntry<int?, String>>[
                      for (final int y in years)
                        MapEntry<int?, String>(y, '$y'),
                    ],
                    onChanged: (int? v) => setState(() {
                      _yearFilter = v;
                      _limit = _pageSize;
                    }),
                  ),
                ],
                if (topics.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  _selectChip<String?>(
                    value: _topicFilter.isEmpty ? null : _topicFilter,
                    hint: 'All topics',
                    items: <MapEntry<String?, String>>[
                      for (final String t in topics)
                        MapEntry<String?, String>(t, t),
                    ],
                    onChanged: (String? v) => setState(() {
                      _topicFilter = v ?? '';
                      _limit = _pageSize;
                    }),
                  ),
                ],
              ],
            ),
          ),
          // ---- search ----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (String v) => setState(() {
                _search = v;
                _limit = _pageSize;
              }),
              style: RenanceText.bodyBase.copyWith(color: context.ink),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon:
                    MsIcon('search', size: 20, color: context.textSecondary),
                hintText: 'Search the questions…',
                hintStyle:
                    RenanceText.bodyBase.copyWith(color: context.textSecondary),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: context.cardLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.outlineVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The fixed bottom strip: "N Questions" pill + numbered jump chips
  /// (the web caps the chips at 120 and prints "+N" for the rest).
  Widget _buildBottomStrip(List<BundleQuestion> filtered) {
    final int chips = filtered.length > 120 ? 120 : filtered.length;
    final bool overflow = filtered.length > 120;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          top: BorderSide(color: context.outlineVariant, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.inverseChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_fmt(filtered.length)} Questions',
                  style: RenanceText.bodyMedium.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.onInverseChip,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips + (overflow ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      if (overflow && i == chips) {
                        return Center(
                          child: Text(
                            '+${filtered.length - 120}',
                            style: RenanceText.caption
                                .copyWith(color: context.textSecondary),
                          ),
                        );
                      }
                      final bool opened = i < _limit;
                      return InkWell(
                        onTap: () => _jumpTo(i, filtered.length),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: opened
                                  ? context.primary
                                  : context.outlineVariant,
                            ),
                            color: context.cardLowest,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: RenanceText.caption
                                .copyWith(color: context.ink),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    String label, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? context.selectionBlue : context.cardLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? context.ink : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _selectChip<T>({
    required T? value,
    required String hint,
    required List<MapEntry<T?, String>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: value != null ? context.selectionBlue : context.cardLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: context.cardLowest,
          icon: MsIcon('expand_more', size: 18, color: context.textSecondary),
          hint: Text(hint,
              style: RenanceText.labelMono
                  .copyWith(fontSize: 12, color: context.textSecondary)),
          items: <DropdownMenuItem<T>>[
            DropdownMenuItem<T>(
              value: null,
              child: Text(hint,
                  style: RenanceText.labelMono.copyWith(fontSize: 12)),
            ),
            for (final MapEntry<T?, String> it in items)
              DropdownMenuItem<T>(
                value: it.key,
                child: Text(it.value,
                    style: RenanceText.labelMono.copyWith(fontSize: 12)),
              ),
          ],
          onChanged: (T? v) => onChanged(v),
        ),
      ),
    );
  }
}

String _fmt(int n) {
  final String s = '$n';
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final int remain = s.length - i;
    out.write(s[i]);
    if (remain > 1 && remain % 3 == 1) out.write(',');
  }
  return out.toString();
}

// --------------------------------------------------------------- pager

/// Keeps one sheet open across Previous/Next, rebuilding the
/// ExplanationSheet per question - the review pager's behaviour.
class _ExplanationPager extends StatefulWidget {
  const _ExplanationPager({
    required this.state,
    required this.questions,
    required this.initialIndex,
  });

  final _StudyReaderScreenState state;
  final List<BundleQuestion> questions;
  final int initialIndex;

  @override
  State<_ExplanationPager> createState() => _ExplanationPagerState();
}

class _ExplanationPagerState extends State<_ExplanationPager> {
  late int _idx = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final BundleQuestion q = widget.questions[_idx];
    return ExplanationSheet(
      key: ValueKey<int>(_idx),
      title: 'Question',
      questionNumber: _idx + 1,
      stem: q.stem,
      passage: q.passage,
      image: q.image,
      topic: q.topic,
      year: q.year,
      options: q.options,
      correct: q.answer,
      explanation: q.explanation,
      questionId: q.id,
      saved: widget.state.isSaved(q.id),
      onToggleSave: () => widget.state._toggleSave(q),
      onPrevious: _idx > 0 ? () => setState(() => _idx--) : null,
      onNext: _idx < widget.questions.length - 1
          ? () => setState(() => _idx++)
          : null,
      onReport: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report noted on question ${q.id}. Thanks for the '
                'flag, it goes straight to the question team.'),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ card

/// One reader card: N pill, topic/year chip, save + copy actions,
/// passage drawer, stem, options and the black "View Explanation"
/// button - the web ReaderCard's mobile twin.
class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.q,
    required this.n,
    required this.saved,
    required this.onExplain,
    required this.onToggleSave,
  });

  final BundleQuestion q;
  final int n;
  final bool saved;
  final VoidCallback onExplain;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.cardLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Q$n',
                  style: RenanceText.labelMono
                      .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (q.topic.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.topic + (q.year > 0 ? '  ${q.year}' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.caption
                        .copyWith(color: context.textSecondary),
                  ),
                ),
              ] else
                const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleSave,
                icon: MsIcon(
                  'bookmark',
                  size: 20,
                  fill: saved,
                  color: saved ? context.primary : context.textSecondary,
                ),
                tooltip: saved ? 'Unsave' : 'Save question',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Clipboard.setData(ClipboardData(
                  text: <String>[
                    q.stem,
                    for (final MapEntry<String, String> e in q.options.entries)
                      '${e.key}) ${e.value}',
                  ].join('\n'),
                )),
                icon: MsIcon('content_copy',
                    size: 18, color: context.textSecondary),
                tooltip: 'Copy question',
              ),
            ],
          ),
          if (q.passage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _PassageDrawer(passage: q.passage),
          ],
          const SizedBox(height: 8),
          QuestionText(
            q.stem,
            style: RenanceText.bodyBase
                .copyWith(fontSize: 15.5, height: 1.45, color: context.ink),
          ),
          if (q.image.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                resolveQImageUrl(q.image),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (q.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final MapEntry<String, String> e in q.options.entries)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardLowest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      e.key,
                      style: RenanceText.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuestionText(
                        e.value,
                        style: RenanceText.bodyBase
                            .copyWith(fontSize: 13.5, color: context.ink),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          TactileButton(
            height: 44,
            radius: BorderRadius.circular(10),
            face: context.inverseChip,
            onFace: context.onInverseChip,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            onPressed: onExplain,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const MsIcon('auto_stories', size: 17, fill: true),
                const SizedBox(width: 8),
                const Text('View Explanation'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The comprehension passage drawer - collapsed by default like the
/// web's details drawer, expanded it scrolls a bounded preview.
class _PassageDrawer extends StatelessWidget {
  const _PassageDrawer({required this.passage});

  final String passage;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        backgroundColor: context.cardLow.withValues(alpha: 0.5),
        collapsedBackgroundColor: context.cardLow.withValues(alpha: 0.5),
        iconColor: context.textSecondary,
        collapsedIconColor: context.textSecondary,
        title: Text(
          'COMPREHENSION PASSAGE',
          style: RenanceText.labelMono.copyWith(
              fontSize: 10, letterSpacing: 1.1, color: context.textSecondary),
        ),
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: QuestionText(
                passage,
                style: RenanceText.bodyBase.copyWith(color: context.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
