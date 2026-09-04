/// Downloads, the Stitch downloads_light screen, adapted to real data.
///
/// Storage meter for the on-device pack library (real byte sizes from the
/// PackStore), the silent-sync status card, and the downloaded pack list
/// with per-pack delete.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'renance_logo.dart';
import 'theme.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Map<String, int> _sizes = const <String, int>{};
  List<ExamMeta> _exams = const <ExamMeta>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final PackStore store = context.read<PackStore>();
    final SyncController sync = context.read<SyncController>();
    final sizes = await store.packSizes();
    if (!mounted) return;
    setState(() {
      _sizes = sizes;
      _exams = sync.exams;
    });
  }

  String _titleFor(String code) {
    for (final ExamMeta e in _exams) {
      if (e.code == code) return e.title;
    }
    return code;
  }

  IconData _iconFor(String title) {
    final String t = title.toLowerCase();
    if (t.contains('biolog') || t.contains('microb')) return Icons.biotech;
    if (t.contains('chem')) return Icons.science;
    if (t.contains('math') || t.contains('calcul')) return Icons.calculate;
    if (t.contains('histor') || t.contains('english')) return Icons.history_edu;
    return Icons.description;
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final Set<String> downloaded = student.downloaded;
    final int totalBytes =
        _sizes.values.fold(0, (int sum, int b) => sum + b);

    return Scaffold(
      backgroundColor: RenanceColors.background,
      appBar: AppBar(
        title: const Text('Downloads', style: RenanceText.sectionTitle),
        backgroundColor: RenanceColors.background,
      ),
      body: downloaded.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const RenanceMark(size: 56),
                  const SizedBox(height: 16),
                  Text('No offline packs yet',
                      style: RenanceText.sectionTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Download a pack from the Practice tab and it lives\n'
                    'here, ready with zero network.',
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                // Storage --------------------------------------------------
                Text('Storage', style: RenanceText.sectionTitle),
                const SizedBox(height: 4),
                Text('${_fmtBytes(totalBytes)} of packs on this device',
                    style: RenanceText.caption),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalBytes == 0 ? 0 : 0.08,
                    minHeight: 10,
                    backgroundColor: RenanceColors.surfaceContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        RenanceColors.ink),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black)),
                    const SizedBox(width: 6),
                    Text('Offline Packs', style: RenanceText.caption),
                    const SizedBox(width: 16),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: RenanceColors.surfaceContainer)),
                    const SizedBox(width: 6),
                    Text('Free space', style: RenanceText.caption),
                  ],
                ),
                // Silent sync ----------------------------------------------
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RenanceColors.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x0F141C2D),
                          blurRadius: 3,
                          offset: Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: RenanceColors.selectionBlue,
                        child: const Icon(Icons.bolt,
                            size: 20, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('Silent Sync',
                                style: RenanceText.bodyMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Your packs download automatically when the '
                              'app opens, you are never without study '
                              'materials, even offline.',
                              style: RenanceText.caption.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Text('Status: Active',
                                style: RenanceText.labelMono.copyWith(
                                    fontSize: 12,
                                    color: RenanceColors.emerald)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Pack list ------------------------------------------------
                const SizedBox(height: 20),
                const Text('Downloaded Packs', style: RenanceText.sectionTitle),
                const SizedBox(height: 12),
                ...downloaded.map((String code) {
                  final int size = _sizes[code] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RenanceColors.card,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                              color: Color(0x0F141C2D),
                              blurRadius: 3,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: RenanceColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_iconFor(_titleFor(code)),
                                size: 22, color: RenanceColors.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(_titleFor(code),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RenanceText.bodyMedium),
                                Text(_fmtBytes(size),
                                    style: RenanceText.caption),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle,
                              size: 18, color: RenanceColors.emerald),
                          const SizedBox(width: 4),
                          Text('Downloaded',
                              style: RenanceText.labelMono.copyWith(
                                  fontSize: 11,
                                  color: RenanceColors.emerald)),
                          IconButton(
                            tooltip: 'Delete pack',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: RenanceColors.error),
                            onPressed: () async {
                              final PackStore store = context.read<PackStore>();
                              final StudentController student =
                                  context.read<StudentController>();
                              await store.removePack(code);
                              await student.refreshDownloaded();
                              if (!mounted) return;
                              await _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
