/// Voice flashcards (ROADMAP #7) — the Stitch voice_flashcards_light.
///
/// Deck grid → the player: white card stage with the front in display-lg,
/// the answer in emerald on reveal, the violet play pill with the
/// waveform bars, and Reveal → Again / Hard / Good. TTS reads the front
/// when a card appears and the back when revealed; voice is optional and
/// everything works offline from the pack store.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'theme.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<FlashcardsController>().loadDecks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FlashcardsController c = context.watch<FlashcardsController>();
    if (c.deck != null) {
      return _CardPlayer(controller: c);
    }
    return Scaffold(
      backgroundColor: RenanceColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: RenanceColors.surfaceContainerLowest,
        title: const Text('Flashcards', style: RenanceText.sectionTitle),
        titleSpacing: 0,
      ),
      body: switch (c.phase) {
        CardsPhase.loading => const Center(
            child: Text('Loading decks…', style: RenanceText.bodySecondary)),
        CardsPhase.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.wifi_off,
                      size: 40, color: RenanceColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(c.error ?? 'Could not reach Renance servers',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodySecondary),
                ],
              ),
            ),
          ),
        CardsPhase.ready when c.decks.isEmpty => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No decks yet — they ship with your packs.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary),
            ),
          ),
        CardsPhase.ready => _DeckGrid(controller: c),
      },
    );
  }
}

// ----------------------------------------------------------------- decks

class _DeckGrid extends StatelessWidget {
  const _DeckGrid({required this.controller});

  final FlashcardsController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.decks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int i) {
        final FlashcardDeckMeta d = controller.decks[i];
        return _DeckTile(meta: d, onTap: () => controller.openDeck(d.code));
      },
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.meta, required this.onTap});

  final FlashcardDeckMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RenanceColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x33141C2D), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: RenanceColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.headphones,
                  size: 22, color: RenanceColors.violet),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(meta.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.bodyMedium.copyWith(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    '${meta.cardCount} cards'
                    '${meta.subject.isEmpty ? '' : ' · ${meta.subject}'}',
                    style: RenanceText.caption
                        .copyWith(color: RenanceColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 22, color: RenanceColors.outlineLight),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- player

class _CardPlayer extends StatelessWidget {
  const _CardPlayer({required this.controller});

  final FlashcardsController controller;

  @override
  Widget build(BuildContext context) {
    final FlashcardCard? card = controller.current;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) controller.closeDeck();
      },
      child: Scaffold(
        backgroundColor: RenanceColors.background,
        appBar: AppBar(
          backgroundColor: RenanceColors.background,
          title: Row(
            children: <Widget>[
              const Icon(Icons.headphones,
                  size: 20, color: RenanceColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  controller.deck?.title ?? 'Flashcards',
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.bodyMedium
                      .copyWith(color: RenanceColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: controller.voiceOn ? 'Mute voice' : 'Unmute voice',
              onPressed: controller.toggleVoice,
              icon: Icon(
                controller.voiceOn ? Icons.volume_up : Icons.volume_off,
                size: 22,
                color: controller.voiceOn
                    ? RenanceColors.violet
                    : RenanceColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: _CardStage(controller: controller, card: card),
        ),
      ),
    );
  }
}

class _CardStage extends StatelessWidget {
  const _CardStage({required this.controller, required this.card});

  final FlashcardsController controller;
  final FlashcardCard? card;

  @override
  Widget build(BuildContext context) {
    if (controller.isDeckDone || card == null) {
      return _DeckComplete(controller: controller);
    }
    final FlashcardCard c = card!;
    final FlashcardDeck? deck = controller.deck;
    final CardProgress? p = controller.progress[c.id];

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: deck == null || deck.cardCount == 0
                        ? 0
                        : controller.index / deck.cardCount,
                    minHeight: 4,
                    backgroundColor: RenanceColors.surfaceContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        RenanceColors.violet),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${controller.index + 1}'
                '/${deck?.cardCount ?? 0}',
                style: RenanceText.statNumber.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: controller.flip,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: RenanceColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                        color: Color(0x33141C2D),
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: controller.revealed
                          ? Column(
                              key: const ValueKey<String>('back'),
                              children: <Widget>[
                                Text(c.back,
                                    textAlign: TextAlign.center,
                                    style: RenanceText.displayLg.copyWith(
                                        fontSize: 22,
                                        color: RenanceColors.emerald)),
                                if (p != null) ...<Widget>[
                                  const SizedBox(height: 16),
                                  Text('Box ${p.box}',
                                      style: RenanceText.labelMono.copyWith(
                                          fontSize: 12,
                                          color:
                                              RenanceColors.textSecondary)),
                                ],
                              ],
                            )
                          : Text(
                              c.front,
                              key: const ValueKey<String>('front'),
                              textAlign: TextAlign.center,
                              style: RenanceText.displayLg.copyWith(
                                  fontSize: 22),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _VoicePill(
                      label:
                          controller.revealed ? 'Read answer' : 'Read card',
                      onPlay: () => controller.speech.speak(
                          controller.revealed ? c.back : c.front),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: controller.revealed
              ? Row(
                  children: <Widget>[
                    Expanded(
                        child: _GradeButton(
                            label: 'Again',
                            bg: RenanceColors.errorContainer,
                            fg: RenanceColors.error,
                            onTap: () => controller.grade('again'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _GradeButton(
                            label: 'Hard',
                            bg: RenanceColors.secondaryContainer,
                            fg: RenanceColors.ink,
                            onTap: () => controller.grade('hard'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _GradeButton(
                            label: 'Good',
                            bg: RenanceColors.surfaceContainerHigh,
                            fg: RenanceColors.ink,
                            onTap: () => controller.grade('good'))),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: controller.flip,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reveal',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The violet play pill with the animated waveform bars (design's
/// #audio-playback): tap re-reads the visible side aloud.
class _VoicePill extends StatelessWidget {
  const _VoicePill({required this.label, required this.onPlay});

  final String label;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
        decoration: BoxDecoration(
          color: RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: RenanceColors.violet,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  size: 24, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const _Waveform(),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  static const List<double> _heights = <double>[1.0, 0.75, 0.5, 1.0, 0.66];

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (BuildContext context, Widget? _) => Row(
        children: <Widget>[
          for (var i = 0; i < _heights.length; i++)
            Container(
              width: 5,
              height: 24 * _heights[i],
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: RenanceColors.selectionBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              transformAlignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                1,
                0.4 + 0.6 * (0.5 + 0.5 * _wave(_ac.value, i)),
                1,
              ),
            ),
        ],
      ),
    );
  }

  /// Sine phase offset per bar — the CSS staggered animation, ported.
  double _wave(double t, int i) =>
      0.5 + 0.5 * (2 * 3.14159 * (t * 1.0 + i * 0.2));
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _DeckComplete extends StatelessWidget {
  const _DeckComplete({required this.controller});

  final FlashcardsController controller;

  @override
  Widget build(BuildContext context) {
    final int total = controller.deck?.cardCount ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.task_alt,
                size: 48, color: RenanceColors.emerald),
            const SizedBox(height: 16),
            const Text('Deck complete', style: RenanceText.displayMd),
            const SizedBox(height: 8),
            Text(
              'You ran $total cards · ${controller.knownCount} known '
              '(box 3+). They will resurface on their Leitner schedule.',
              textAlign: TextAlign.center,
              style: RenanceText.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 52,
              child: FilledButton(
                onPressed: controller.restartDeck,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Run it again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
