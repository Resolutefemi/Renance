import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'theme.dart';
import 'inline_text.dart';

/// Lessons library (ROADMAP #8) — mdx-built reading, cached offline like
/// packs and decks. List view: subject chip, title, summary, read time.
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  @override
  void initState() {
    super.initState();
    final LessonsController lessons = context.read<LessonsController>();
    Future<void>.microtask(() => lessons.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RenanceColors.background,
      appBar: AppBar(
        title: const Text('Lessons'),
        backgroundColor: RenanceColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<LessonsController>(
        builder: (BuildContext context, LessonsController lessons, _) {
          if (lessons.phase == LessonsPhase.loading &&
              lessons.lessons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (lessons.lessons.isEmpty) {
            return _MessageCard(
              message: lessons.error.isNotEmpty
                  ? lessons.error
                  : 'Lessons are being typeset — pull to refresh shortly.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => lessons.load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                if (lessons.error.isNotEmpty &&
                    lessons.phase == LessonsPhase.ready)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OfflineNote(lessons.error),
                  ),
                ...lessons.lessons.map(
                  (LessonMeta l) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LessonCard(meta: l),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.meta});

  final LessonMeta meta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RenanceColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                LessonReaderScreen(slug: meta.slug, title: meta.title),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RenanceColors.outlineVariant, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (meta.subject.isNotEmpty)
                    _Chip(label: meta.subject, filled: true),
                  if (meta.subject.isNotEmpty && meta.body.isNotEmpty)
                    const SizedBox(width: 6),
                  if (meta.body.isNotEmpty) _Chip(label: meta.body),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                meta.title,
                style: RenanceText.sectionTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              InlineText(
                meta.summary,
                style: RenanceText.bodySecondary.copyWith(
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: RenanceColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${meta.minutes} min read',
                    style: RenanceText.labelMono.copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: RenanceColors.textSecondary,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? RenanceColors.selectionBlue
            : RenanceColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: RenanceText.caption.copyWith(
          fontSize: 11,
          fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// One lesson, full sections. Loaded online-first with cache fallback.
class LessonReaderScreen extends StatefulWidget {
  const LessonReaderScreen({
    super.key,
    required this.slug,
    required this.title,
  });

  final String slug;
  final String title;

  @override
  State<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends State<LessonReaderScreen> {
  Lesson? _lesson;
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    final LessonsController lessons = context.read<LessonsController>();
    Future<void>.microtask(() async {
      final Lesson? les = await lessons.loadLesson(widget.slug);
      if (!mounted) return;
      setState(() {
        _lesson = les;
        _loading = false;
        _offline =
            les != null &&
            lessons.phase == LessonsPhase.ready &&
            lessons.error.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RenanceColors.background,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: RenanceColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lesson == null
          ? const _MessageCard(
              message: 'This lesson is not saved on your device yet — reconnect and open it once.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                if (_offline) ...<Widget>[
                  const _OfflineNote('Offline — reading your saved copy.'),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: <Widget>[
                    if (_lesson!.subject.isNotEmpty)
                      _Chip(label: _lesson!.subject, filled: true),
                    if (_lesson!.subject.isNotEmpty && _lesson!.body.isNotEmpty)
                      const SizedBox(width: 6),
                    if (_lesson!.body.isNotEmpty) _Chip(label: _lesson!.body),
                    const Spacer(),
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: RenanceColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_lesson!.minutes} min read',
                      style: RenanceText.labelMono.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _lesson!.title,
                  style: RenanceText.displayMd.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                InlineText(
                  _lesson!.summary,
                  style: RenanceText.bodySecondary.copyWith(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _lesson!.sections.length; i++)
                  _Section(index: i + 1, section: _lesson!.sections[i]),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.index, required this.section});

  final int index;
  final LessonSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$index. ${section.heading}',
            style: RenanceText.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 10),
          for (final LessonBlock b in section.blocks) ...<Widget>[
            _Block(block: b),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final LessonBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            block.text,
            style: RenanceText.sectionTitle.copyWith(fontSize: 15),
          ),
        );
      case 'callout':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1AF59E0B), // amber @10% — key-point tone
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: RenanceColors.amber, width: 3),
            ),
          ),
          child: InlineText(
            block.text,
            style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.5),
          ),
        );
      case 'ul':
      case 'ol':
        return Column(
          children: <Widget>[
            for (var i = 0; i < block.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      child: Text(
                        block.type == 'ol' ? '${i + 1}.' : '•',
                        style: RenanceText.bodyBase.copyWith(
                          fontSize: 13.5,
                          fontWeight: block.type == 'ol'
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: InlineText(
                        block.items[i],
                        style: RenanceText.bodyBase.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'p':
      default:
        return InlineText(
          block.text,
          style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.55),
        );
    }
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_off,
            size: 15,
            color: RenanceColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: RenanceText.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: RenanceText.bodySecondary.copyWith(fontSize: 13, height: 1.5),
        ),
      ),
    );
  }
}
