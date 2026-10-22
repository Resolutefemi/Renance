/// The Feed - the Flutter twin of the web's app/feed: the Duolingo-style
/// milestone post feed with tinted milestone rails, likes, inline
/// comment threads with drafts, follow chips, native sharing and
/// infinite scroll pagination (25 per page, 400px lookahead).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api_client.dart';
import '../learn_models.dart';
import 'blue_tick.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'social_screens.dart';
import 'tactile.dart';
import 'theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

/// One feed post with its local mutable engagement state (the server
/// model is immutable; likes/comments update in place here).
class _FeedPost {
  _FeedPost(this.post)
      : likes = post.likes,
        likedByMe = post.likedByMe,
        comments = post.comments;

  final SocialPost post;
  int likes;
  bool likedByMe;
  int comments;
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scroll = ScrollController();
  final List<_FeedPost> _posts = <_FeedPost>[];
  final Map<int, bool> _following = <int, bool>{};
  final Map<int, List<SocialComment>> _comments = <int, List<SocialComment>>{};
  final Map<int, bool> _expanded = <int, bool>{};
  // Comment drafts survive collapse (the web keeps the box state).
  final Map<int, TextEditingController> _drafts = <int, TextEditingController>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _poll?.cancel();
    for (final TextEditingController c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<SocialPost> posts = await api.socialFeed(limit: 25);
      final List<_FeedPost> wrapped =
          posts.map((SocialPost p) => _FeedPost(p)).toList();
      SocialConnections conns;
      try {
        conns = await api.socialConnections();
      } catch (_) {
        conns = const SocialConnections(
          followers: <FollowRow>[],
          following: <FollowRow>[],
        );
      }
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(wrapped);
        // Seed follow state from the connection graph by username.
        _following.clear();
        for (final _FeedPost fp in _posts) {
          final String? uname = fp.post.author?.username;
          if (uname != null &&
              conns.following.any((FollowRow f) => f.username == uname)) {
            _following[fp.post.id] = true;
          }
        }
        _exhausted = posts.length < 25;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    final ApiClient api = context.read<ApiClient>();
    try {
      final int before = _posts.last.post.id;
      final List<SocialPost> more =
          await api.socialFeed(before: before, limit: 25);
      if (!mounted) return;
      setState(() {
        // Dedup by id (the web's guard against server reordering).
        for (final SocialPost p in more) {
          if (!_posts.any((_FeedPost x) => x.post.id == p.id)) {
            _posts.add(_FeedPost(p));
          }
        }
        if (more.length < 25) _exhausted = true;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _like(_FeedPost fp) async {
    final ApiClient api = context.read<ApiClient>();
    // Optimistic flip.
    setState(() {
      fp.likes += fp.likedByMe ? -1 : 1;
      fp.likedByMe = !fp.likedByMe;
    });
    try {
      final (int likes, bool liked) = await api.socialLike(fp.post.id);
      if (!mounted) return;
      setState(() {
        fp.likes = likes;
        fp.likedByMe = liked;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        fp.likes += fp.likedByMe ? -1 : 1;
        fp.likedByMe = !fp.likedByMe;
      });
    }
  }

  Future<void> _toggleComments(_FeedPost fp) async {
    final int id = fp.post.id;
    final bool open = !(_expanded[id] ?? false);
    setState(() => _expanded[id] = open);
    if (!open) return;
    if (_comments.containsKey(id)) return;
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<SocialComment> comments = await api.socialComments(id);
      if (!mounted) return;
      setState(() => _comments[id] = comments);
    } catch (_) {
      if (mounted) setState(() => _comments[id] = <SocialComment>[]);
    }
  }

  Future<void> _sendComment(_FeedPost fp) async {
    final TextEditingController? draft = _drafts[fp.post.id];
    final String body = draft?.text.trim() ?? '';
    if (body.isEmpty || body.length > 300) return;
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<SocialComment> comments =
          await api.socialAddComment(fp.post.id, body);
      if (!mounted) return;
      setState(() {
        _comments[fp.post.id] = comments;
        _postById(fp.post.id)?.comments = comments.length;
      });
      draft?.clear();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not comment - ${e.message}')));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not comment - ${e.message}')));
      }
    }
  }

  Future<void> _follow(_FeedPost fp) async {
    final String? username = fp.post.author?.username;
    if (username == null || username.isEmpty) return;
    final ApiClient api = context.read<ApiClient>();
    final bool was = _following[fp.post.id] ?? false;
    setState(() => _following[fp.post.id] = !was);
    try {
      final bool following = await api.socialFollow(username);
      if (!mounted) return;
      setState(() => _following[fp.post.id] = following);
    } catch (_) {
      if (mounted) setState(() => _following[fp.post.id] = was);
    }
  }

  _FeedPost? _postById(int id) {
    for (final _FeedPost fp in _posts) {
      if (fp.post.id == id) return fp;
    }
    return null;
  }

  Future<void> _share(_FeedPost fp) async {
    final String name = fp.post.author?.name ?? 'A scholar';
    final String text = '$name ${fp.post.body} - via Renance';
    try {
      await Share.share(text, subject: 'Renance');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied - share it anywhere')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top +66),
        Expanded(
          child: _loading
              ? const Center(child: RenanceMark(size: 40, busy: true))
              : _error != null
                  ? _FeedSyncing(message: _error!)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _posts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(28),
                              children: <Widget>[
                                MsIcon('newspaper',
                                    size: 44, color: context.textSecondary),
                                const SizedBox(height: 12),
                                const Text(
                                  'The feed is waiting for its first story',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Streaks, big scores, league promotions and '
                                  'arena wins show up here automatically as you '
                                  'study.',
                                  textAlign: TextAlign.center,
                                  style: RenanceText.bodySecondary
                                      .copyWith(color: context.textSecondary),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                              itemCount: _posts.length + 1,
                              itemBuilder: (BuildContext context, int i) {
                                if (i == _posts.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Center(
                                      child: _loadingMore
                                          ? const RenanceMark(size: 26, busy: true)
                                          : const SizedBox.shrink(),
                                    ),
                                  );
                                }
                                final _FeedPost fp = _posts[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PostCard(
                                    fp: fp,
                                    following: _following[fp.post.id] ?? false,
                                    comments: _comments[fp.post.id],
                                    expanded: _expanded[fp.post.id] ?? false,
                                    draft: _draftFor(fp.post.id),
                                    onLike: () => _like(fp),
                                    onComments: () => _toggleComments(fp),
                                    onShare: () => _share(fp),
                                    onFollow: () => _follow(fp),
                                    onSendComment: () => _sendComment(fp),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  TextEditingController _draftFor(int postId) {
    return _drafts.putIfAbsent(
      postId,
      () => TextEditingController(),
    );
  }
}

class _FeedSyncing extends StatelessWidget {
  const _FeedSyncing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const RenanceMark(size: 40, busy: true),
            const SizedBox(height: 14),
            Text('Finding your feed…', style: RenanceText.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// One feed post card: milestone rail + author row + body + actions +
/// the inline comment thread.
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.fp,
    required this.following,
    required this.comments,
    required this.expanded,
    required this.draft,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onFollow,
    required this.onSendComment,
  });

  final _FeedPost fp;
  final bool following;
  final List<SocialComment>? comments;
  final bool expanded;
  final TextEditingController draft;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onFollow;
  final VoidCallback onSendComment;

  SocialPost get post => fp.post;

  (String, Color, String) get _rail {
    final SocialMeta? m = post.meta;
    if (m == null) {
      return ('MILESTONE', const Color(0xFF10DA11), 'military_tech');
    }
    if (m.streak != null) {
      return ('STREAK', const Color(0xFFFF9600), 'local_fire_department');
    }
    if (m.league != null && m.league!.isNotEmpty) {
      return ('${m.league!.toUpperCase()} LEAGUE', const Color(0xFFCE82FF), 'trophy');
    }
    if (m.exam != null && m.exam!.isNotEmpty) {
      return ('${m.exam!.toUpperCase()} SCORE', const Color(0xFF1CB0F6), 'target');
    }
    if (m.matchId != null) {
      return ('ARENA', const Color(0xFFFF4B4B), 'swords');
    }
    return ('MILESTONE', const Color(0xFF10DA11), 'military_tech');
  }

  @override
  Widget build(BuildContext context) {
    final (String label, Color tint, String icon) = _rail;
    final String name = post.author?.name ?? 'A scholar';
    final String username = post.author?.username ?? '';
    return TactileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // milestone rail
          Row(
            children: <Widget>[
              MsIcon(icon, size: 16, color: tint, fill: true),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: tint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // author row
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: username.isEmpty
                    ? null
                    : () => PublicProfileScreen.push(context, username),
                child: SocialAvatar(
                    username: username,
                    name: name,
                    size: 40,
                    avatar: post.author?.avatar,
                    photo: post.author?.photo,
                  ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: username.isEmpty
                      ? null
                      : () => PublicProfileScreen.push(context, username),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (post.author?.premium ?? false) ...<Widget>[
                            const SizedBox(width: 5),
                            const BlueTickIcon(size: 14),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            timeAgo(post.createdAtMs),
                            style: RenanceText.caption.copyWith(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!post.mine && username.isNotEmpty)
                FollowChip(following: following, onTap: onFollow),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // action bar
          Row(
            children: <Widget>[
              _ActionKey(
                icon: fp.likedByMe ? 'favorite' : 'favorite_border',
                label: fp.likes > 0 ? '${fp.likes}' : 'Love',
                tint: fp.likedByMe ? RenanceColors.cardinal : null,
                fill: fp.likedByMe,
                onTap: onLike,
              ),
              const SizedBox(width: 8),
              _ActionKey(
                icon: 'chat_bubble',
                label: fp.comments > 0 ? '${fp.comments}' : 'Comment',
                onTap: onComments,
              ),
              const Spacer(),
              _ActionKey(
                icon: 'ios_share',
                label: '',
                onTap: onShare,
              ),
            ],
          ),
          // comments thread
          if (expanded) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (comments == null)
              const Center(child: RenanceMark(size: 22, busy: true))
            else ...<Widget>[
              if (comments!.isEmpty)
                Text(
                  'No comments yet - cheer them on.',
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary),
                )
              else
                for (final SocialComment c in comments!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommentRow(comment: c),
                  ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: draft,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onSendComment,
                    child: Container(alignment: Alignment.center,
                      
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: mixTowardBlack(context.primary, 0.68),
                            offset: const Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const MsIcon('send',
                          size: 18, color: Colors.white, fill: true),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final SocialComment comment;

  @override
  Widget build(BuildContext context) {
    final String name = comment.author?.name ?? 'A scholar';
    final String username = comment.author?.username ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: username.isEmpty
              ? null
              : () => PublicProfileScreen.push(context, username),
          child: SocialAvatar(
            username: username,
            name: name,
            size: 32,
            avatar: comment.author?.avatar,
            photo: comment.author?.photo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (comment.author?.premium ?? false) ...<Widget>[
                    const SizedBox(width: 4),
                    const BlueTickIcon(size: 12),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    timeAgo(comment.createdAtMs),
                    style: RenanceText.caption.copyWith(
                      fontSize: 11.5,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.body,
                style: RenanceText.bodyBase.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    this.fill = false,
  });

  final String icon;
  final String label;
  final Color? tint;
  final bool fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = tint ?? context.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MsIcon(icon, size: 18, color: color, fill: fill),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
