/// Profile tab, the Stitch profile_light screen, 1:1.
///
/// Header card: 80px avatar with the ink Lvl badge, display-md name,
/// @username + target chip, and the XP / Streak / Accuracy stat strip.
/// Then the content and system menu groups and the red sign-out card.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../learn_controller.dart';
import '../learn_models.dart' show MyCourse, SocialAuthor, SocialConnections;
import '../models.dart';
import '../school_registry.dart';
import '../storage.dart';
import 'courses_screen.dart' show CoursesScreen;
import 'exam_history_screen.dart';
import 'face.dart';
import 'faq_screen.dart';
import 'focus_sheet.dart';
import 'gpa_screen.dart';
import 'performance_screen.dart';
import 'saved_questions.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'social_screens.dart';
import 'social_search_screen.dart';
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
                      GestureDetector(
                        // The identity art sheet (founder 2026-10-22):
                        // tapping the face swaps the photo / avatar.
                        onTap: () => _openIdentityArt(context),
                        child: RenanceFace(
                          name: name,
                          username: username,
                          avatar: me?.profile?.avatar,
                          photoUrl:
                              (me?.profile?.avatarPhoto?.isNotEmpty ?? false)
                                  ? context
                                      .read<ApiClient>()
                                      .profilePhotoUrl(
                                          me!.profile!.avatarPhoto!)
                                  : null,
                          size: 80,
                        ),
                      ),
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
        // Friend suggestions (founder 2026-10-22, the Duolingo strip):
        // follow-backs first, then active scholars, one per row with an
        // instant ADD chip - web parity with the profile page.
        const _SuggestionsStrip(),
        const SizedBox(height: 12),
        // Follow strip (the web's exact card, founder 2026-10-14/15):
        // followers and following read DIRECTLY on the profile - the
        // old "Followers and following ... View all" row is gone.
        // Tapping a half opens the lists on the management page.
        _FollowStrip(),
        const SizedBox(height: 12),
        // Invite friends (the web's referral card): 100 diamonds per
        // friend who joins with your code (founder 2026-10-22 - the
        // old 3-REN-coins loop is retired with the Ren points it fed).
        if (me?.entitlement?.referralCode.isNotEmpty ?? false)
          _InviteCard(code: me!.entitlement!.referralCode),
        if (me?.entitlement?.referralCode.isNotEmpty ?? false)
          const SizedBox(height: 16),
        // The shop left the profile on the founder's 2026-10-22 order:
        // it is a full page now (ShopScreen), opened from the home
        // grid's Storefront tile and the header gems chip.
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
        // My courses (founder 2026-10-22: the profile lists the courses
        // the scholar is taking, Duolingo's course roster but on the
        // Renance design language).
        const _MyCoursesCard(),
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
          // My Packs removed (founder 2026-10-22) - the course library
          // stays on the Courses tab; the profile menu no longer double-
          // lists it.
          // Downloads removed (founder 2026-10-21: the feature is
          // useless) - the profile menu row is gone with it.
          _MenuItem(
            icon: 'group_add',
            tint: context.ink,
            label: 'Find friends',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SocialSearchScreen()));
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
          // My papers removed (founder 2026-10-22) - exam history already
          // sits in the content group above.
          _MenuItem(
            icon: 'info',
            tint: context.textSecondary,
            label: 'About Renance',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen()));
            },
          ),
          _MenuItem(
            icon: 'help',
            tint: context.textSecondary,
            label: 'Help & Support',
            onTap: () {
              // Founder pass VIII: the real FAQ screen now answers this
              // row; the licenses page it used to open moved to the
              // FAQ's footer ('Open-source licenses').
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const FaqScreen()));
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
                  'leaderboard row and feed post carries.',
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: MsFieldIcon('person',
                        size: 20, color: context.textSecondary),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: MsFieldIcon('alternate_email',
                        size: 20, color: context.textSecondary),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
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
                Text('Invite friends, earn 100 diamonds',
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
              // Founder report 2026-10-21 ("that scattered text in the
              // profile page"): the chip pill is GONE - the web's
              // collapsed card (app/profile/page.tsx) carries NO pill;
              // the target name lives only in the caption. The pill was
              // an unbounded sibling, so at large system font scales it
              // devoured the row and crushed 'Learning focus' into one
              // letter per line. Expanded column + fixed siblings can
              // never stack again.
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

    final Set<String> banked = universityCourses(sync.exams).keys.toSet();

    final String? pickedSlug = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext sheetContext) => _SchoolPickerSheet(banked: banked),
    );
    if (pickedSlug == null) return;

    // Persist: the pick key (same one the website reads) AND the profile
    // institution, so the server record stays in step.
    final SchoolEntry? entry = await SchoolRegistry.bySlug(pickedSlug);
    final String fullName = entry?.name ??
        kUniversitySchools[pickedSlug]?.$2 ??
        pickedSlug;
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
    // The profile institution IS the school record (founder 2026-10-22:
    // the pick PUTs it), so it reads first; the banked map covers the
    // pre-registry picks.
    final String current =
        (student.me?.profile?.institution.trim().isNotEmpty == true
                ? student.me!.profile!.institution
                : null) ??
            (stored != null && banked.contains(stored)
                ? kUniversitySchools[stored]?.$2
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

/// The school picker sheet - the website's 1,108-school registry
/// (founder 2026-10-22: "there are up to 1000 schools a user can pick
/// on the website"). A live search box over the bundled dataset; live
/// course-bank schools wear a small desk chip so the scholar knows the
/// desk ships real courses for them.
class _SchoolPickerSheet extends StatefulWidget {
  const _SchoolPickerSheet({required this.banked});

  /// Slugs with real semester course banks (the desk chip).
  final Set<String> banked;

  @override
  State<_SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<_SchoolPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<SchoolEntry> _results = const <SchoolEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SchoolRegistry.all().then((List<SchoolEntry> all) {
      if (!mounted) return;
      setState(() {
        _results = all.take(60).toList();
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    SchoolRegistry.search(q, limit: 60).then((List<SchoolEntry> list) {
      if (!mounted) return;
      setState(() => _results = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: context.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child:
                  Text('Which school are you in?', style: RenanceText.displayMd),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                '1,108 schools. This pick drives the School Desk and shows '
                'on your profile.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: _onQuery,
                decoration: InputDecoration(
                  hintText: 'Search by name, code or state',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  isDense: true,
                  filled: true,
                  fillColor: context.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _results.length,
                      itemBuilder: (BuildContext context, int i) {
                        final SchoolEntry s = _results[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TactileCard(
                            color: context.card,
                            radius: BorderRadius.circular(12),
                            padding: EdgeInsets.zero,
                            onTap: () =>
                                Navigator.of(context).pop(s.slug),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              leading: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: context.selectionBlue
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  s.short.length <= 5
                                      ? s.short
                                      : s.short.substring(0, 4),
                                  style: RenanceText.labelMono.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.ink),
                                ),
                              ),
                              title: Text(s.short,
                                  style: RenanceText.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w600)),
                              subtitle: Text(s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RenanceText.caption
                                      .copyWith(color: context.textSecondary)),
                              trailing: widget.banked.contains(s.slug)
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: context.selectionBlue,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text('COURSES',
                                          style: RenanceText.labelMono
                                              .copyWith(fontSize: 10)),
                                    )
                                  : MsIcon('chevron_right',
                                      size: 24,
                                      color: context.outlineLight),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friend suggestions (founder 2026-10-22, the Duolingo strip on the
/// profile): follow-backs first, then active scholars. Rows flip their
/// own ADD chip instantly; the strip hides itself entirely when the
/// server has nobody to suggest.
class _SuggestionsStrip extends StatefulWidget {
  const _SuggestionsStrip();

  @override
  State<_SuggestionsStrip> createState() => _SuggestionsStripState();
}

class _SuggestionsStripState extends State<_SuggestionsStrip> {
  List<SocialAuthor>? _people; // null = loading, empty = hide
  final Map<String, bool> _edges = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<SocialAuthor> users = await api.socialSuggestions(limit: 8);
      if (!mounted) return;
      setState(() => _people = users);
    } on ApiException {
      if (!mounted) return;
      setState(() => _people = const <SocialAuthor>[]);
    } on NetworkException {
      if (!mounted) return;
      setState(() => _people = const <SocialAuthor>[]);
    }
  }

  Future<void> _toggle(SocialAuthor u) async {
    final ApiClient api = context.read<ApiClient>();
    final bool was = _edges[u.username] ?? false;
    setState(() => _edges[u.username] = !was);
    try {
      final bool following = await api.socialFollow(u.username);
      if (!mounted) return;
      setState(() => _edges[u.username] = following);
    } catch (_) {
      if (mounted) setState(() => _edges[u.username] = was);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SocialAuthor>? people = _people;
    if (people == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    // The strip vanishes when nobody is suggestible (new platforms,
    // everyone followed) - an empty rail is never shipped.
    if (people.isEmpty) return const SizedBox.shrink();

    return Container(
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
              MsIcon('diversity_3', size: 20, color: context.primaryInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Friend suggestions',
                    style: RenanceText.sectionTitle),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SocialSearchScreen())),
                child: Text('See all',
                    style: RenanceText.labelMono.copyWith(
                        fontSize: 12, color: context.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...people.map((SocialAuthor u) {
            final bool following = _edges[u.username] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () =>
                        PublicProfileScreen.push(context, u.username),
                    child: Row(
                      children: <Widget>[
                        RenanceFace(
                          name: u.name,
                          username: u.username,
                          avatar: u.avatar,
                          photoUrl: u.photo == null
                              ? null
                              : context
                                  .read<ApiClient>()
                                  .profilePhotoUrl(u.photo!),
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.42,
                              child: Text(u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RenanceText.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 2),
                            Text('@${u.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _toggle(u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            following ? context.surfaceContainer : context.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        following ? 'FOLLOWING' : 'ADD',
                        style: RenanceText.labelMono.copyWith(
                          fontSize: 12,
                          color: following
                              ? context.textSecondary
                              : context.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// My courses (founder 2026-10-22): the profile lists the courses the
/// scholar is taking with live progress, Duolingo's roster but on the
/// Renance card language. Empty state is a gentle CTA, not a void.
class _MyCoursesCard extends StatefulWidget {
  const _MyCoursesCard();

  @override
  State<_MyCoursesCard> createState() => _MyCoursesCardState();
}

class _MyCoursesCardState extends State<_MyCoursesCard> {
  List<MyCourse>? _courses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<MyCourse> courses = await api.learnMyCourses();
      if (!mounted) return;
      setState(() => _courses = courses);
    } catch (_) {
      if (!mounted) return;
      setState(() => _courses = const <MyCourse>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MyCourse>? courses = _courses;
    if (courses == null) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final List<MyCourse> active =
        courses.where((MyCourse c) => c.topicCount > 0).toList();
    return Container(
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
              MsIcon('menu_book', size: 20, color: context.primaryInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text('My courses', style: RenanceText.sectionTitle),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(
                        builder: (_) => const CoursesScreen())),
                child: Text('Manage',
                    style: RenanceText.labelMono.copyWith(
                        fontSize: 12, color: context.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            Text(
              'No course on your desk yet - open the Courses tab to enroll.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else
            ...active.map((MyCourse c) {
              final int pct = c.topicCount <= 0
                  ? 0
                  : (c.completedTopics * 100 / c.topicCount)
                      .clamp(0, 100)
                      .round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.selectionBlue
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: MsIcon('school',
                              size: 20, color: context.primaryInk),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RenanceText.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  '${c.completedTopics}/${c.topicCount} topics '
                                  '- $pct%',
                                  style: RenanceText.caption.copyWith(
                                      color: context.textSecondary)),
                            ],
                          ),
                        ),
                        Text('$pct%',
                            style: RenanceText.labelMono.copyWith(
                                fontSize: 13, color: context.primaryInk)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: context.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            context.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// The identity art sheet (founder 2026-10-22: "users can also choose
/// to add avatars instead of pictures"): upload a photo to the R2
/// profile-picture folder, pick one of the 50 baked-in avatars, or
/// clear the photo back to the initial letter. The one-wins rule is
/// the server's: an upload clears the avatar key and a pick clears the
/// photo, so the header can never show two identities at once.
Future<void> _openIdentityArt(BuildContext context) async {
  final StudentController student = context.read<StudentController>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.pageBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (BuildContext sheetContext) => const _IdentityArtSheet(),
  );
  // The sheet mutates the server record; a refresh re-renders the
  // header (and every face in the app on the next /me).
  if (!context.mounted) return;
  final StudentController fresh = context.read<StudentController>();
  if (fresh != student) return;
  await fresh.refresh();
}

class _IdentityArtSheet extends StatefulWidget {
  const _IdentityArtSheet();

  @override
  State<_IdentityArtSheet> createState() => _IdentityArtSheetState();
}

class _IdentityArtSheetState extends State<_IdentityArtSheet> {
  bool _busy = false;
  String _error = '';
  final List<String> _keys = List<String>.generate(
      50, (int i) => 'avatar-${(i + 1).toString().padLeft(2, '0')}');

  Future<void> _upload() async {
    if (_busy) return;
    final ApiClient api = context.read<ApiClient>();
    final StudentController student = context.read<StudentController>();
    final XTypeGroup images = const XTypeGroup(
        label: 'Photo',
        extensions: <String>['png', 'jpg', 'jpeg', 'webp']);
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[images]);
    if (file == null) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final List<int> bytes = await file.readAsBytes();
      if (bytes.length > (5 << 20)) {
        throw ApiException(413, 'bad_upload',
            'The photo must be 5MB or smaller.');
      }
      await api.uploadAvatarPhoto(bytes: bytes, filename: file.name);
      await student.refresh();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The photo could not be uploaded. Try again.';
      });
    }
  }

  Future<void> _pickAvatar(String key) async {
    if (_busy) return;
    final ApiClient api = context.read<ApiClient>();
    final StudentController student = context.read<StudentController>();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await api.setAvatarKey(key);
      await student.refresh();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop();
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

  Future<void> _removePhoto() async {
    if (_busy) return;
    final ApiClient api = context.read<ApiClient>();
    final StudentController student = context.read<StudentController>();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await api.deleteAvatarPhoto();
      await student.refresh();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The photo could not be removed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final Profile? profile = student.me?.profile;
    final bool hasPhoto =
        (profile?.avatarPhoto?.isNotEmpty ?? false);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: context.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text('Profile picture', style: RenanceText.displayMd),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Upload a photo or pick an avatar. Your photo wins while '
                'it is set.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(_error,
                    style: RenanceText.caption
                        .copyWith(color: context.error)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      onTap: _upload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: context.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.onPrimary))
                            : Text('Upload photo',
                                style: RenanceText.bodyMedium.copyWith(
                                    color: context.onPrimary,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  if (hasPhoto) ...<Widget>[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MsIcon('delete', size: 20, color: context.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('OR CHOOSE AN AVATAR',
                  style: RenanceText.labelMono.copyWith(
                      fontSize: 11, color: context.textSecondary)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _keys.length,
                itemBuilder: (BuildContext context, int i) {
                  final String key = _keys[i];
                  final bool selected = profile?.avatar == key;
                  return GestureDetector(
                    onTap: _busy ? null : () => _pickAvatar(key),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                width: 3, color: context.primary)
                            : null,
                      ),
                      child: SvgPicture.asset(avatarAsset(key),
                          fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
