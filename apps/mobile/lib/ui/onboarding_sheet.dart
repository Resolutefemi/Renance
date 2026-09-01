/// Contextual profile modal — first thing after auth, non-dismissable.
/// Collects: full name, target institution, current grade level, active
/// examinations. Completion kicks the silent asset sync (founder spec).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'home_screen.dart';
import 'renance_logo.dart';
import 'theme.dart';

const List<String> kGradeLevels = <String>[
  'SS1', 'SS2', 'SS3',
  '100 Level', '200 Level', '300 Level', '400 Level',
  'Postgraduate',
];

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _institution = TextEditingController();
  String _gradeLevel = 'SS3';
  final Set<String> _exams = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _institution.dispose();
    super.dispose();
  }

  bool get _valid =>
      _fullName.text.trim().length >= 2 &&
      _institution.text.trim().length >= 2 &&
      _exams.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    final SessionStore session = context.read<SessionStore>();
    final SyncController sync = context.read<SyncController>();
    try {
      final Profile profile = await api.updateProfile(
        fullName: _fullName.text.trim(),
        institution: _institution.text.trim(),
        gradeLevel: _gradeLevel,
        exams: _exams.toList(),
      );
      final AppUser? user = session.user;
      if (user != null) {
        await session.save(
          session.token ?? '',
          AppUser(
            id: user.id,
            username: user.username,
            profileCompleted: profile.completed,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      // Silent background asset sync starts the moment preferences land.
      await sync.bootstrap(profileExams: profile.exams);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: RenanceColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RenanceColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  const RenanceMark(size: 44, busy: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Set up your desk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: RenanceColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'We use this to pull the right past questions '
                          'in the background.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Full name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: RenanceColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  hintText: 'e.g. Ariyo Oluwafemi',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Target institution',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: RenanceColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _institution,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.school_outlined, size: 20),
                  hintText: 'e.g. FUT Akure',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Current level',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: RenanceColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _gradeLevel,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.stairs_outlined, size: 20),
                ),
                items: kGradeLevels
                    .map((String g) => DropdownMenuItem<String>(
                          value: g,
                          child: Text(g),
                        ))
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _gradeLevel = v ?? 'SS3'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Active examinations',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: RenanceColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kExamOptions.map((String exam) {
                  final bool selected = _exams.contains(exam);
                  return FilterChip(
                    label: Text(exam),
                    selected: selected,
                    onSelected: (bool on) {
                      setState(() {
                        if (on) {
                          _exams.add(exam);
                        } else {
                          _exams.remove(exam);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                      color: RenanceColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_valid && !_busy) ? _submit : null,
                child: Text(_busy ? 'Saving…' : 'Done — start syncing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
