/// GPA / CGPA calculator — the app mirror of the website's /gpa tool.
///
/// Pure client-side: no account, no API, works offline. Nigerian 5.0
/// scale (A=5 … F=0), current-semester GPA plus a previous-CGPA fold-in,
/// persisted through SharedPreferences so a student can pick up where
/// they left off. Class-of-degree bands follow the standard Nigerian
/// bands.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const List<({String letter, int points})> _grades = <({String letter, int points})>[
  (letter: 'A', points: 5),
  (letter: 'B', points: 4),
  (letter: 'C', points: 3),
  (letter: 'D', points: 2),
  (letter: 'E', points: 1),
  (letter: 'F', points: 0),
];

const List<int> _unitOptions = <int>[0, 1, 2, 3, 4, 5, 6];
const String _storeKey = 'renance.gpa.v1';

class _CourseRow {
  _CourseRow({required this.id, required this.code, required this.units, required this.grade});

  final int id;
  String code;
  int units;
  String grade;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'units': units,
        'grade': grade,
      };
}

class _GpaComputation {
  const _GpaComputation({
    required this.gpa,
    required this.semesterUnits,
    required this.cgpa,
    required this.totalUnits,
    required this.classOf,
  });

  final double gpa;
  final int semesterUnits;
  final double cgpa;
  final int totalUnits;
  final String classOf;
}

int _pointsOf(String letter) =>
    _grades.firstWhere((({String letter, int points}) g) => g.letter == letter,
        orElse: () => (letter: 'F', points: 0))
        .points;

String _classify(double cgpa) {
  if (cgpa >= 4.5) return 'First Class';
  if (cgpa >= 3.5) return 'Second Class Upper (2:1)';
  if (cgpa >= 2.4) return 'Second Class Lower (2:2)';
  if (cgpa >= 1.5) return 'Third Class';
  if (cgpa >= 1.0) return 'Pass';
  return 'Below pass mark';
}

class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key, this.embedded = false});

  /// When true the calculator renders as the shell's 4th tab: no back
  /// bar and the launcher's header-clearing top padding.
  final bool embedded;

  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen> {
  List<_CourseRow> _rows = <_CourseRow>[];
  String _prevCgpa = '';
  String _prevUnits = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<_CourseRow> fresh = <_CourseRow>[
      _CourseRow(id: 1, code: '', units: 3, grade: 'A'),
      _CourseRow(id: 2, code: '', units: 3, grade: 'A'),
      _CourseRow(id: 3, code: '', units: 2, grade: 'B'),
      _CourseRow(id: 4, code: '', units: 2, grade: 'B'),
      _CourseRow(id: 5, code: '', units: 2, grade: 'C'),
    ];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storeKey);
      if (raw != null) {
        // Minimal parse without dart:convert map casts on unknown shapes.
        final List<_CourseRow> saved = <_CourseRow>[];
        String prevCgpa = '';
        String prevUnits = '';
        for (final String line in raw.split('\n')) {
          if (line.startsWith('cgpa=')) {
            prevCgpa = line.substring(5);
          } else if (line.startsWith('units=')) {
            prevUnits = line.substring(6);
          } else if (line.startsWith('row=')) {
            final List<String> p = line.substring(4).split('|');
            if (p.length == 4) {
              saved.add(_CourseRow(
                id: int.tryParse(p[0]) ?? 0,
                code: p[1],
                units: int.tryParse(p[2]) ?? 0,
                grade: p[3],
              ));
            }
          }
        }
        if (mounted) {
          setState(() {
            if (saved.isNotEmpty) _rows = saved;
            _prevCgpa = prevCgpa;
            _prevUnits = prevUnits;
          });
        }
      } else if (mounted) {
        setState(() => _rows = fresh);
      }
    } catch (_) {
      if (mounted) setState(() => _rows = fresh);
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final StringBuffer buf = StringBuffer();
      buf.writeln('cgpa=$_prevCgpa');
      buf.writeln('units=$_prevUnits');
      for (final _CourseRow r in _rows) {
        buf.writeln('row=${r.id}|${r.code}|${r.units}|${r.grade}');
      }
      await prefs.setString(_storeKey, buf.toString());
    } catch (_) {
      /* private mode: the calculator still works, just not persisted */
    }
  }

  void _mutate(void Function() change) {
    setState(change);
    _persist();
  }

  _GpaComputation compute() {
    double points = 0;
    int units = 0;
    for (final _CourseRow r in _rows) {
      final int u = r.units;
      points += u * _pointsOf(r.grade);
      units += u;
    }
    final double semGpa = units > 0 ? points / units : 0;

    final int prevU = int.tryParse(_prevUnits) ?? 0;
    final double prevC = double.tryParse(_prevCgpa) ?? 0;
    final double allPoints = points + prevC * prevU;
    final int allUnits = units + prevU;
    final double allCgpa = allUnits > 0 ? allPoints / allUnits : 0;

    return _GpaComputation(
      gpa: semGpa,
      semesterUnits: units,
      cgpa: allCgpa,
      totalUnits: allUnits,
      classOf: _classify(allCgpa),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _GpaComputation c = compute();
    final Widget list = Padding(
      padding: EdgeInsets.only(
        top: widget.embedded ? MediaQuery.paddingOf(context).top + 64 + 16 : 0,
      ),
      child: _sheet(context, c),
    );
    if (widget.embedded) {
      return list;
    }
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _sheet(context, c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context, _GpaComputation c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text('GPA Calculator', style: RenanceText.displayLg),
        const SizedBox(height: 16),
                      // Result card ------------------------------------
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.inverseChip,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('SEMESTER GPA',
                                      style: RenanceText.labelMono.copyWith(
                                          fontSize: 10,
                                          color: context.onInverseChip
                                              .withValues(alpha: 0.7))),
                                  const SizedBox(height: 4),
                                  Text(c.gpa.toStringAsFixed(2),
                                      style: RenanceText.displayLg.copyWith(
                                          color: context.onInverseChip)),
                                  Text('${c.semesterUnits} units this semester',
                                      style: RenanceText.caption.copyWith(
                                          color: context.onInverseChip
                                              .withValues(alpha: 0.7))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                      color: Color(0x14141C2D),
                                      blurRadius: 3,
                                      offset: Offset(0, 1)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('CGPA',
                                      style: RenanceText.labelMono.copyWith(
                                          fontSize: 10,
                                          color: context.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(c.cgpa.toStringAsFixed(2),
                                      style: RenanceText.displayLg),
                                  Text(c.classOf,
                                      style: RenanceText.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: context.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Semester courses --------------------------------
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text("This semester's courses",
                              style: RenanceText.sectionTitle),
                          TextButton(
                            onPressed: () => _mutate(() {
                              _rows = <_CourseRow>[
                                _CourseRow(id: 1, code: '', units: 3, grade: 'A'),
                                _CourseRow(id: 2, code: '', units: 3, grade: 'A'),
                                _CourseRow(id: 3, code: '', units: 2, grade: 'B'),
                                _CourseRow(id: 4, code: '', units: 2, grade: 'B'),
                                _CourseRow(id: 5, code: '', units: 2, grade: 'C'),
                              ];
                              _prevCgpa = '';
                              _prevUnits = '';
                            }),
                            child: Text('Reset',
                                style: RenanceText.bodyMedium
                                    .copyWith(color: context.error)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final _CourseRow r in _rows)
                        _CourseRowTile(
                          row: r,
                          onCode: (String v) => _mutate(() => r.code = v),
                          onUnits: (int? u) =>
                              _mutate(() => r.units = u ?? 0),
                          onGrade: (String? g) =>
                              _mutate(() => r.grade = g ?? 'A'),
                          onRemove: () => _mutate(() {
                            if (_rows.length > 1) {
                              _rows.remove(r);
                            }
                          }),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _mutate(() {
                          final int nextId = _rows
                              .map((_CourseRow r) => r.id)
                              .fold<int>(0, (int a, int b) => a > b ? a : b) + 1;
                          _rows.add(_CourseRow(
                            id: nextId,
                            code: '',
                            units: 2,
                            grade: 'A',
                          ));
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add course'),
                      ),
                      // Previous sessions fold-in -----------------------
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                                color: Color(0x14141C2D),
                                blurRadius: 3,
                                offset: Offset(0, 1)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Fold in previous sessions',
                                style: RenanceText.sectionTitle),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your cumulative record so far — the CGPA above combines this semester with it.',
                              style: RenanceText.caption
                                  .copyWith(color: context.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    onChanged: (String v) =>
                                        _mutate(() => _prevCgpa = v),
                                    controller: TextEditingController(
                                        text: _prevCgpa),
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Previous CGPA',
                                      hintText: 'e.g. 4.12',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    onChanged: (String v) =>
                                        _mutate(() => _prevUnits = v),
                                    controller: TextEditingController(
                                        text: _prevUnits),
                                    keyboardType: const TextInputType.numberWithOptions(),
                                    decoration: const InputDecoration(
                                      labelText: 'Total units so far',
                                      hintText: 'e.g. 86',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Scale: A=5 · B=4 · C=3 · D=2 · E=1 · F=0 — the standard Nigerian university 5.0 scale.'
                              '${c.totalUnits > 0 ? ' Cumulative total: ${c.totalUnits} units at ${c.cgpa.toStringAsFixed(2)}.' : ''}',
                              style: RenanceText.caption
                                  .copyWith(color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
    ],
        );
  }
}

/// One editable course row: code field, units dropdown, grade dropdown,
/// remove button.
class _CourseRowTile extends StatelessWidget {
  const _CourseRowTile({
    required this.row,
    required this.onCode,
    required this.onUnits,
    required this.onGrade,
    required this.onRemove,
  });

  final _CourseRow row;
  final ValueChanged<String> onCode;
  final ValueChanged<int?> onUnits;
  final ValueChanged<String?> onGrade;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: TextEditingController(text: row.code),
              onChanged: onCode,
              decoration: const InputDecoration(
                hintText: 'Course (e.g. CSC 201)',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          DropdownButton<int>(
            value: _unitOptions.contains(row.units) ? row.units : 0,
            items: <DropdownMenuItem<int>>[
              for (final int u in _unitOptions)
                DropdownMenuItem<int>(value: u, child: Text('$u U')),
            ],
            onChanged: onUnits,
            underline: const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: row.grade,
            items: <DropdownMenuItem<String>>[
              for (final ({String letter, int points}) g in _grades)
                DropdownMenuItem<String>(value: g.letter, child: Text(g.letter)),
            ],
            onChanged: onGrade,
            underline: const SizedBox.shrink(),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: context.textSecondary,
            tooltip: 'Remove ${row.code.isEmpty ? 'course' : row.code}',
          ),
        ],
      ),
    );
  }
}
