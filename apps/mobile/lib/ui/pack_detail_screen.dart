/// Pack detail, the Stitch pack_detail_light screen, 1:1.
///
/// Hero card (subject icon, title, body chip), the four-stat grid
/// (questions, marks, duration, size), offline state, and topic coverage
/// when the pack sits on the device. Wide windows (desktop, >= 700 px)
/// keep the column centered at a readable measure instead of stretching.
///
/// Entry: library pack cards tap here; the primary button hands control
/// back to the shell's exam opener (fast path unchanged elsewhere).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'theme.dart';

class PackDetailScreen extends StatefulWidget {
  const PackDetailScreen({
    super.key,
    required this.exam,
    required this.onStart,
  });

  final ExamMeta exam;
  final void Function(BuildContext context, ExamMeta exam) onStart;

  @override
  State<PackDetailScreen> createState() => _PackDetailScreenState();
}

class _PackDetailScreenState extends State<PackDetailScreen> {
  /// Topic coverage, loaded lazily only when the pack is already offline.
  List<(String, int)>? _topics;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final StudentController student = context.read<StudentController>();
    if (!student.downloaded.contains(widget.exam.code)) return;
    final PackStore store = context.read<PackStore>();
    final Bundle? bundle =
        await store.loadPack(widget.exam.code, widget.exam.bundleSha256);
    if (!mounted || bundle == null) return;
    final Map<String, int> counts = <String, int>{};
    for (final BundleQuestion q in bundle.questions) {
      final String topic =
          q.topic.isEmpty ? 'General' : q.topic;
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
    final List<(String, int)> topics = counts.entries
        .map((MapEntry<String, int> e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    if (!mounted) return;
    setState(() => _topics = topics);
  }

  String _sizeLabel(int bytes) {
    if (bytes <= 0) return 'synced over the air';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    final StudentController student = context.watch<StudentController>();
    final ExamMeta exam = widget.exam;
    final bool downloaded = student.downloaded.contains(exam.code);
    final bool downloading =
        sync.isSyncing && !downloaded && sync.phase == SyncPhase.syncing;

    return Scaffold(
      backgroundColor: RenanceColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                _Header(exam: exam, onBack: () => Navigator.of(context).pop()),
                const SizedBox(height: 16),
                _StatsGrid(
                  cells: <(String, String)>[
                    ('Questions', '${exam.questionCount}'),
                    ('Total marks', '${exam.totalMarks}'),
                    (
                      'Duration',
                      exam.durationMinutes == null
                          ? 'Untimed'
                          : '${exam.durationMinutes} min'
                    ),
                    ('Offline size', _sizeLabel(exam.sizeBytes)),
                  ],
                ),
                const SizedBox(height: 16),
                _OfflineCard(
                  downloaded: downloaded,
                  downloading: downloading,
                  onDownload: downloading
                      ? null
                      : () async {
                          await context
                              .read<SyncController>()
                              .downloadExam(exam);
                          if (mounted) await _loadTopics();
                        },
                ),
                const SizedBox(height: 16),
                if (_topics != null && _topics!.isNotEmpty) ...<Widget>[
                  const _SectionLabel('Topic coverage'),
                  const SizedBox(height: 10),
                  _TopicCoverage(topics: _topics!, total: exam.questionCount),
                  const SizedBox(height: 24),
                ],
                _PrimaryButton(
                  label: downloaded ? 'Start practice' : 'Download & practice',
                  onPressed: () => widget.onStart(context, exam),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({required this.exam, required this.onBack});

  final ExamMeta exam;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: RenanceColors.ink,
        ),
        const SizedBox(width: 4),
        _SubjectIcon(exam: exam),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                exam.title,
                style: RenanceText.sectionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                <String>[
                  if (exam.body.isNotEmpty) exam.body,
                  if (exam.category.isNotEmpty) exam.category,
                ].join(' · '),
                style: RenanceText.labelMono.copyWith(
                  color: RenanceColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectIcon extends StatelessWidget {
  const _SubjectIcon({required this.exam});

  final ExamMeta exam;

  @override
  Widget build(BuildContext context) {
    final String code = exam.code.toLowerCase();
    final IconData icon = switch (code) {
      final String c when c.contains('bio') => Icons.biotech,
      final String c when c.contains('chem') => Icons.science,
      final String c when c.contains('phys') => Icons.rocket_launch,
      final String c when c.contains('english') => Icons.translate,
      final String c when c.contains('math') => Icons.calculate,
      final String c when c.contains('cos') => Icons.terminal,
      _ => Icons.description,
    };
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: RenanceColors.ink, size: 24),
    );
  }
}

// ------------------------------------------------------------------- stats

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < cells.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    cells[i].$2,
                    style: RenanceText.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cells[i].$1,
                    textAlign: TextAlign.center,
                    style: RenanceText.labelMono.copyWith(
                      fontSize: 10,
                      color: RenanceColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- offline card

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
  });

  final bool downloaded;
  final bool downloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String body, Color tint) = downloaded
        ? (
            Icons.offline_bolt,
            'Ready offline',
            'This pack lives on your device. Practice without data.',
            RenanceColors.emerald,
          )
        : downloading
            ? (
                Icons.downloading,
                'Downloading…',
                'The pack lands on your device in moments.',
                RenanceColors.amber,
              )
            : (
                Icons.cloud_download_outlined,
                'Not on this device yet',
                'Tap download to keep this pack available without data.',
                RenanceColors.textSecondary,
              );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RenanceColors.outlineLight),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: RenanceText.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: RenanceText.caption,
                ),
              ],
            ),
          ),
          if (!downloaded && !downloading)
            TextButton(
              onPressed: onDownload,
              style: TextButton.styleFrom(
                foregroundColor: RenanceColors.ink,
                textStyle: RenanceText.bodyMedium,
              ),
              child: const Text('Download'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- coverage

class _TopicCoverage extends StatelessWidget {
  const _TopicCoverage({required this.topics, required this.total});

  final List<(String, int)> topics;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < topics.length && i < 8; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    topics[i].$1,
                    style: RenanceText.bodyBase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: total == 0
                          ? 0
                          : (topics[i].$2 / total).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: RenanceColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        RenanceColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 26,
                  child: Text(
                    '${topics[i].$2}',
                    textAlign: TextAlign.right,
                    style: RenanceText.labelMono,
                  ),
                ),
              ],
            ),
          ],
          if (topics.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '+${topics.length - 8} more topics on the syllabus map',
                style: RenanceText.caption,
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: RenanceText.sectionTitle);
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
