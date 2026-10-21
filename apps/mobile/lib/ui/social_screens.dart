/// The social layer's screens - the Flutter twins of the web's
/// app/profile/view + app/profile/social: the public profile (header,
/// stat strip, Taking course progress, posts), the followers/following
/// management page, and the shared FollowChip / SocialAvatar atoms.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_models.dart';
import 'blue_tick.dart';
import 'courses_screen.dart' show LearnPageBar;
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

// ---------------------------------------------------------------- atoms

/// The deterministic-colour initials avatar every social surface uses.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.username,
    required this.name,
    this.size = 40,
  });

  final String username;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String seed = username.isNotEmpty ? username : name;
    final String initial = seed.isNotEmpty ? seed[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColorFor(seed),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The Follow / Following pill with its optimistic flip.
class FollowChip extends StatelessWidget {
  const FollowChip({super.key, required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: following ? Colors.transparent : context.primary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: following ? context.outlineVariant : context.primary,
            width: 2,
          ),
          boxShadow: following
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: mixTowardBlack(context.primary, 0.68),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: following ? context.ink : context.onPrimary,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- public profile

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.username});

  final String username;

  static Future<void> push(BuildContext context, String username) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(username: username),
      ),
    );
  }

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _loading = true;
  bool _notFound = false;
  PublicProfile? _profile;
  List<SocialPost> _posts = <SocialPost>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final (PublicProfile profile, List<SocialPost> posts) =
          await api.socialPublicProfile(widget.username);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts;
        _loading = false;
      });
    } on ApiException {
      if (mounted) setState(() { _loading = false; _notFound = true; });
    } on NetworkException {
      if (mounted) setState(() { _loading = false; _notFound = true; });
    }
  }

  Future<void> _toggleFollow() async {
    final PublicProfile? p = _profile;
    if (p == null) return;
    final ApiClient api = context.read<ApiClient>();
    final bool was = p.isFollowing;
    setState(() => _profile = _copyWith(isFollowing: !was));
    try {
      final bool following = await api.socialFollow(p.username);
      if (!mounted) return;
      setState(() => _profile = _copyWith(isFollowing: following));
    } catch (_) {
      if (mounted) setState(() => _profile = _copyWith(isFollowing: was));
    }
  }

  PublicProfile _copyWith({bool? isFollowing}) {
    // Rebuild the immutable model with the follow edge (and its count
    // delta) applied.
    final bool next = isFollowing ?? _profile!.isFollowing;
    final int delta = (next ? 1 : 0) - (_profile!.isFollowing ? 1 : 0);
    return PublicProfile(
      id: _profile!.id,
      username: _profile!.username,
      name: _profile!.name,
      premium: _profile!.premium,
      avatar: _profile!.avatar,
      level: _profile!.level,
      xp: _profile!.xp,
      streak: _profile!.streak,
      league: _profile!.league,
      topicsDone: _profile!.topicsDone,
      perfectCount: _profile!.perfectCount,
      followers: _profile!.followers + delta,
      following: _profile!.following,
      isFollowing: isFollowing ?? _profile!.isFollowing,
      followsYou: _profile!.followsYou,
      isSelf: _profile!.isSelf,
      joinedMs: _profile!.joinedMs,
      courses: _profile!.courses,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The web's route: PageBar titled with the scholar's NAME (never
    // the raw @handle) - components/page-bar.tsx + the 2px rule.
    return Scaffold(
      backgroundColor: context.pageBg,
      body: Column(
        children: <Widget>[
          LearnPageBar(title: _profile?.name ?? 'Profile'),
          Expanded(
            child: _loading
                ? const Center(child: RenanceMark(size: 40, busy: true))
                : _notFound
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            MsIcon('person_off',
                                size: 38, color: context.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'This scholar could not be found.',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TactileButton(
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              expand: false,
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Text('Back to the desk'),
                            ),
                          ],
                        ),
                      )
                    : _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final PublicProfile p = _profile!;
    final DateTime joined =
        DateTime.fromMillisecondsSinceEpoch(p.joinedMs);
    // The web's toLocaleDateString(undefined, {month:'long',...}).
    final String joinedLabel = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ][joined.month - 1];
    // The web's learn-tile recipe: 2px outline, 4px extruded ledge.
    BoxDecoration tile(BuildContext context) => BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.outlineVariant, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.outlineVariant.withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        // Header card - one learn-tile, everything centred inside.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: tile(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // the 80px avatar (primary face, ink initial) with the
              // Lvl badge anchored at its bottom-right edge.
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.primary,
                    ),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: context.onPrimary,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.card, width: 2),
                      ),
                      child: Text(
                        'Lvl ${p.level}',
                        style: RenanceText.labelMono.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: context.ink,
                      ),
                    ),
                  ),
                  if (p.premium) ...<Widget>[
                    const SizedBox(width: 6),
                    const BlueTickIcon(size: 17),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@${p.username}',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  LeagueBadge(league: p.league, size: 34),
                  const SizedBox(width: 8),
                  Text(
                    '${p.league} League',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // The web's key-btn follow key: rectangular, Following
              // flips to the muted ink face, follow-back aware.
              if (!p.isSelf)
                TactileButton(
                  onPressed: _toggleFollow,
                  expand: false,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  fontSize: 14,
                  face: p.isFollowing ? context.textSecondary : context.primary,
                  onFace: p.isFollowing ? Colors.white : context.onPrimary,
                  edge: p.isFollowing
                      ? mixTowardBlack(context.textSecondary, 0.62)
                      : mixTowardBlack(context.primary, 0.68),
                  child: Text(
                    p.isFollowing
                        ? 'Following \u2713'
                        : (p.followsYou ? 'Follow back' : 'Follow'),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'On Renance since $joinedLabel ${joined.year}',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stat strip card: four 11px-uppercase-label / 19px-black columns
        // with hairline dividers, then the topics/perfect pill inside.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: tile(context),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _PublicStat(label: 'Followers', value: '${p.followers}'),
                  _statDivider(context),
                  _PublicStat(label: 'Following', value: '${p.following}'),
                  _statDivider(context),
                  _PublicStat(
                    label: 'Streak',
                    value: '${p.streak}',
                    amber: true,
                  ),
                  _statDivider(context),
                  _PublicStat(label: 'XP', value: '${p.xp}'),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('${p.topicsDone} topics done',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        )),
                    Text('${p.perfectCount} perfect runs',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Taking - one card, the uppercase header inside.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: tile(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'TAKING',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (p.courses.isEmpty)
                Text(
                  'No courses on their desk yet.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondary,
                  ),
                )
              else
                for (final CoursePulse c in p.courses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${c.body} \u00b7 ${c.done}/${c.topics}',
                              style: RenanceText.labelMono.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LearnProgressBar(
                          value: c.percent / 100,
                          height: 8,
                          gold: c.percent >= 100,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Their posts - uppercase section header, dashed empty card.
        Text(
          'POSTS',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.outlineVariant,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Text(
              'Nothing posted yet.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          )
        else
          for (final SocialPost post in _posts)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.outlineVariant, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: context.outlineVariant.withValues(alpha: 0.55),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        post.body,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: context.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: context.outlineVariant.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: <Widget>[
                          MsIcon(
                            post.likedByMe ? 'favorite' : 'favorite_border',
                            size: 16,
                            color: post.likedByMe
                                ? RenanceColors.cardinal
                                : context.textSecondary,
                            fill: post.likedByMe,
                          ),
                          const SizedBox(width: 4),
                          Text('${post.likes}',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              )),
                          const SizedBox(width: 16),
                          MsIcon('chat_bubble',
                              size: 16, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text('${post.comments}',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              )),
                          const Spacer(),
                          Text(
                            timeAgo(post.createdAtMs),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// the stat strip's w-px bg-outline-variant/40 divider
  Widget _statDivider(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: context.outlineVariant.withValues(alpha: 0.40),
      );
}

/// One stat column of the public profile strip: the 11px bold uppercase
/// label over the 19px black value (streak wears the amber flame).
class _PublicStat extends StatelessWidget {
  const _PublicStat({
    required this.label,
    required this.value,
    this.amber = false,
  });

  final String label;
  final String value;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (amber) ...<Widget>[
                const MsIcon('local_fire_department',
                    size: 15, color: Color(0xFFF59E0B), fill: true),
                const SizedBox(width: 3),
              ],
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: amber ? const Color(0xFFF59E0B) : context.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- social management

/// "Your people" - the followers / following management page.
class SocialManagementScreen extends StatefulWidget {
  const SocialManagementScreen({super.key});

  @override
  State<SocialManagementScreen> createState() => _SocialManagementScreenState();
}

class _SocialManagementScreenState extends State<SocialManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  SocialConnections? _conns;
  // Local follow-edge mirror (FollowRow is immutable).
  final Map<String, bool> _followState = <String, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final SocialConnections conns = await api.socialConnections();
      if (!mounted) return;
      setState(() {
        _conns = conns;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  bool _isFollowing(FollowRow row) =>
      _followState[row.username] ?? row.following;

  Future<void> _toggle(FollowRow row) async {
    final ApiClient api = context.read<ApiClient>();
    final bool was = _isFollowing(row);
    setState(() => _followState[row.username] = !was);
    try {
      final bool following = await api.socialFollow(row.username);
      if (!mounted) return;
      setState(() => _followState[row.username] = following);
    } catch (_) {
      if (mounted) setState(() => _followState[row.username] = was);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: Column(
        children: <Widget>[
          // the web /profile/social PageBar: "Your people".
          LearnPageBar(title: 'Your people'),
          TabBar(
            controller: _tabs,
            labelColor: context.ink,
            unselectedLabelColor: context.textSecondary,
            indicatorColor: context.primary,
            labelStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
            ),
            tabs: <Widget>[
              Tab(
                icon: const MsIcon('group', size: 18),
                text: 'Followers (${_conns?.followers.length ?? 0})',
              ),
              Tab(
                icon: const MsIcon('person_add', size: 18),
                text: 'Following (${_conns?.following.length ?? 0})',
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: RenanceMark(size: 40, busy: true))
                : _error != null
                    ? Center(
                        child: Text(
                          'Your people are syncing…',
                          style: RenanceText.bodySecondary
                              .copyWith(color: context.textSecondary),
                        ),
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: <Widget>[
                          _FollowList(
                            rows: _conns?.followers ?? <FollowRow>[],
                            emptyTitle: 'No followers yet',
                            emptyBody: 'Post your wins on the feed and share '
                                'your invite link - they will come.',
                            onToggle: _toggle,
                            followState: _followState,
                          ),
                          _FollowList(
                            rows: _conns?.following ?? <FollowRow>[],
                            emptyTitle: 'Not following anyone yet',
                            emptyBody: 'Tap any name on the feed, the boards or '
                                'the arena and follow them from their profile.',
                            onToggle: _toggle,
                            followState: _followState,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _FollowList extends StatelessWidget {
  const _FollowList({
    required this.rows,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onToggle,
    required this.followState,
  });

  final List<FollowRow> rows;
  final String emptyTitle;
  final String emptyBody;
  final Future<void> Function(FollowRow) onToggle;
  final Map<String, bool> followState;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptyBody,
                textAlign: TextAlign.center,
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int i) {
        final FollowRow row = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.outlineVariant, width: 2),
            ),
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () =>
                      PublicProfileScreen.push(context, row.username),
                  child: SocialAvatar(
                      username: row.username, name: row.name, size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        PublicProfileScreen.push(context, row.username),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (row.premium) ...<Widget>[
                              const SizedBox(width: 5),
                              const BlueTickIcon(size: 13),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Text(
                              '@${row.username}',
                              style: RenanceText.caption.copyWith(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                            if (row.followsYou) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.surfaceContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Follows you',
                                  style: RenanceText.caption.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                FollowChip(
                  following: followState[row.username] ?? row.following,
                  onTap: () => onToggle(row),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
