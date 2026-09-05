/// Study plan, the Stitch study_plan_light screen, 1:1.
///
/// "TODAY'S PLAN" card with the three focus blocks, the Current Energy
/// Level selector and the Fatigue Insight card. Static-friendly: the plan
/// is the Stitch copy, the energy chip is local state, and the play
/// buttons route into the shelves that already exist.
///
/// Wide windows (desktop, >= 560 px) keep the column centered.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Study plan screen entry.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  int _energy = 0; // 0 Sharp, 1 Normal, 2 Tired

  static const List<String> _kEnergies = <String>['Sharp', 'Normal', 'Tired'];
  static const List<IconData> _kEnergyIcons = <IconData>[
    Icons.bolt,
    Icons.battery_charging_full,
    Icons.battery_1_bar,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                // back bar ------------------------------------------------
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Study Plan', style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // TODAY'S PLAN card --------------------------------------
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text("TODAY'S PLAN",
                                style: RenanceText.overline.copyWith(color: context.textSecondary)),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.cardLow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_outlined,
                                size: 20, color: context.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('42 min remaining',
                          style: RenanceText.displayMd),
                      const SizedBox(height: 16),
                      const _PlanRow(
                        icon: Icons.science_outlined,
                        iconBg: Color(0xFFE8F5E9),
                        iconColor: RenanceColors.emerald,
                        title: 'Biology Practice',
                        meta: '15 min',
                        focus: 'High focus',
                      ),
                      const SizedBox(height: 10),
                      _PlanRow(
                        icon: Icons.style_outlined,
                        iconBg: Color(0xFFE7EEFF),
                        iconColor: context.ink,
                        title: 'Review Cards',
                        meta: '12 min',
                        focus: 'Medium focus',
                      ),
                      const SizedBox(height: 10),
                      const _PlanRow(
                        icon: Icons.mic_outlined,
                        iconBg: Color(0xFFFFF3D6),
                        iconColor: RenanceColors.amber,
                        title: 'Voice Flashcards',
                        meta: '15 min',
                        focus: 'Low focus',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Current Energy Level ------------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Current Energy Level',
                      style: RenanceText.sectionTitle),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    for (var i = 0; i < _kEnergies.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 10),
                      _EnergyChip(
                        label: _kEnergies[i],
                        icon: _kEnergyIcons[i],
                        selected: _energy == i,
                        onTap: () => setState(() => _energy = i),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 28),
                // Fatigue Insight -----------------------------------------
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.isDarkTier
                        ? RenanceColors.darkSurface
                        : const Color(0xFFE4EAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lightbulb_outlined,
                            size: 22, color: context.ink),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Fatigue Insight',
                                style: RenanceText.bodyMedium
                                    .copyWith(color: context.ink)),
                            SizedBox(height: 8),
                            Text(
                              "You usually fade after ~25 min in the "
                              "evening. We've placed your heaviest topics "
                              "(Biology) first to maximize retention.",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                height: 24 / 15,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
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

/// One plan block row: drag-handle dots, tinted icon circle, title +
/// "15 min • High focus" meta and the play affordance.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.meta,
    required this.focus,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String meta;
  final String focus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.isDarkTier
            ? RenanceColors.darkSurfaceLow
            : const Color(0xFFEEF1FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var r = 0; r < 2; r++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      for (var c = 0; c < 2; c++)
                        Container(
                          width: 3.5,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: context.outlineLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: RenanceText.bodyMedium
                        .copyWith(fontSize: 17, color: context.ink)),
                const SizedBox(height: 2),
                Text('$meta • $focus',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 15)),
              ],
            ),
          ),
          Icon(Icons.play_arrow_rounded,
              size: 26, color: context.ink),
        ],
      ),
    );
  }
}

/// Energy chip: selection-blue when active, plain container otherwise.
class _EnergyChip extends StatelessWidget {
  const _EnergyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? context.selectionBlue
                : context.cardLow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  size: 18,
                  color: selected ? context.ink : context.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? context.ink : context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
