/// Career bridge, the Stitch career_bridge_light screen, 1:1.
///
/// The "Where can Biology take you?" hero, the Scholarships open now
/// list, the Course cut-off explorer with its filter chips. Static
/// friendly: the catalogue is the Stitch copy, chips are local state.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

class CareerBridgeScreen extends StatefulWidget {
  const CareerBridgeScreen({super.key});

  @override
  State<CareerBridgeScreen> createState() => _CareerBridgeScreenState();
}

class _CareerBridgeScreenState extends State<CareerBridgeScreen> {
  final Set<String> _filters = <String>{'Health'};

  static const List<String> _kFilterOptions = <String>[
    'Health',
    'Research',
    'Ecology',
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
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Career Bridge',
                        style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // hero ------------------------------------------------------
                Container(
                  height: 190,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: context.isDarkTier
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              RenanceColors.darkSurface,
                              RenanceColors.darkSurfaceLow,
                              Color(0xFF223252),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFEAF1FE),
                              Color(0xFFD8E3FB),
                              Color(0xFFC7D9F7),
                            ],
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Career Bridge',
                          style: RenanceText.overline
                              .copyWith(color: context.textSecondary)),
                      const Spacer(),
                      Text(
                        'Where can Biology take you?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w700,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Explore pathways and funding',
                          style: RenanceText.bodySecondary
                              .copyWith(color: context.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Scholarships open now ------------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Scholarships open now',
                      style: RenanceText.sectionTitle),
                ),
                SizedBox(height: 14),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      _ScholarshipRow(
                        icon: Icons.school_outlined,
                        title: 'National STEM Grant',
                        meta: 'Closes in 12 days • \$5,000',
                        urgent: true,
                      ),
                      Divider(height: 1, color: context.outlineLight),
                      _ScholarshipRow(
                        icon: Icons.biotech_outlined,
                        title: 'Future Biotech Leaders',
                        meta: 'Nov 15 Deadline • Full Tuition',
                      ),
                      Divider(height: 1, color: context.outlineLight),
                      _ScholarshipRow(
                        icon: Icons.eco_outlined,
                        title: 'Conservation Initiative',
                        meta: 'Dec 01 Deadline • \$2,500',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Course cut-off explorer ----------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Course cut-off explorer',
                      style: RenanceText.sectionTitle),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
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
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.cardLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText:
                                'Search degrees (e.g. B.Sc Marine Biology)',
                            icon: Icon(Icons.search,
                                color: context.textSecondary),
                            border: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final String f in _kFilterOptions)
                            FilterChip(
                              label: Text(f),
                              selected: _filters.contains(f),
                              onSelected: (bool v) => setState(() {
                                v ? _filters.add(f) : _filters.remove(f);
                              }),
                            ),
                        ],
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

class _ScholarshipRow extends StatelessWidget {
  const _ScholarshipRow({
    required this.icon,
    required this.title,
    required this.meta,
    this.urgent = false,
  });

  final IconData icon;
  final String title;
  final String meta;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.cardHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: context.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(title,
                            overflow: TextOverflow.ellipsis,
                            style:
                                RenanceText.bodyMedium.copyWith(fontSize: 17)),
                      ),
                      if (urgent) ...<Widget>[
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('URGENT',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: context.error,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(meta,
                      style: RenanceText.bodySecondary
                          .copyWith(color: context.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}
