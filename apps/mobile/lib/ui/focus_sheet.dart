/// Switch Learning Focus, the Stitch exam_target_light screen as a sheet.
///
/// Opened from the profile screen: the scholar taps their profile, taps the
/// learning-focus card and moves between JAMB / WAEC / NECO / University
/// modules without losing any data. Saving calls PUT /me/profile with the
/// existing identity fields and the new focus, then the shell re-syncs.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'theme.dart';

class FocusSheet extends StatefulWidget {
  const FocusSheet({super.key});

  /// Shows the sheet; returns true when the focus was changed and saved.
  static Future<bool> show(BuildContext context) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FocusSheet(),
    );
    return changed == true;
  }

  @override
  State<FocusSheet> createState() => _FocusSheetState();
}

class _FocusSheetState extends State<FocusSheet> {
  String? _exam;
  int? _year;
  bool _busy = false;
  String? _error;

  static const List<_FocusOption> _options = <_FocusOption>[
    _FocusOption(
      icon: Icons.school,
      title: 'JAMB UTME',
      subtitle: 'Nigerian university admissions',
      server: 'JAMB',
    ),
    _FocusOption(
      icon: Icons.workspace_premium,
      title: 'WAEC/WASSCE',
      subtitle: 'West African senior school certificate',
      server: 'WAEC',
    ),
    _FocusOption(
      icon: Icons.verified,
      title: 'NECO',
      subtitle: 'National examinations council',
      server: 'NECO',
    ),
    _FocusOption(
      icon: Icons.account_balance,
      title: 'Tertiary institution',
      subtitle: 'Undergraduate semester exams',
      server: 'University Modules',
    ),
  ];

  static const List<int> _years = <int>[2026, 2027, 2028];

  @override
  void initState() {
    super.initState();
    final Profile? p = context.read<StudentController>().me?.profile;
    _exam = p?.exams.isNotEmpty == true ? p!.exams.first : null;
    _year = p?.targetYear;
  }

  Future<void> _save() async {
    if (_exam == null || _year == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    final Profile? current =
        context.read<StudentController>().me?.profile;
    try {
      await api.updateProfile(
        fullName: current?.fullName ?? '',
        institution: current?.institution ?? '',
        gradeLevel: current?.gradeLevel ?? 'SS3',
        exams: <String>[_exam!],
        targetYear: _year,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: const BoxDecoration(
          color: RenanceColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: Color(0x1F111C2D), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: RenanceColors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('What are you preparing for?',
                          style: RenanceText.displayMd),
                      const SizedBox(height: 8),
                      Text(
                        'Switch your target exam and the whole app reshapes '
                        'around it. Your papers and XP stay put.',
                        style: RenanceText.bodySecondary.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      ..._options.map(_buildOption),
                      const SizedBox(height: 16),
                      const Text('EXAM YEAR', style: RenanceText.overline),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          for (final int y in _years) ...<Widget>[
                            _YearChip(
                              year: y,
                              selected: _year == y,
                              onTap: () => setState(() => _year = y),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(_error!,
                            style: RenanceText.caption
                                .copyWith(color: RenanceColors.error)),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Pinned Continue button, the Stitch exam_target pattern.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        (_exam != null && _year != null && !_busy) ? _save : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_busy ? 'Saving…' : 'Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(_FocusOption t) {
    final bool selected = _exam == t.server;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _exam = t.server),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected ? RenanceColors.selectionBlue : RenanceColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.black : RenanceColors.outlineLight,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? const <BoxShadow>[]
                : const <BoxShadow>[
                    BoxShadow(
                        color: Color(0x0F141C2D),
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.black
                      : RenanceColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(t.icon,
                    size: 22,
                    color: selected ? Colors.white : RenanceColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(t.title,
                        style: RenanceText.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(t.subtitle, style: RenanceText.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    size: 20, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusOption {
  const _FocusOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.server,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String server;
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RenanceColors.selectionBlue
              : RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Text(
          '$year',
          style: RenanceText.labelMono.copyWith(
            color: selected ? RenanceColors.ink : RenanceColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
