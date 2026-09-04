/// Onboarding, the Stitch onboarding_light + exam_target_light flow.
///
/// Step 1: "Your exam, your plan" intro carousel page.
/// Step 2: "What are you preparing for?", the target list (JAMB UTME /
///         WAEC / NECO / University course) + exam year chips.
/// Step 3: the scholar's details (name / institution / level) the server
///         requires, then the profile lands and the silent sync kicks.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import 'renance_logo.dart';
import 'theme.dart';

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  int _step = 0;

  String? _targetExam; // server value
  int? _targetYear;
  String _fullName = '';
  String _institution = '';
  String _gradeLevel = 'SS3';
  bool _busy = false;
  String? _error;

  static const List<_TargetOption> _targets = <_TargetOption>[
    _TargetOption(
      icon: Icons.school,
      title: 'JAMB UTME',
      subtitle: 'Nigerian university admissions',
      server: 'JAMB',
    ),
    _TargetOption(
      icon: Icons.workspace_premium,
      title: 'WAEC/WASSCE',
      subtitle: 'West African senior school certificate',
      server: 'WAEC',
    ),
    _TargetOption(
      icon: Icons.verified,
      title: 'NECO',
      subtitle: 'National examinations council',
      server: 'NECO',
    ),
    _TargetOption(
      icon: Icons.account_balance,
      title: 'University course',
      subtitle: 'Undergraduate semester exams',
      server: 'University Modules',
    ),
  ];

  static const List<int> _years = <int>[2026, 2027, 2028];

  bool get _detailsValid =>
      _fullName.trim().length >= 2 &&
      _institution.trim().length >= 2 &&
      _gradeLevel.isNotEmpty;

  Future<void> _submit() async {
    if (_targetExam == null || _targetYear == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.updateProfile(
        fullName: _fullName.trim(),
        institution: _institution.trim(),
        gradeLevel: _gradeLevel,
        exams: <String>[_targetExam!],
        targetYear: _targetYear,
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: switch (_step) {
                    0 => _buildIntro(context),
                    1 => _buildTarget(context),
                    _ => _buildDetails(context),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ step 1

  Widget _buildIntro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const RenanceMark(size: 56),
        const SizedBox(height: 20),
        const Text('Your exam, your plan', style: RenanceText.displayLg),
        const SizedBox(height: 8),
        Text(
          "Pick what you're preparing for and the whole app reshapes "
          'around it.',
          style: RenanceText.bodySecondary.copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ step 2

  Widget _buildTarget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('What are you preparing for?',
            style: RenanceText.displayMd),
        const SizedBox(height: 8),
        Text('Select your target exam to customize your learning OS.',
            style: RenanceText.bodySecondary),
        const SizedBox(height: 20),
        ..._targets.map((_TargetOption t) {
          final bool selected = _targetExam == t.server;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _targetExam = t.server),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? RenanceColors.selectionBlue
                      : RenanceColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Colors.black
                        : RenanceColors.outlineLight,
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.black
                            : RenanceColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(t.icon,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : RenanceColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.title,
                              style: RenanceText.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(t.subtitle,
                              style: RenanceText.caption),
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
        }),
        const SizedBox(height: 8),
        Text('EXAM YEAR', style: RenanceText.overline),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (final int y in _years) ...<Widget>[
              _YearChip(
                year: y,
                selected: _targetYear == y,
                onTap: () => setState(() => _targetYear = y),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: (_targetExam != null && _targetYear != null)
                    ? () => setState(() => _step = 2)
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ step 3

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Almost there', style: RenanceText.displayMd),
        const SizedBox(height: 8),
        Text(
          'Tell us who is studying so results, streaks and badges carry '
          'your name.',
          style: RenanceText.bodySecondary.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        const Text('Full name', style: RenanceText.labelMono),
        const SizedBox(height: 6),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline, size: 20),
            hintText: 'e.g. Ariyo Oluwafemi',
          ),
          onChanged: (String v) => _fullName = v,
        ),
        const SizedBox(height: 16),
        const Text('Institution', style: RenanceText.labelMono),
        const SizedBox(height: 6),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.school_outlined, size: 20),
            hintText: 'e.g. FUT Akure',
          ),
          onChanged: (String v) => _institution = v,
        ),
        const SizedBox(height: 16),
        const Text('Current level', style: RenanceText.labelMono),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _gradeLevel,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.stairs_outlined, size: 20),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'JSS1', child: Text('JSS1')),
            DropdownMenuItem<String>(value: 'JSS2', child: Text('JSS2')),
            DropdownMenuItem<String>(value: 'JSS3', child: Text('JSS3')),
            DropdownMenuItem<String>(value: 'SS1', child: Text('SS1')),
            DropdownMenuItem<String>(value: 'SS2', child: Text('SS2')),
            DropdownMenuItem<String>(value: 'SS3', child: Text('SS3')),
            DropdownMenuItem<String>(
                value: 'Undergraduate', child: Text('Undergraduate')),
            DropdownMenuItem<String>(
                value: 'Postgraduate', child: Text('Postgraduate')),
          ],
          onChanged: (String? v) => setState(() => _gradeLevel = v ?? 'SS3'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(_error!,
              style:
                  RenanceText.caption.copyWith(color: RenanceColors.error)),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step = 1),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: (_detailsValid && !_busy) ? _submit : null,
                child: Text(_busy ? 'Saving…' : 'Done, start syncing'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetOption {
  const _TargetOption({
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
