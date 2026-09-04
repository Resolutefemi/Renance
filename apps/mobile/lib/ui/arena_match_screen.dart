/// Arena live match, the Stitch arena_match_light screen, 1:1.
///
/// Head-to-head 5-question duel simulated locally: a 42s round clock, the
/// LIVE question card ("LIVE · first to 5"), the four option rows with
/// your ink chip and the opponent's gray chip, the "answered in" caption
/// and the "Answer locks in" bottom rail. Founder rule: no purple, the
/// opponent accent is the gray secondary.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

class _MatchQ {
  const _MatchQ(this.topic, this.stem, this.options, this.correct);
  final String topic;
  final String stem;
  final List<String> options;
  final int correct;
}

const List<_MatchQ> _kMatchQuestions = <_MatchQ>[
  _MatchQ('Biology', 'Which organelle is known as the powerhouse of the cell?',
      <String>['Ribosome', 'Mitochondrion', 'Golgi apparatus', 'Nucleolus'], 1),
  _MatchQ('Biology', 'Which blood cells carry oxygen?',
      <String>['Platelets', 'Rods', 'Red cells', 'White cells'], 2),
  _MatchQ('Biology', 'Photosynthesis mainly occurs in the:',
      <String>['Mitochondria', 'Chloroplasts', 'Vacuole', 'Nucleus'], 1),
  _MatchQ('Biology', 'The basic unit of heredity is the:',
      <String>['Enzyme', 'Protein', 'Cell', 'Gene'], 3),
  _MatchQ('Biology', 'Which vitamin is produced in the skin by sunlight?',
      <String>['Vitamin A', 'Vitamin C', 'Vitamin D', 'Vitamin K'], 2),
];

class ArenaMatchScreen extends StatefulWidget {
  const ArenaMatchScreen({super.key});

  @override
  State<ArenaMatchScreen> createState() => _ArenaMatchScreenState();
}

class _ArenaMatchScreenState extends State<ArenaMatchScreen> {
  int _index = 3; // the Stitch capture opens on Q4/5
  int _you = 3;
  int _rival = 2;
  int? _yourPick;
  int? _rivalPick;
  bool _locked = false;
  int _roundLeft = 42;
  int _lockLeft = 12;
  String _rivalNote = '';
  Timer? _tick;

  _MatchQ get _q => _kMatchQuestions[_index];

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _startRound() {
    _tick?.cancel();
    _yourPick = null;
    _rivalPick = null;
    _locked = false;
    _roundLeft = 42;
    _lockLeft = 12;
    _rivalNote = '';
    // The rival locks at a random beat within the window.
    final int delay = 2 + (_index * 37) % 9;
    Future<void>.delayed(Duration(seconds: delay), () {
      if (!mounted || _locked) return;
      setState(() {
        _rivalPick = (_index + 1) % 4;
        _rivalNote = 'Tunde answered in ${(1.2 + _index * 0.7).toStringAsFixed(1)}s. '
            'Tap your answer to lock it';
      });
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        if (_roundLeft > 0) _roundLeft--;
        if (!_locked && _lockLeft > 0) _lockLeft--;
        if (_roundLeft == 0 && !_locked) _lock(_yourPick ?? -1);
      });
    });
  }

  void _lock(int pick) {
    _tick?.cancel();
    setState(() {
      _yourPick = pick;
      _locked = true;
      if (pick == _q.correct) _you++;
      if (_rivalPick == _q.correct) _rival++;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        if (_index >= _kMatchQuestions.length - 1) {
          _index = 0;
          _you = 0;
          _rival = 0;
        } else {
          _index++;
        }
      });
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Colors.black, shape: BoxShape.circle),
                        child: const Text('Y',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text('You',
                          style: RenanceText.bodyMedium.copyWith(fontSize: 17)),
                      Spacer(),
                      Text('$_you  —  $_rival',
                          style: RenanceText.displayMd.copyWith(fontSize: 22)),
                      Spacer(),
                      Text('Tunde',
                          style: RenanceText.bodyMedium.copyWith(fontSize: 17)),
                      SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: context.secondary,
                            shape: BoxShape.circle),
                        child: const Text('T',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.timer_outlined,
                                size: 15, color: RenanceColors.amber),
                            const SizedBox(width: 4),
                            Text('0:$_roundLeft'.padLeft(4, '0'),
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: RenanceColors.amber,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // round rail ----------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (_index + 1) / _kMatchQuestions.length,
                            minHeight: 6,
                            backgroundColor:
                                context.cardHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                context.ink),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Q${_index + 1}/5', style: RenanceText.bodyBase),
                    ],
                  ),
                ),
                // question card -------------------------------------------
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
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
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(_q.topic,
                                      style: RenanceText.bodyMedium
                                          .copyWith(fontSize: 15)),
                                ),
                                const Spacer(),
                                Text('LIVE · first to 5',
                                    style: RenanceText.labelMono.copyWith(
                                        fontSize: 11,
                                        color:
                                            context.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(_q.stem,
                                style: RenanceText.bodyMedium.copyWith(
                                    fontSize: 20, height: 28 / 20)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List<Widget>.generate(4, (int i) {
                        final bool mine = _yourPick == i;
                        final bool theirs = _rivalPick == i && !mine;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: _locked
                                ? null
                                : () => _lock(i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: mine
                                    ? context.selectionBlue
                                    : context.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: mine
                                      ? context.ink
                                      : context.outlineLight,
                                  width: mine ? 2 : 1,
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
                                          ? Colors.black
                                          : context.cardLow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + i),
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: mine
                                              ? Colors.white
                                              : context.ink),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_q.options[i],
                                        style: RenanceText.bodyMedium
                                            .copyWith(
                                                fontSize: 16,
                                                fontWeight: mine
                                                    ? FontWeight.w700
                                                    : FontWeight.w600)),
                                  ),
                                  if (mine)
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle),
                                      child: const Text('Y',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  if (theirs)
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: context.secondary,
                                          shape: BoxShape.circle),
                                      child: const Text('T',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text(
                        _rivalNote.isEmpty
                            ? 'Tap your answer to lock it'
                            : _rivalNote,
                        textAlign: TextAlign.center,
                        style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Answer locks in ----------------------------------------
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
                          Text('0:${_lockLeft.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: RenanceColors.amber,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _lockLeft / 12,
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
