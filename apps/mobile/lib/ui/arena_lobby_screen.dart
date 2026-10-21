/// THE ARENA - the app's live floor, the school-app lobby cut with real
/// multiplayer behind it.
///
/// Three ways into a duel (the founder's cut):
///   · Quick Match   - the focus bucket queue, the house bot keeps it moving
///   · Host a room   - a short code + shareable invite
///   · Active Now    - live presence from GET /arena/players, one tap
///                     challenges a student who is on the floor right now
///
/// Each focus is its own arena (JAMB, WAEC, NECO, Post UTME, Tertiary):
/// separate queues, separate pack shelves, separate Ren Point ladders.
/// A duel is 15 questions at a 20-second window each - five minutes -
/// and every win is worth 1 Ren Point. The whole flow runs on ONE
/// authenticated WebSocket owned here and handed to ArenaMatchScreen,
/// so the connection never drops mid-match.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../arena_client.dart';
import '../config.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'arena_match_screen.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

const List<String> _kFoci = <String>[
  'JAMB',
  'WAEC',
  'NECO',
  'POST-UTME',
  'University Modules',
];

String _focusLabel(String f) =>
    f == 'University Modules' ? 'Tertiary' : (f == 'POST-UTME' ? 'Post UTME' : f);

class ArenaLobbyScreen extends StatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  State<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends State<ArenaLobbyScreen> {
  String _focus = 'JAMB';
  bool _down = false;
  bool _connecting = true;

  // lobby states: idle | queued | hosted | challengeSent
  String _roomCode = '';
  String _waitingNote = '';
  List<ArenaPlayer>? _players;

  ArenaSocket? _sock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final StudentController student = context.read<StudentController>();
      setState(() {
        _focus = student.me?.profile?.exams.firstOrNull ?? 'JAMB';
        if (!_kFoci.contains(_focus)) _focus = 'JAMB';
      });
      _openSocket();
      _loadPlayers();
    });
  }

  @override
  void dispose() {
    _sock?.send(const <String, dynamic>{'type': 'cancel'});
    _sock?.close();
    super.dispose();
  }

  ApiClient get _api => context.read<ApiClient>();

  Future<void> _openSocket() async {
    final SessionStore session = context.read<SessionStore>();
    final String token = session.token ?? '';
    if (token.isEmpty) {
      setState(() {
        _down = true;
        _connecting = false;
      });
      return;
    }
    final ArenaSocket sock = ArenaSocket(
      onFrame: _onFrame,
      onDown: () {
        if (mounted) setState(() => _down = true);
      },
    );
    _sock = sock;
    await sock.connect(token);
    if (mounted) setState(() => _connecting = false);
  }

  void _onFrame(Map<String, dynamic> f) {
    if (!mounted) return;
    switch (f['type'] as String?) {
      case 'matched':
        _startMatch(
          opponent: (f['opponent'] as String?) ?? 'Renance Bot',
        );
      case 'challenge':
        final String code = (f['code'] as String?) ?? '';
        final String opponent = (f['opponent'] as String?) ?? 'A rival';
        if (code.isEmpty) return;
        _confirmChallenge(opponent, code);
      case 'challenge_sent':
        setState(() {
          _roomCode = (f['code'] as String?) ?? '';
          _waitingNote = 'Challenge sent - waiting for the answer';
        });
      case 'hosted':
        setState(() {
          _roomCode = (f['code'] as String?) ?? '';
          _waitingNote = 'Your room is open - share the code';
        });
      case 'cancelled':
        setState(() {
          _roomCode = '';
          _waitingNote = '';
        });
      case 'error':
        final String code = (f['errorCode'] as String?) ?? '';
        if (code == 'already_queued' || code == 'in_match') return;
        final String msg = (f['message'] as String?) ?? 'The arena refused that move.';
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        setState(() {
          _roomCode = '';
          _waitingNote = '';
        });
      default:
        break;
    }
  }

  Future<void> _loadPlayers() async {
    try {
      final List<ArenaPlayer> rows = await _api.arenaPlayers();
      if (!mounted) return;
      setState(() => _players = rows);
    } on ApiException {
      if (mounted) setState(() => _players = <ArenaPlayer>[]);
    } on NetworkException {
      if (mounted) setState(() => _players = <ArenaPlayer>[]);
    }
  }

  void _send(Map<String, dynamic> frame) => _sock?.send(frame);

  void _backToIdle() {
    setState(() {
      _roomCode = '';
      _waitingNote = '';
    });
  }

  void _startMatch({required String opponent}) {
    final ArenaSocket? sock = _sock;
    if (sock == null) return;
    final StudentController student = context.read<StudentController>();
    final String myId = student.me?.user.id ?? '';
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ArenaMatchScreen(
              socket: sock,
              onFrames: _onFrame,
              myId: myId,
              opponent: opponent,
              focus: _focus,
              onOver: _backToIdle,
            ),
          ),
        )
        .whenComplete(_backToIdle);
  }

  Future<void> _confirmChallenge(String opponent, String code) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('$opponent challenges you'),
        content: const Text(
          '15 questions · 5 minutes · 1 Ren Point to the winner.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.inverseChip,
              foregroundColor: context.onInverseChip,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Accept duel'),
          ),
        ],
      ),
    );
    if (accepted == true) _send(<String, dynamic>{'type': 'join', 'code': code});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Arena', style: RenanceText.sectionTitle.copyWith(fontSize: 20)),
        foregroundColor: context.ink,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              // focus floor chips -------------------------------------
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final String f in _kFoci)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            _focusLabel(f),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: _focus == f,
                          onSelected: (_) => setState(() => _focus = f),
                          selectedColor: context.inverseChip,
                          labelStyle: TextStyle(
                            color: _focus == f
                                ? context.onInverseChip
                                : context.textSecondary,
                          ),
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // dark hero ----------------------------------------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // The founder's rule: the black hero follows the colour
                  // selected in Appearance (stock black, the seed colour,
                  // light on the dark tier).
                  color: context.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_focusLabel(_focus).toUpperCase()} FLOOR',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        letterSpacing: 3,
                        color: context.onPrimary.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the arena',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: context.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: const <Widget>[
                        _RulePill('15 questions'),
                        _RulePill('5:00 minutes'),
                        _RulePill('Win = +1 Ren Point'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_down)
                      Material(
                        color: context.onPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _down = false;
                              _connecting = true;
                            });
                            _openSocket();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              'Arena socket dropped - tap to reconnect',
                              style: TextStyle(color: context.onPrimary),
                            ),
                          ),
                        ),
                      )
                    else if (_roomCode.isNotEmpty) ...<Widget>[
                      Text(
                        _waitingNote,
                        style: TextStyle(
                            color: context.onPrimary.withValues(alpha: 0.7),
                            fontSize: 13.5),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _roomCode,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                            color: context.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ArenaButton(
                        label: 'Copy invite link',
                        icon: 'link',
                        onTap: () => _copyInvite(context),
                      ),
                      const SizedBox(height: 8),
                      _ArenaButton(
                        label: 'Cancel',
                        icon: 'close',
                        onTap: () {
                          _send(const <String, dynamic>{'type': 'cancel'});
                          _backToIdle();
                        },
                      ),
                    ]
                    else ...<Widget>[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: context.onPrimary,
                            foregroundColor: context.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              (_connecting || _down) ? null : _quickMatch,
                          icon: MsIcon('swords', size: 20),
                          label: Text(
                            _connecting ? 'Connecting…' : 'Quick Match',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _ArenaButton(
                              label: 'Host a room',
                              icon: 'meeting_room',
                              onTap:
                                  (_connecting || _down) ? null : _hostRoom,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ArenaButton(
                              label: 'Join with code',
                              icon: 'group_add',
                              onTap:
                                  (_connecting || _down) ? null : _joinRoom,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Active now ----------------------------------------------
              Row(
                children: <Widget>[
                  Text('Active now',
                      style: RenanceText.sectionTitle.copyWith(fontSize: 17)),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00CD9C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_players == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'Checking who is on the floor…',
                      style: TextStyle(color: context.textMuted, fontSize: 13.5),
                    ),
                  ),
                )
              else if (_players!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Nobody else is in the arena right now - quick match, or '
                    'bring a friend with a room code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textMuted, fontSize: 13.5),
                  ),
                )
              else
                ...<Widget>[
                  for (final ArenaPlayer p in _players!)
                    Container(alignment: Alignment.center,
                      
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: context.surfaceVariant,
                            child: MsIcon('person',
                                size: 20, color: context.textMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  p.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${p.renPoints} Ren Points',
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TactileButton(
                            height: 36,
                            radius: RenanceRadius.chip,
                            fontSize: 12.5,
                            face: context.inverseChip,
                            onFace: context.onInverseChip,
                            expand: false,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            onPressed: () => _send(<String, dynamic>{
                              'type': 'challenge',
                              'target': p.userId,
                              'body': _focus,
                            }),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const <Widget>[
                                MsIcon('swords', size: 15),
                                SizedBox(width: 4),
                                Text('Battle'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _loadPlayers,
                  child: const Text('Refresh the floor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _quickMatch() {
    _backToIdle();
    _send(<String, dynamic>{'type': 'queue', 'body': _focus});
  }

  void _hostRoom() {
    _backToIdle();
    _send(<String, dynamic>{'type': 'host', 'body': _focus});
  }

  Future<void> _joinRoom() async {
    final TextEditingController code = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Join a duel'),
        content: TextField(
          controller: code,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'ABC123',
            counterText: '',
          ),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 22,
            letterSpacing: 6,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.inverseChip,
              foregroundColor: context.onInverseChip,
            ),
            onPressed: () => Navigator.of(ctx).pop(code.text.trim()),
            child: const Text('Walk in'),
          ),
        ],
      ),
    );
    if (entered != null && entered.length >= 4) {
      _send(<String, dynamic>{'type': 'join', 'code': entered.toUpperCase()});
    }
  }

  Future<void> _copyInvite(BuildContext context) async {
    final String base = apiBaseUrl.startsWith('http')
        ? apiBaseUrl.replaceFirst(RegExp(r'^ws'), 'http')
        : apiBaseUrl;
    // The invite rides whatever channel the friend opens first; on the
    // phone the code itself is the contract, the link is a convenience.
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Invite'),
        content: SelectableText('Room code: $_roomCode\nJoin from the app or the web arena: $base/arena?join=$_roomCode'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  const _RulePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.onPrimary,
        ),
      ),
    );
  }
}

class _ArenaButton extends StatelessWidget {
  const _ArenaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The web's arena secondary keys: flat translucent pills
    // (bg-card/10 on the green hero) - deliberately not 3D keys.
    final bool enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: context.onPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MsIcon(icon, size: 17, color: context.onPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
