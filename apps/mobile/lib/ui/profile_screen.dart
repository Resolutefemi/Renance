/// Profile tab, the Stitch profile_light screen, 1:1.
///
/// Header card: 80px avatar with the violet Lvl badge, display-md name,
/// @username + target chip, and the XP / Streak / Accuracy stat strip.
/// Then the content and system menu groups and the red sign-out card.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'downloads_screen.dart';
import 'home_screen.dart' show AvatarCircle;
import 'settings_screen.dart';
import 'theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onGoTab});

  final ValueChanged<int> onGoTab;

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final MeResult? me = student.me;
    final GamificationSummary? gam = student.gamification;

    final String name = me?.profile?.fullName.isNotEmpty == true
        ? me!.profile!.fullName
        : (me?.user.username ?? 'Scholar');
    final String username = me?.user.username ?? 'renance';
    final int level = gam?.state.level ?? 1;
    final int xp = gam?.state.totalXp ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 64 + 8, 16, 24),
      children: <Widget>[
        // Header card -----------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RenanceColors.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AvatarCircle(name: name, size: 80),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: RenanceColors.violet,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            'Lvl $level',
                            style: RenanceText.labelMono.copyWith(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RenanceText.displayMd.copyWith(fontSize: 22)),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text('@$username',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RenanceText.bodySecondary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: RenanceColors.selectionBlue,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                student.targetChip,
                                style: RenanceText.labelMono.copyWith(
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stat strip -------------------------------------------------
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RenanceColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Stat(
                          label: 'XP',
                          value: xp >= 1000
                              ? '${(xp / 1000).toStringAsFixed(1)}k'
                              : '$xp',
                          color: RenanceColors.violet),
                    ),
                    const _Divider(),
                    Expanded(
                      child: _Stat(
                        label: 'Streak',
                        value: '${gam?.state.currentStreak ?? 0}',
                        color: RenanceColors.ink,
                        flame: true,
                      ),
                    ),
                    const _Divider(),
                    Expanded(
                      child: _Stat(
                          label: 'Accuracy',
                          value: '${student.accuracyPct}%',
                          color: RenanceColors.emerald),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Menu group: content --------------------------------------------
        _MenuGroup(items: <_MenuItem>[
          _MenuItem(
            icon: Icons.auto_stories,
            tint: RenanceColors.violet,
            label: 'My Packs',
            onTap: () => onGoTab(1),
          ),
          _MenuItem(
            icon: Icons.download,
            tint: RenanceColors.violet,
            label: 'Downloads',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.workspace_premium,
            tint: RenanceColors.violet,
            label: 'Certificates',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'The certificate wallet is designed, it lands with the exam board.')));
            },
          ),
        ]),
        const SizedBox(height: 16),
        // Menu group: system ---------------------------------------------
        _MenuGroup(items: <_MenuItem>[
          _MenuItem(
            icon: Icons.settings,
            tint: RenanceColors.textSecondary,
            label: 'Settings',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.history_edu,
            tint: RenanceColors.textSecondary,
            label: 'My papers',
            onTap: () => onGoTab(2),
          ),
          _MenuItem(
            icon: Icons.help,
            tint: RenanceColors.textSecondary,
            label: 'Help & Support',
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Renance',
                applicationLegalese: 'Learn. Practice. Rise.',
              );
            },
          ),
        ]),
        const SizedBox(height: 16),
        // Sign out --------------------------------------------------------
        Container(
          decoration: BoxDecoration(
            color: RenanceColors.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await context.read<SessionStore>().clear();
              if (!context.mounted) return;
              await Navigator.of(context).pushReplacementNamed('/login');
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: RenanceColors.errorContainer,
                    ),
                    child:
                        const Icon(Icons.logout, color: RenanceColors.error),
                  ),
                  const SizedBox(width: 16),
                  const Text('Sign Out',
                      style: TextStyle(
                          color: RenanceColors.error,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One stat of the strip (XP violet / flame streak / accuracy emerald).
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.flame = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool flame;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label, style: RenanceText.caption),
        const SizedBox(height: 2),
        flame
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.local_fire_department,
                      size: 18, color: RenanceColors.amber),
                  const SizedBox(width: 2),
                  Text(value, style: RenanceText.statNumber.copyWith(color: color)),
                ],
              )
            : Text(value, style: RenanceText.statNumber.copyWith(color: color)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: RenanceColors.outlineLight.withValues(alpha: 0.3),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              Container(height: 1, color: RenanceColors.surfaceContainerHigh),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: RenanceColors.surfaceContainer,
                      ),
                      child: Icon(items[i].icon, size: 22, color: items[i].tint),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(items[i].label, style: RenanceText.bodyMedium),
                    ),
                    const Icon(Icons.chevron_right,
                        color: RenanceColors.outlineLight),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
