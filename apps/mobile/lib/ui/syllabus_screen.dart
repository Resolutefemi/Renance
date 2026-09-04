import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../controllers.dart';
import 'renance_logo.dart';
import 'theme.dart';

/// The syllabus map (Stitch syllabus_map_light, ROADMAP #4): the
/// curriculum tree of one exam body overlaid with the student's own
/// SM-2 mastery state. Header card carries the mastery ring + legend;
/// sections expand into topic rows with mastery dots and accuracy bars;
/// the "Focus next" chips deep-link the server's weakest topics.
class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key, this.initialBody = 'jamb'});

  /// Slug of the body to open by default ("jamb", "university-modules").
  final String initialBody;

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  static const List<(String, String)> _bodies = <(String, String)>[
    ('jamb', 'JAMB'),
    ('waec', 'WAEC'),
    ('university-modules', 'University'),
  ];

  late String _body;
  SyllabusTree? _tree;
  bool _loading = false;
  String? _error;
  final Set<String> _expanded = <String>{};
  String? _highlight;

  @override
  void initState() {
    super.initState();
    _body = widget.initialBody;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<StudentController>().api;
    if (api == null) {
      if (mounted) {
        setState(() => _error = 'Sign in to open the syllabus map.');
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tree = await api.syllabus(_body);
      if (!mounted) return;
      setState(() => _tree = tree);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchBody(String slug) {
    if (slug == _body || _loading) return;
    setState(() {
      _body = slug;
      _tree = null;
      _expanded.clear();
      _highlight = null;
    });
    _load();
  }

  void _focusTopic(SyllabusTopic t) {
    final tree = _tree;
    if (tree == null) return;
    for (final subject in tree.subjects) {
      for (final sec in subject.sections) {
        if (sec.topics.any((x) => x.topic == t.topic)) {
          setState(() {
            _expanded.add(sec.title);
            _highlight = t.topic;
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = _tree;
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  BackButton(onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Syllabus',
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.sectionTitle),
                  ),
                ],
              ),
            ),
            // Body pills ---------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  for (final (slug, label) in _bodies)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _BodyPill(
                        label: label,
                        active: slug == _body,
                        onTap: () => _switchBody(slug),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: LogoActivityIndicator(label: 'Opening the map…'))
                  : _error != null
                      ? _ErrorPane(message: _error!, onRetry: _load)
                      : tree == null
                          ? const SizedBox.shrink()
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: <Widget>[
                                  _HeaderCard(tree: tree),
                                  if (tree.weakest.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 12),
                                    _FocusNext(
                                      topics: tree.weakest,
                                      onTap: _focusTopic,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  for (final subject in tree.subjects)
                                    _SubjectBlock(
                                      subject: subject,
                                      expanded: _expanded,
                                      highlight: _highlight,
                                      onToggle: (String title) => setState(() {
                                        if (!_expanded.remove(title)) {
                                          _expanded.add(title);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header

/// Header card: circular mastery ring + legend (Stitch syllabus_map_light).
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.tree});

  final SyllabusTree tree;

  @override
  Widget build(BuildContext context) {
    // Ring = covered ground: mastered weighs full, learning weighs its
    // accuracy. Unseen contributes nothing, honest, never inflated.
    final double learningSum = tree.subjects.fold<double>(0, (sum, s) {
      for (final sec in s.sections) {
        for (final t in sec.topics) {
          if (t.status == 'learning') sum += t.accuracy;
        }
      }
      return sum;
    });
    final double mastery =
        tree.stats.topics == 0 ? 0 : (tree.stats.mastered + learningSum) / tree.stats.topics;
    final int pct = (mastery * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('COURSE SYLLABUS', style: RenanceText.overline.copyWith(color: context.textSecondary)),
                const SizedBox(height: 4),
                Text(tree.body, style: RenanceText.displayMd),
                const SizedBox(height: 10),
                Text(
                  '${tree.stats.topics} topics · '
                  '${tree.stats.mastered} mastered · '
                  '${tree.stats.learning} learning · '
                  '${tree.stats.unseen} unseen',
                  style: RenanceText.caption.copyWith(
                      color: context.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _LegendDot(color: RenanceColors.emerald, label: 'Mastered'),
                    SizedBox(width: 12),
                    _LegendDot(color: RenanceColors.amber, label: 'Learning'),
                    SizedBox(width: 12),
                    _LegendDot(
                        color: context.surfaceVariant, label: 'Unseen'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _MasteryRing(pct: pct),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: RenanceText.caption.copyWith(color: context.textSecondary)
                .copyWith(color: context.textSecondary, fontSize: 11)),
      ],
    );
  }
}

/// The circular progress ring of the header (72px, emerald arc).
class _MasteryRing extends StatelessWidget {
  const _MasteryRing({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: context.surfaceVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(RenanceColors.emerald),
            ),
          ),
          Text('$pct%',
              style: RenanceText.statNumber.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- focus next

/// "Focus next", the server's weakest topics as amber chips. Tap expands
/// the section that holds the topic and highlights the row.
class _FocusNext extends StatelessWidget {
  const _FocusNext({required this.topics, required this.onTap});

  final List<SyllabusTopic> topics;
  final ValueChanged<SyllabusTopic> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Focus next',
            style: RenanceText.sectionTitle.copyWith(
                color: context.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final t in topics)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: RenanceColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: RenanceColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.local_fire_department,
                          size: 14, color: RenanceColors.amber),
                      const SizedBox(width: 4),
                      Text(
                        t.lastTotal > 0
                            ? '${t.topic} · ${(t.accuracy * 100).round()}%'
                            : t.topic,
                        style: RenanceText.labelMono.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- sections

class _SubjectBlock extends StatelessWidget {
  const _SubjectBlock({
    required this.subject,
    required this.expanded,
    required this.highlight,
    required this.onToggle,
  });

  final SyllabusSubject subject;
  final Set<String> expanded;
  final String? highlight;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (subject.sections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(subject.subject, style: RenanceText.bodyMedium),
          ),
        for (var i = 0; i < subject.sections.length; i++)
          _SectionCard(
            index: i + 1,
            section: subject.sections[i],
            open: expanded.contains(subject.sections[i].title),
            highlight: highlight,
            onToggle: () => onToggle(subject.sections[i].title),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.index,
    required this.section,
    required this.open,
    required this.highlight,
    required this.onToggle,
  });

  final int index;
  final SyllabusSection section;
  final bool open;
  final String? highlight;
  final VoidCallback onToggle;

  Color _pctColor(BuildContext context) {
    final int p = (section.mastery * 100).round();
    if (p >= 70) return RenanceColors.emerald;
    if (p > 0) return RenanceColors.amber;
    return context.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$index',
                        style: RenanceText.labelMono.copyWith(fontSize: 13)),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(section.title,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.bodyMedium),
                  ),
                  Text('${(section.mastery * 100).round()}%',
                      style: RenanceText.labelMono
                          .copyWith(fontSize: 12, color: _pctColor(context))),
                  SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        size: 20, color: context.outlineDark),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: <Widget>[
                  for (final t in section.topics)
                    _TopicRow(topic: t, highlight: highlight == t.topic),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One topic row: name + question count on the left, three mastery dots
/// and an accuracy bar on the right, exactly the design's anatomy.
class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.highlight});

  final SyllabusTopic topic;
  final bool highlight;

  Color _dotColor(BuildContext context) {
    switch (topic.status) {
      case 'mastered':
        return RenanceColors.emerald;
      case 'learning':
        return RenanceColors.amber;
      default:
        return context.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.pageBg,
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: RenanceColors.amber, width: 1.4)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(topic.topic,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyMedium.copyWith(fontSize: 13)),
              ),
              for (var i = 0; i < 3; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < topic.dot
                        ? _dotColor(context)
                        : context.surfaceVariant,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                topic.seen && topic.lastTotal > 0
                    ? '${topic.questions} questions · last ${topic.lastCorrect}/${topic.lastTotal}'
                    : '${topic.questions} questions · not tried yet',
                style: RenanceText.caption.copyWith(
                    fontSize: 11, color: context.textSecondary),
              ),
              const Spacer(),
              SizedBox(
                width: 96,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: topic.accuracy,
                    minHeight: 6,
                    backgroundColor: context.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        topic.status == 'mastered'
                            ? RenanceColors.emerald
                            : RenanceColors.amber),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

class _BodyPill extends StatelessWidget {
  const _BodyPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : context.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? Colors.black : context.outlineLight),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            color: active ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.menu_book_outlined,
                size: 40, color: context.outlineLight),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
