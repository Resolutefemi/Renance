/// The daily CBT subject-combination bottom sheet (the founder's rule).
///
/// The first Daily tap asks for the combination: every subject the
/// student's focus body banks, multi-pick, at most nine. Saving hits
/// PUT /me/daily-subjects and the server then composes every daily
/// sprint from exactly those subjects - the same paper the web plays.
library;

import 'package:flutter/material.dart';

import '../api_client.dart';
import 'theme.dart';

/// Bodies that carry per-subject banks (the only ones that ever ask).
const Set<String> kComboBodies = <String>{'JAMB', 'WAEC', 'NECO'};

/// Returns the saved combination, or null when the student dismissed.
Future<List<String>?> showDailySubjectsSheet(
  BuildContext context, {
  required ApiClient api,
  required String body,
  required List<({String slug, int count})> subjects,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _DailySubjectsSheet(
      api: api,
      body: body,
      subjects: subjects,
    ),
  );
}

class _DailySubjectsSheet extends StatefulWidget {
  const _DailySubjectsSheet({
    required this.api,
    required this.body,
    required this.subjects,
  });

  final ApiClient api;
  final String body;
  final List<({String slug, int count})> subjects;

  @override
  State<_DailySubjectsSheet> createState() => _DailySubjectsSheetState();
}

class _DailySubjectsSheetState extends State<_DailySubjectsSheet> {
  final Set<String> _picked = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // JAMB convention: Use of English rides every combination.
    if (widget.body == 'JAMB') _picked.add('english');
  }

  String _label(String slug) => slug
      .split('-')
      .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Future<void> _save() async {
    if (_picked.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.setDailySubjects(_picked.toList()..sort());
      if (!mounted) return;
      Navigator.of(context).pop(_picked.toList()..sort());
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on NetworkException {
      setState(() {
        _busy = false;
        _error = 'No connection, try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.heightOf(context) * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your Daily subjects',
              style: RenanceText.sectionTitle.copyWith(fontSize: 19),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick your subject combination once - every daily CBT then '
              'shows only these subjects, every day.'
              '${widget.body == 'JAMB' ? ' Use of English is pre-picked, the hall rule.' : ''}',
              style: RenanceText.bodyMedium.copyWith(
                color: Colors.black54,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final (:slug, :count) in widget.subjects)
                      _SubjectChip(
                        label: _label(slug),
                        count: count,
                        on: _picked.contains(slug),
                        onTap: () => setState(() {
                          if (_picked.contains(slug)) {
                            _picked.remove(slug);
                          } else if (_picked.length < 9) {
                            _picked.add(slug);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_picked.length}/9 picked · at least 1',
              style: RenanceText.labelMono.copyWith(
                fontSize: 11,
                color: Colors.black38,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: (_picked.isEmpty || _busy) ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_busy ? 'Saving…' : 'Save & start'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? Colors.black : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                color: on ? Colors.white : Colors.black54,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count Q',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'JetBrainsMono',
                color: on ? Colors.white70 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
