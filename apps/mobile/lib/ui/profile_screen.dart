/// Profile tab, the Stitch profile_light screen, 1:1.
///
/// Header card: 80px avatar with the ink Lvl badge, display-md name,
/// @username + target chip, and the XP / Streak / Accuracy stat strip.
/// Then the content and system menu groups and the red sign-out card.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../learn_controller.dart';
import '../learn_models.dart' show SocialConnections;
import '../models.dart';
import '../storage.dart';
import 'downloads_screen.dart';
import 'exam_history_screen.dart';
import 'focus_sheet.dart';
import 'gpa_screen.dart';
import 'home_screen.dart' show AvatarCircle;
import 'performance_screen.dart';
import 'saved_questions.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'shop_panel.dart';
import 'social_screens.dart';
import 'tactile.dart';
import 'theme.dart';
import 'university_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onGoTab,
    this.onFocusChanged,
  });

  final ValueChanged<int> onGoTab;

  /// Fired after the scholar switches their learning focus so the shell
  /// can re-sync packs for the new target exam.
  final VoidCallback? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final MeResult? me = student.me;
    final GamificationSummary? gam = student.gamification;

    final String name = me?.profile?.fullName.isNotEmpty == true
        ? me!.profile!.fullName
        : (me?.user.username ?? 'Scholar');
    final String username = me?.user.username ?? 'renance';
    final int xp = gam?.state.totalXp ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top +66, 16, 112),
      children: <Widget>[
        // Header card -----------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
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
                      // The web's pencil (founder directive 2026-10-17,
                      // mirrored 2026-10-20: it REPLACES the level
                      // badge): a 28px green key anchored hard to the
                      // avatar's bottom-right edge (no overhang), 2px
                      // card ring, edit glyph. Opens the identity
                      // editor - username + display name.
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _openIdentityEditor(context),
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.primary,
                              border: Border.all(color: context.card, width: 2),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: mixTowardBlack(context.primary, 0.68),
                                  offset: const Offset(0, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: MsIcon('edit',
                                size: 14, color: context.onPrimary, fill: true),
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
                                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.selectionBlue,
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
                  color: context.surfaceContainer,
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
                          // the web's XP readout: primary-ink
                          // (color-mix(primary 72%, black))
                          color: _primaryInk(context)),
                    ),
                    const _Divider(),
                    Expanded(
                      child: _Stat(
                        label: 'Streak',
                        value: '${gam?.state.currentStreak ?? 0}',
                        color: context.ink,
                        flame: true,
                      ),
                    ),
                    const _Divider(),
                    Expanded(
                      child: _Stat(
                        label: 'Gems',
                        value:
                            '${context.watch<LearnController>().gems}',
                        color: RenanceColors.macawDark,
                        gem: true,
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
        const SizedBox(height: 12),
        // Follow strip (the web's exact card, founder 2026-10-14/15):
        // followers and following read DIRECTLY on the profile - the
        // old "Followers and following ... View all" row is gone.
        // Tapping a half opens the lists on the management page.
        _FollowStrip(),
        const SizedBox(height: 12),
        // Invite friends (the web's referral card): the REN loop.
        if (me?.entitlement?.referralCode.isNotEmpty ?? false)
          _InviteCard(code: me!.entitlement!.referralCode),
        if (me?.entitlement?.referralCode.isNotEmpty ?? false)
          const SizedBox(height: 16),
        // Shop (web /profile#shop): the gem wallet + the item list.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // The web shop header: text-[20px] text-primary-ink -
                  // the seed-aware green ink, not a flat gray.
                  MsIcon('storefront', size: 20, color: context.primaryInk),
                  const SizedBox(width: 8),
                  Text('Shop', style: RenanceText.sectionTitle),
                ],
              ),
              const SizedBox(height: 14),
              const ShopPanel(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Learning focus: switch between JAMB / WAEC / NECO / tertiary.
        _FocusCard(
          chip: student.targetChip,
          onSwitch: () async {
            final StudentController fresh = context.read<StudentController>();
            final bool changed = await FocusSheet.show(context);
            if (!changed) return;
            await fresh.refresh();
            onFocusChanged?.call();
          },
        ),
        const SizedBox(height: 16),
        // My school: the ONLY place the picked school changes (founder
        // rule). Saving stores the pick AND the profile institution.
        _SchoolCard(onChanged: onFocusChanged),
        const SizedBox(height: 16),
        // Premium: the plans desk, the REN wallet and the blue tick.
        _MenuGroup(items: <_MenuItem>[
          _MenuItem(
            icon: 'verified',
            tint: const Color(0xFF1D9BF0),
            label: 'Renance Premium',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PremiumScreen()));
            },
          ),
        ]),
        const SizedBox(height: 16),
        // Menu group: content - 1:1 with the up-to-date web profile
        // (My Packs, GPA Calculator; Downloads stays as the mobile
        // affordance for the on-device pack library) ----------------------
        _MenuGroup(items: <_MenuItem>[
          _MenuItem(
            icon: 'history_edu',
            tint: context.ink,
            label: 'Exam History',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ExamHistoryScreen()));
            },
          ),
          _MenuItem(
            icon: 'insights',
            tint: context.ink,
            label: 'Performance Analysis',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PerformanceScreen()));
            },
          ),
          _MenuItem(
            icon: 'bookmark',
            tint: context.ink,
            label: 'Saved Questions',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SavedQuestionsScreen()));
            },
          ),
          _MenuItem(
            icon: 'auto_stories',
            tint: context.ink,
            label: 'My Packs',
            onTap: () => onGoTab(1),
          ),
          _MenuItem(
            icon: 'download',
            tint: context.ink,
            label: 'Downloads',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen()));
            },
          ),
          _MenuItem(
            icon: 'calculate',
            tint: context.ink,
            label: 'GPA Calculator',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const GpaScreen()));
            },
          ),
        ]),
        const SizedBox(height: 16),
        // Menu group: system ---------------------------------------------
        _MenuGroup(items: <_MenuItem>[
          _MenuItem(
            icon: 'settings',
            tint: context.textSecondary,
            label: 'Settings',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen()));
            },
          ),
          _MenuItem(
            icon: 'history_edu',
            tint: context.textSecondary,
            label: 'My papers',
            onTap: () => onGoTab(2),
          ),
          _MenuItem(
            icon: 'help',
            tint: context.textSecondary,
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
        Container(alignment: Alignment.center,
          
          decoration: BoxDecoration(
            color: context.card,
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
                  Container(alignment: Alignment.center,
                    
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.errorContainer,
                    ),
                    child:
                        MsIcon('logout', size: 24, color: context.error),
                  ),
                  const SizedBox(width: 16),
                  Text('Sign Out',
                      style: TextStyle(
                          color: context.error,
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

/// The identity editor behind the avatar pencil: username + display
/// name, the mobile twin of the web's openIdentityEditor sheet. Saving
/// PUTs /me/profile and refreshes the student so the header re-renders.
Future<void> _openIdentityEditor(BuildContext context) async {
  final StudentController student = context.read<StudentController>();
  final MeResult? me = student.me;
  final Profile? profile = me?.profile;
  final TextEditingController nameCtrl =
      TextEditingController(text: profile?.fullName ?? '');
  final TextEditingController userCtrl =
      TextEditingController(text: me?.user.username ?? '');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      bool busy = false;
      return StatefulBuilder(
        builder: (BuildContext sheetContext,
            void Function(void Function()) setSheet) {
          Future<void> save() async {
            final String fullName = nameCtrl.text.trim();
            final String username = userCtrl.text.trim();
            if (fullName.isEmpty || username.isEmpty || busy) return;
            setSheet(() => busy = true);
            try {
              await sheetContext.read<ApiClient>().updateProfile(
                    fullName: fullName,
                    institution: profile?.institution ?? '',
                    gradeLevel: profile?.gradeLevel ?? '',
                    exams: profile?.exams ?? const <String>[],
                    targetYear: profile?.targetYear,
                    username: username == (me?.user.username ?? '')
                        ? null
                        : username,
                  );
              await student.refresh();
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved')),
                );
              }
            } catch (_) {
              if (sheetContext.mounted) setSheet(() => busy = false);
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Could not save - check your connection')),
                );
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.paddingOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Edit your profile', style: RenanceText.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  'Your display name and @handle - the identity every '
                  'leaderboard, feed and arena seat carries.',
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: MsIcon('person', size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: MsIcon('alternate_email', size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: busy ? null : save,
                  height: 48,
                  child: Text(busy ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// The web's follow strip: followers and following read DIRECTLY on the
/// profile (founder 2026-10-14/15), two halves of one card - group key
/// + count + label | person_add key + count + label. Tapping a half
/// opens the management page (the mobile /profile/social).
class _FollowStrip extends StatefulWidget {
  const _FollowStrip();

  @override
  State<_FollowStrip> createState() => _FollowStripState();
}

class _FollowStripState extends State<_FollowStrip> {
  Future<SocialConnections>? _conns;

  @override
  void initState() {
    super.initState();
    _conns = context.read<ApiClient>().socialConnections();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<SocialConnections>(
        future: _conns,
        builder: (BuildContext context,
            AsyncSnapshot<SocialConnections> snap) {
          final int followers = snap.data?.followers.length ?? 0;
          final int following = snap.data?.following.length ?? 0;
          return Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SocialManagementScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        MsIcon('group', size: 19, color: context.primary),
                        const SizedBox(width: 8),
                        Text('$followers',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                            )),
                        const SizedBox(width: 6),
                        Text('Followers',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              // the web's my-3 w-px bg-outline-light/40 divider
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 1,
                color: context.outlineLight.withValues(alpha: 0.40),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SocialManagementScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        MsIcon('person_add',
                            size: 19, color: RenanceColors.macawDark),
                        const SizedBox(width: 8),
                        Text('$following',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.ink,
                            )),
                        const SizedBox(width: 6),
                        Text('Following',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The web's invite card: redeem key in the primary wash, the REN
/// invitation line, the mono referral code and the Copy link key
/// (clipboard + toast).
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primary.withValues(alpha: 0.15),
            ),
            child: MsIcon('redeem',
                size: 20, color: context.primaryInk, fill: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Invite friends, earn REN',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    )),
                const SizedBox(height: 2),
                Text(code,
                    style: RenanceText.labelMono.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: context.textSecondary,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TactileButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: 'https://renance.app/register/?ref=$code'),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link copied')),
                );
              }
            },
            expand: false,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            fontSize: 12,
            child: const Text('Copy link'),
          ),
        ],
      ),
    );
  }
}

/// Learning-focus card: shows the current target chip and opens the
/// focus sheet (exam_target_light) on tap.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.chip, required this.onSwitch});

  final String chip;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center,
      
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSwitch,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(alignment: Alignment.center,
                
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.selectionBlue,
                ),
                child: MsIcon('track_changes',
                    size: 22, color: context.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Learning focus', style: RenanceText.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Preparing for $chip. Tap to switch.',
                      style: RenanceText.caption.copyWith(color: context.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.selectionBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(chip,
                    style:
                        RenanceText.labelMono.copyWith(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              MsIcon('swap_horiz',
                  size: 24, color: context.outlineLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// One stat of the strip (XP ink / flame streak / accuracy emerald).
/// color-mix(in srgb, var(--color-primary) 72%, #000) - the web's
/// small-text primary ink.
Color _primaryInk(BuildContext context) {
  return mixTowardBlack(context.primary, 0.72);
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.flame = false,
    this.gem = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool flame;
  final bool gem;

  @override
  Widget build(BuildContext context) {
    Widget? adorn;
    if (flame) {
      adorn = const MsIcon('local_fire_department',
          size: 18, color: Color(0xFFF59E0B), fill: true);
    } else if (gem) {
      adorn = const GemIcon(size: 16);
    }
    return Column(
      children: <Widget>[
        Text(label, style: RenanceText.caption.copyWith(color: context.textSecondary)),
        const SizedBox(height: 2),
        if (adorn != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              adorn,
              const SizedBox(width: 4),
              Text(value, style: RenanceText.statNumber.copyWith(color: color)),
            ],
          )
        else
          Text(value, style: RenanceText.statNumber.copyWith(color: color)),
        const SizedBox(height: 2),
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
      color: context.outlineLight.withValues(alpha: 0.3),
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

  final String icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center,
      
      decoration: BoxDecoration(
        color: context.card,
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
              Container(height: 1, color: context.cardHigh),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(alignment: Alignment.center,
                      
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.surfaceContainer,
                      ),
                      child: MsIcon(items[i].icon, size: 22, color: items[i].tint),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(items[i].label, style: RenanceText.bodyMedium),
                    ),
                    MsIcon('chevron_right',
                        size: 24, color: context.outlineLight),
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

/// My school card: shows the picked school (stored pick first, then the
/// profile institution). ONLY the founder account can change it (founder
/// directive 2026-10-04): for everyone else the card is read-only - the
/// school is picked once on the School Desk and stays. The founder's
/// address is matched case-insensitively on the /me email.
class _SchoolCard extends StatelessWidget {
  const _SchoolCard({this.onChanged});

  final VoidCallback? onChanged;

  /// The only account allowed to switch schools from the profile page.
  static const String _founderEmail = 'ariyooluwafemi487@gmail.com';

  Future<void> _pick(BuildContext context) async {
    final SyncController sync = context.read<SyncController>();
    final StudentController student = context.read<StudentController>();
    final ApiClient api = context.read<ApiClient>();
    final SessionStore session = context.read<SessionStore>();

    final Map<String, List<UniCourse>> schools =
        universityCourses(sync.exams);
    // Available = schools with real semester course banks.
    final List<String> available = schools.keys
        .where((String s) => schools[s]!.any((UniCourse c) => !c.isPostUtme))
        .toList()
      ..sort();

    final String? pickedSlug = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: sheetContext.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Text('Which school are you in?',
                    style: RenanceText.displayMd),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  '${available.length} schools ship course banks. '
                  'This pick drives the School Desk.',
                  style: RenanceText.bodySecondary.copyWith(
                      color: sheetContext.textSecondary),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: available.length,
                  itemBuilder: (BuildContext context, int i) {
                    final String slug = available[i];
                    final (String short, String full) =
                        kUniversitySchools[slug] ??
                            (slug.toUpperCase(), slug);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TactileCard(
                        color: sheetContext.card,
                        radius: BorderRadius.circular(12),
                        padding: EdgeInsets.zero,
                        onTap: () => Navigator.of(sheetContext).pop(slug),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sheetContext.selectionBlue
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              short.length <= 5 ? short : short.substring(0, 4),
                              style: RenanceText.labelMono.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sheetContext.ink),
                            ),
                          ),
                          title: Text(short,
                              style: RenanceText.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(full,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RenanceText.caption.copyWith(
                                  color: sheetContext.textSecondary)),
                          trailing: MsIcon('chevron_right',
                              size: 24, color: sheetContext.outlineLight),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (pickedSlug == null) return;

    // Persist: the pick key (same one the website reads) AND the profile
    // institution, so the server record stays in step.
    final String fullName = kUniversitySchools[pickedSlug]?.$2 ?? pickedSlug;
    try {
      await session.prefs.setString(kSchoolPickKey, pickedSlug);
      final Profile? p = student.me?.profile;
      await api.updateProfile(
        fullName: p?.fullName ?? '',
        institution: fullName,
        gradeLevel: p?.gradeLevel ?? 'SS3',
        exams: p?.exams ?? const <String>['JAMB'],
        targetYear: p?.targetYear,
      );
      await student.refresh();
      onChanged?.call();
    } on ApiException {
      // Network/handler failure: the pick key already stored, the desk
      // still resolves; the profile record catches up on the next save.
    } on NetworkException {
      // Same soft handling: never strand the scholar on a dialog.
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final Set<String> banked = universityCourses(sync.exams).keys.toSet();
    final String? stored =
        context.read<SessionStore>().prefs.getString(kSchoolPickKey);
    final String current = (stored != null && banked.contains(stored)
            ? kUniversitySchools[stored]?.$2
            : null) ??
        (student.me?.profile?.institution.trim().isNotEmpty == true
            ? student.me!.profile!.institution
            : null) ??
        'Not set yet, tap to pick';
    // Founder-only school switching (2026-10-04): everyone else gets a
    // read-only card once a school is set - but the FIRST pick stays open
    // for everyone (a student with no school yet can still choose one).
    final bool founder =
        (student.me?.email ?? '').trim().toLowerCase() == _founderEmail;
    final bool hasSchool = stored != null && banked.contains(stored) ||
        (student.me?.profile?.institution.trim().isNotEmpty == true);
    final bool editable = founder || !hasSchool;

    return Container(alignment: Alignment.center,
      
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: editable ? () => _pick(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(alignment: Alignment.center,
                
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.selectionBlue,
                ),
                child: MsIcon('account_balance',
                    size: 22, color: context.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('My school', style: RenanceText.bodyMedium),
                    const SizedBox(height: 2),
                    Text(current,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RenanceText.caption
                            .copyWith(color: context.textSecondary)),
                  ],
                ),
              ),
              if (editable)
                MsIcon('edit', size: 20, color: context.outlineLight)
              else
                MsIcon('lock',
                    size: 18, color: context.outlineLight),
            ],
          ),
        ),
      ),
    );
  }
}
