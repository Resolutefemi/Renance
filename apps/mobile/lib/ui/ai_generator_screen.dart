/// AI question generator, the Stitch ai_question_generator_light screen, 1:1.
///
/// Generate practice: topic chips, the Easy / Medium / Hard segmented
/// control, the count stepper and the black Generate CTA (the design's
/// purple button, re-toned per the founder's no-purple rule), plus the
/// Review Generated list with the AI GENERATED pill. Static friendly:
/// Generate appends a mock pending question locally until the AI provider
/// key lands (Class B).
library;

import 'package:flutter/material.dart';

import 'theme.dart';

class AiGeneratorScreen extends StatefulWidget {
  const AiGeneratorScreen({super.key});

  @override
  State<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends State<AiGeneratorScreen> {
  static const List<String> _kTopics = <String>[
    'Microeconomics',
    'Calculus I',
    'World History',
    'Organic Chem',
  ];
  static const List<String> _kDifficulties = <String>['Easy', 'Medium', 'Hard'];

  final Set<String> _topics = <String>{'Microeconomics'};
  int _difficulty = 1;
  int _count = 5;

  final List<({String stem, String difficulty})> _generated =
      <({String stem, String difficulty})>[
    (
      stem: 'Explain the concept of opportunity cost using a real-world example.',
      difficulty: 'Medium',
    ),
  ];

  void _generate() {
    setState(() {
      for (var i = 0; i < _count; i++) {
        _generated.add((
          stem: 'Practice question ${_generated.length + 1}: Explain the '
              'concept of ${_topics.isEmpty ? 'Microeconomics' : _topics.first}.',
          difficulty: _kDifficulties[_difficulty],
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RenanceColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: RenanceColors.ink,
                      ),
                      const SizedBox(width: 4),
                      const Text('Generate practice',
                          style: RenanceText.sectionTitle),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'AI-powered question generation tailored to your needs.',
                    style: RenanceText.bodySecondary,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: <Widget>[
                      // builder card ------------------------------------
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: RenanceColors.card,
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
                            const Row(
                              children: <Widget>[
                                Icon(Icons.category_outlined,
                                    size: 20, color: RenanceColors.ink),
                                SizedBox(width: 10),
                                Text('Select Topic',
                                    style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                for (final String t in _kTopics)
                                  _TopicChip(
                                    label: t,
                                    selected: _topics.contains(t),
                                    onTap: () => setState(() {
                                      _topics.contains(t)
                                          ? _topics.remove(t)
                                          : _topics.add(t);
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            const Row(
                              children: <Widget>[
                                Icon(Icons.bar_chart,
                                    size: 20, color: RenanceColors.ink),
                                SizedBox(width: 10),
                                Text('Difficulty',
                                    style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: RenanceColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: <Widget>[
                                  for (var i = 0; i < 3; i++)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => _difficulty = i),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _difficulty == i
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _kDifficulties[i],
                                            textAlign: TextAlign.center,
                                            style: RenanceText.bodyBase
                                                .copyWith(
                                              fontWeight:
                                                  _difficulty == i
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Row(
                              children: <Widget>[
                                Icon(Icons.format_list_numbered,
                                    size: 20, color: RenanceColors.ink),
                                SizedBox(width: 10),
                                Text('Question Count',
                                    style: RenanceText.sectionTitle),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: RenanceColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: <Widget>[
                                  _StepButton(
                                    icon: Icons.remove,
                                    onTap: () => setState(() =>
                                        _count = (_count - 1).clamp(1, 50)),
                                  ),
                                  Expanded(
                                    child: Text('$_count',
                                        textAlign: TextAlign.center,
                                        style: RenanceText.displayMd
                                            .copyWith(fontSize: 20)),
                                  ),
                                  _StepButton(
                                    icon: Icons.add,
                                    onTap: () => setState(
                                        () => _count = (_count + 1).clamp(1, 50)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onPressed: _topics.isEmpty ? null : _generate,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const <Widget>[
                                    Icon(Icons.auto_awesome, size: 18),
                                    SizedBox(width: 8),
                                    Text('Generate',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Review Generated --------------------------------
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text('Review Generated',
                                style: RenanceText.sectionTitle),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: RenanceColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${_generated.length} Pending',
                                style: RenanceText.caption),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ..._generated.map(_GeneratedCard.new),
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

class _TopicChip extends StatelessWidget {
  const _TopicChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? RenanceColors.selectionBlue
              : RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? RenanceColors.ink : RenanceColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: RenanceColors.ink),
      ),
    );
  }
}

class _GeneratedCard extends StatelessWidget {
  const _GeneratedCard(this.item);

  final ({String stem, String difficulty}) item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: RenanceColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.smart_toy_outlined,
                              size: 13, color: RenanceColors.ink),
                          SizedBox(width: 5),
                          Text('AI GENERATED',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.8,
                                  color: RenanceColors.ink)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(item.difficulty, style: RenanceText.caption),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.stem.replaceAll('\n', ' '),
                  style: RenanceText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500, height: 22 / 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: RenanceColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 20, color: RenanceColors.emerald),
          ),
        ],
      ),
    );
  }
}
