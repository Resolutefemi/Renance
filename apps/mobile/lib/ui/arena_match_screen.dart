/// Arena live duel, now on the REAL multiplayer hub
/// (apps/study-api/internal/arena) - no local simulation.
///
/// Frames arrive on the lobby-owned socket (this screen swaps its own
/// handler in for the duel and restores the owner's on dispose):
/// question frames carry the deadline, result frames the correct letter
/// keyed solves, and "over" the authoritative final scores - a win is
/// worth 1 Ren Point on the focus ladder. 15 questions, 20 seconds
/// each: five minutes on the floor. Founder rule: no purple, the
/// opponent accent is the gray secondary.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../arena_client.dart';
import 'theme.dart';

class ArenaMatchScreen extends StatefulWidget {
  const ArenaMatchScreen({
    super.key,
    required this.socket,
    required this.onFrames,
    required this.myId,
    required this.opponent,
    required this.focus,
    required this.onOver,
  });

  /// The lobby-owned arena socket (frames flow through here).
  final ArenaSocket socket;

  /// The owner's frame handler, restored when this screen pops.
  final void Function(Map<String, dynamic> frame) onFrames;

  /// The caller's userID for result/score attribution.
  final String myId;

  final String opponent;
  final String focus;

  /// Called once the duel is over (back to the floor).
  final VoidCallback onOver;

  @override
  State<ArenaMatchScreen> createState() => _ArenaMatchScreenState();
}

class _ArenaMatchScreenState extends State<ArenaMatchScreen> {
  // Live match state, driven by hub frames only.
  String _opponent = 'Renance Bot';
  int _questionCount = 15;
  int _secondsPerQuestion = 20;
  int _index = 0;
  int _you = 0;
  int _rival = 0;
  String _stem = '';
  List<Map<String, String>> _options = <Map<String, String>>[];
  String? _picked;
  String? _correct;
  int _deadline = 0;
  int _left = 0;
  bool _over = false;
  String _overNote = '';
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
    widget.socket.onFrame = _onFrame;
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.socket.onFrame = widget.onFrames;
    super.dispose();
  }

  void _onFrame(Map<String, dynamic> f) {
    if (!mounted) return;
    switch (f['type'] as String?) {
      case 'question':
        final Map<String, dynamic> q =
            (f['question'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
        final Map<String, dynamic> rawOpts =
            (q['options'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
        final List<String> letters = rawOpts.keys.toList()..sort();
        setState(() {
          _index = ((f['index'] ?? 0) as num).toInt();
          _stem = (q['stem'] ?? '') as String;
          _options = <Map<String, String>>[
            for (final String l in letters)
              <String, String>{'letter': l, 'text': (rawOpts[l] ?? '') as String},
          ];
          _picked = null;
          _correct = null;
          _deadline = ((f['deadline'] ?? 0) as num).toInt();
          _left = _deadline > 0
              ? (_deadline - DateTime.now().millisecondsSinceEpoch ~/ 1000)
                  .clamp(0, _secondsPerQuestion)
              : _secondsPerQuestion;
        });
        _startClock();
      case 'result':
        final Map<String, dynamic> solved =
            (f['solved'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
        setState(() {
          _correct = (f['correctLetter'] ?? '') as String;
          if (widget.myId.isNotEmpty && solved[widget.myId] == true) _you++;
          if (solved.entries
              .any((MapEntry<String, dynamic> e) => e.key != widget.myId && e.value == true)) {
            _rival++;
          }
        });
      case 'over':
        final Map<String, dynamic> scores =
            (f['scores'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
        final String winner = (f['winner'] ?? '') as String;
        final int? mine =
            widget.myId.isEmpty ? null : ((scores[widget.myId] ?? 0) as num).toInt();
        final int theirs = scores.entries
            .where((MapEntry<String, dynamic> e) => e.key != widget.myId)
            .fold(0, (int acc, MapEntry<String, dynamic> e) => acc + ((e.value ?? 0) as num).toInt());
        setState(() {
          _over = true;
          if (mine != null) _you = mine;
          _rival = theirs;
          _overNote = winner.isEmpty
              ? 'A draw - the point stays in the house.'
              : winner == widget.myId
                  ? 'You took the duel - +1 Ren Point on the ladder.'
                  : '$_opponent took this one. Run it back.';
        });
        widget.onOver();
      case 'matched':
        // A fresh match (rematch path): reset the board.
        setState(() {
          _opponent = (f['opponent'] as String?) ?? _opponent;
          _questionCount = ((f['questionCount'] ?? 15) as num).toInt();
          _secondsPerQuestion = ((f['secondsPerQuestion'] ?? 20) as num).toInt();
          _index = 0;
          _you = 0;
          _rival = 0;
          _over = false;
          _stem = '';
          _options = <Map<String, String>>[];
        });
      default:
        break;
    }
  }

  void _startClock() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int left = _deadline > 0
          ? (_deadline - DateTime.now().millisecondsSinceEpoch ~/ 1000)
              .clamp(0, _secondsPerQuestion)
          : _left;
      if (left != _left) setState(() => _left = left);
    });
  }

  void _pick(String letter) {
    if (_picked != null || _over) return;
    setState(() => _picked = letter);
    widget.socket.send(<String, dynamic>{
      'type': 'answer',
      'index': _index,
      'letter': letter,
    });
  }

  void _rematch() {
    widget.socket.send(<String, dynamic>{'type': 'queue', 'body': widget.focus});
    setState(() {
      _over = false;
      _overNote = '';
      _stem = '';
      _options = <Map<String, String>>[];
      _you = 0;
      _rival = 0;
      _index = 0;
    });
  }

  String get _clockLabel {
    final int m = _left ~/ 60;
    final int s = _left % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool waiting = !_over && _stem.isEmpty;
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                // scoreboard ---------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left, size: 24),
                        color: context.ink,
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: context.inverseChip,
                        child: Text('Y',
                            style: TextStyle(
                                color: context.onInverseChip,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text('You',
                          style: RenanceText.bodyMedium.copyWith(fontSize: 16)),
                      const Spacer(),
                      Text('$_you  -  $_rival',
                          style: RenanceText.displayMd.copyWith(fontSize: 21)),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          _opponent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RenanceText.bodyMedium.copyWith(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: context.secondary,
                        child: Text(
                          _opponent == 'Renance Bot' ? 'B' : _opponent.isNotEmpty ? _opponent[0].toUpperCase() : 'R',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _over ? 'Full time' : _clockLabel,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: RenanceColors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // round rail ----------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _questionCount == 0
                                ? 0
                                : (_index + (_over ? 1 : 0)) / _questionCount,
                            minHeight: 6,
                            backgroundColor: context.cardHigh,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(context.ink),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _over ? 'Done' : 'Q${_index + 1}/$_questionCount',
                        style: RenanceText.bodyBase,
                      ),
                    ],
                  ),
                ),
                // duel body -----------------------------------------------
                Expanded(
                  child: waiting
                      ? const Center(
                          child: Text(
                            'Loading the first question…',
                            style: TextStyle(color: Colors.black38),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            if (_over)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Text(
                                      '$_you - $_rival',
                                      style: RenanceText.displayMd
                                          .copyWith(fontSize: 30),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _overNote,
                                      textAlign: TextAlign.center,
                                      style: RenanceText.bodyMedium.copyWith(
                                          color: context.textSecondary),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.black,
                                              minimumSize:
                                                  const Size.fromHeight(50),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: _rematch,
                                            child: const Text('Rematch'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(50),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('The floor'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (!_over) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.card,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                        color: Color(0x14141C2D),
                                        blurRadius: 6,
                                        offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: context.selectionBlue,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                              '${_focusLabel(widget.focus)} duel',
                                              style: RenanceText.bodyMedium
                                                  .copyWith(fontSize: 14)),
                                        ),
                                        const Spacer(),
                                        Text(
                                            _picked == null
                                                ? 'LIVE · 20s window'
                                                : 'Answer locked in',
                                            style: RenanceText.labelMono
                                                .copyWith(
                                                    fontSize: 11,
                                                    color: context
                                                        .textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _stem,
                                      style: RenanceText.bodyMedium.copyWith(
                                          fontSize: 19, height: 28 / 19),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...List<Widget>.generate(_options.length, (int i) {
                                final Map<String, String> opt = _options[i];
                                final bool mine = _picked == opt['letter'];
                                final bool truth =
                                    _correct == opt['letter'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: _picked != null
                                        ? null
                                        : () => _pick(opt['letter']!),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: truth
                                            ? const Color(0xFFDFF5EA)
                                            : mine
                                                ? context.selectionBlue
                                                : context.card,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: truth
                                              ? const Color(0xFF10B981)
                                              : mine
                                                  ? context.ink
                                                  : context.outlineLight,
                                          width: mine || truth ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: mine
                                                  ? context.primary
                                                  : context.cardLow,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              opt['letter'] ?? '',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: mine
                                                      ? context.onPrimary
                                                      : context.ink),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              opt['text'] ?? '',
                                              style: RenanceText.bodyMedium
                                                  .copyWith(
                                                      fontSize: 15.5,
                                                      fontWeight: mine
                                                          ? FontWeight.w700
                                                          : FontWeight.w600),
                                            ),
                                          ),
                                          if (mine)
                                            const Icon(Icons.check_circle,
                                                size: 20, color: Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                ),
                // rail ----------------------------------------------------
                if (!_over)
                  Container(
                    color: context.card,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Answer locks in',
                                style: RenanceText.bodyMedium),
                            Text(
                              '${_left}s',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: RenanceColors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _secondsPerQuestion == 0
                                ? 0
                                : (_left / _secondsPerQuestion)
                                    .clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: context.cardHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                RenanceColors.amber),
                          ),
                        ),
                      ],
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

String _focusLabel(String f) =>
    f == 'University Modules' ? 'Tertiary' : (f == 'POST-UTME' ? 'Post UTME' : f);
