/// The account surfaces — the school app's account cut, Renance
/// edition.
///
/// AccountSheet: tapping the header avatar slides the bottom sheet up —
/// avatar, full name, @username, the X — with the menu (Dashboard,
/// Performance Analysis, Exam History, Saved Questions, Update
/// Questions, App Settings, Logout), exactly the way Myschool displays
/// the account at the top-right of home.
///
/// MyAccountScreen: the full "My Account" page — the white-card rows
/// (Performance Analysis, Exam History, Saved Questions, Downloads,
/// GPA Calculator, App Settings, Help) and the red Logout row, the
/// school app's My Account list in Renance's black & white.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'downloads_screen.dart';
import 'gpa_screen.dart';
import 'home_screen.dart' show AvatarCircle;
import 'performance_screen.dart';
import 'saved_questions.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'update_questions_screen.dart';

/// Opens the account bottom sheet from the home header avatar.
Future<void> showAccountSheet(
  BuildContext context, {
  required ValueChanged<int> onGoTab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => AccountSheet(onGoTab: onGoTab),
  );
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.onGoTab});

  /// Jumps the shell's tab (Dashboard / Exam History rows).
  final ValueChanged<int> onGoTab;

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final MeResult? me = student.me;
    final String name = me?.profile?.fullName.isNotEmpty == true
        ? me!.profile!.fullName
        : (me?.user.username ?? 'Scholar');
    final String username = me?.user.username ?? 'renance';

    return Container(
      decoration: BoxDecoration(
        color: context.cardLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.outlineLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // identity row — avatar + name + @username + X
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: <Widget>[
                  AvatarCircle(name: name, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RenanceText.bodyMedium.copyWith(
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@$username',
                          style: RenanceText.bodySecondary.copyWith(
                            fontSize: 14,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.cardLow,
                      ),
                      child:
                          Icon(Icons.close, size: 18, color: context.ink),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.outlineLight),
            // menu
            _SheetItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () {
                Navigator.of(context).pop();
                onGoTab(0);
              },
            ),
            _SheetItem(
              icon: Icons.insights,
              label: 'Performance Analysis',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const PerformanceScreen()));
              },
            ),
            _SheetItem(
              icon: Icons.history_edu,
              label: 'Exam History',
              onTap: () {
                Navigator.of(context).pop();
                onGoTab(2);
              },
            ),
            _SheetItem(
              icon: Icons.bookmark_border,
              label: 'Saved Questions',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SavedQuestionsScreen()));
              },
            ),
            _SheetItem(
              icon: Icons.sync,
              label: 'Update Questions',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const UpdateQuestionsScreen()));
              },
            ),
            _SheetItem(
              icon: Icons.settings_outlined,
              label: 'App Settings',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen()));
              },
            ),
            _SheetItem(
              icon: Icons.logout,
              label: 'Logout',
              destructive: true,
              onTap: () async {
                Navigator.of(context).pop();
                await context.read<SessionStore>().clear();
                if (!context.mounted) return;
                await Navigator.of(context)
                    .pushReplacementNamed('/login');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color tint =
        destructive ? context.error : context.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 21, color: tint),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: RenanceText.bodyMedium.copyWith(
                  fontSize: 15.5,
                  color: tint,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 19, color: context.outlineLight),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ my account

/// The My Account page — the school app's white-card menu list, every
/// row routing to a real Renance surface.
class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({super.key, this.onGoTab});

  /// Routed through when the account page is opened from the shell's
  /// profile tab (rows can then jump tabs).
  final ValueChanged<int>? onGoTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.outlineVariant),
                          color: context.card,
                        ),
                        child: Icon(Icons.arrow_back,
                            size: 19, color: context.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: <Widget>[
                  Text('My Account',
                      style: RenanceText.displayLg.copyWith(fontSize: 26)),
                  const SizedBox(height: 18),
                  _AccountGroup(rows: <_AccountRow>[
                    _AccountRow(
                      icon: Icons.bar_chart,
                      label: 'Performance Analysis',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PerformanceScreen()),
                      ),
                    ),
                    _AccountRow(
                      icon: Icons.history_edu,
                      label: 'Exam History',
                      onTap: () {
                        Navigator.of(context).pop();
                        onGoTab?.call(2);
                      },
                    ),
                    _AccountRow(
                      icon: Icons.bookmark_border,
                      label: 'Saved Questions',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SavedQuestionsScreen()),
                      ),
                    ),
                    _AccountRow(
                      icon: Icons.download_outlined,
                      label: 'Downloads',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const DownloadsScreen()),
                      ),
                    ),
                    _AccountRow(
                      icon: Icons.calculate_outlined,
                      label: 'GPA Calculator',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const GpaScreen()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _AccountGroup(rows: <_AccountRow>[
                    _AccountRow(
                      icon: Icons.sync,
                      label: 'Update Questions',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const UpdateQuestionsScreen()),
                      ),
                    ),
                    _AccountRow(
                      icon: Icons.settings_outlined,
                      label: 'App Settings',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    _AccountRow(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Renance',
                        applicationLegalese: 'Learn. Practice. Rise.',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _AccountGroup(rows: <_AccountRow>[
                    _AccountRow(
                      icon: Icons.logout,
                      label: 'Logout',
                      destructive: true,
                      onTap: () async {
                        await context.read<SessionStore>().clear();
                        if (!context.mounted) return;
                        await Navigator.of(context)
                            .pushReplacementNamed('/login');
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One white-card group of rows, the school app's My Account list.
class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.rows});

  final List<_AccountRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, color: context.outlineLight, indent: 64),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color tint = destructive ? context.error : context.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 21, color: tint),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: RenanceText.bodyMedium.copyWith(
                  fontSize: 15.5,
                  color: tint,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 19, color: context.outlineLight),
          ],
        ),
      ),
    );
  }
}
