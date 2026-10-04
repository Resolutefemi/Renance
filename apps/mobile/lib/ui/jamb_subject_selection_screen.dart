/// Subject Selection, the Stitch jamb_subject_selection_light screen -
/// now driven by the REAL bank slugs.
///
/// The catalogue mirrors lib/papers.dart's kUtmeElectives (one entry per
/// JAMB past-question bank), filtered down to the slugs the live
/// manifest actually ships. English stays mandatory for the Standard
/// UTME Mock (English + up to 3 electives); Custom Practice lets the
/// candidate take any 1-4 subjects, English optional.
///
/// The old hardcoded ids ("math") that never matched the server's bank
/// slugs are gone - selections now compose real papers 1:1.
library;

import 'package:flutter/material.dart';

import '../papers.dart';
import 'theme.dart';

/// One selectable subject row.
class _PickableSubject {
  const _PickableSubject(this.slug, this.name, this.icon);
  final String slug;
  final String name;
  final IconData icon;
}

IconData _iconFor(String slug) => switch (slug) {
      'english' => Icons.menu_book,
      'mathematics' => Icons.calculate,
      'physics' => Icons.psychology,
      'chemistry' => Icons.science,
      'biology' => Icons.biotech,
      'literature' => Icons.auto_stories,
      'crs' => Icons.church,
      'irs' => Icons.mosque,
      'agricultural-science' => Icons.agriculture,
      'commerce' => Icons.storefront,
      'accounting' => Icons.receipt_long,
      'computer-studies' => Icons.computer,
      'civic-education' => Icons.gavel,
      'economics' => Icons.trending_up,
      'government' => Icons.account_balance,
      'geography' => Icons.public,
      'history' => Icons.history_edu,
      'french' => Icons.translate,
      'arabic' => Icons.language,
      'hausa' => Icons.record_voice_over,
      'igbo' => Icons.record_voice_over,
      'yoruba' => Icons.record_voice_over,
      'music' => Icons.music_note,
      'fine-arts' => Icons.palette,
      'home-economics' => Icons.home,
      'physical-education' => Icons.sports_soccer,
      _ => Icons.book,
    };

/// English first, then the electives in catalogue order.
List<_PickableSubject> _catalogue(Set<String> available) {
  final List<_PickableSubject> list = <_PickableSubject>[
    const _PickableSubject('english', 'Use of English', Icons.menu_book),
  ];
  for (final (String slug, String name) in kUtmeElectives) {
    if (available.isEmpty || available.contains(slug)) {
      list.add(_PickableSubject(slug, name, _iconFor(slug)));
    }
  }
  return list;
}

class JambSubjectSelectionScreen extends StatefulWidget {
  const JambSubjectSelectionScreen({
    super.key,
    this.initial,
    this.mandatoryEnglish = true,
    this.availableSlugs = const <String>[],
  });

  /// Slug set already picked on the setup screen.
  final Set<String>? initial;

  /// Standard UTME Mock pins English; Custom Practice lets it go.
  final bool mandatoryEnglish;

  /// Bank slugs the manifest actually ships (empty = every catalogue
  /// subject shows).
  final List<String> availableSlugs;

  @override
  State<JambSubjectSelectionScreen> createState() =>
      _JambSubjectSelectionScreenState();
}

class _JambSubjectSelectionScreenState
    extends State<JambSubjectSelectionScreen> {
  static const int _maxSelections = 4;

  late final Set<String> _selected =
      widget.initial == null || widget.initial!.isEmpty
          ? <String>{'english', 'mathematics', 'physics', 'biology'}
          : Set<String>.of(widget.initial!);

  String _query = '';

  late final List<_PickableSubject> _subjects =
      _catalogue(widget.availableSlugs.toSet());

  int get _minimum => widget.mandatoryEnglish ? 2 : 1;

  bool selected(String id) => _selected.contains(id);

  void _toggle(String slug) {
    if (widget.mandatoryEnglish && slug == 'english') {
      return; // English is pinned for the standard mock
    }
    setState(() {
      if (selected(slug)) {
        if (_selected.length > _minimum) _selected.remove(slug);
      } else if (_selected.length < _maxSelections) {
        _selected.add(slug);
      }
    });
  }

  void _confirm() {
    if (_selected.length < _minimum) return;
    Navigator.of(context).pop(Set<String>.of(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final bool full = _selected.length >= _maxSelections;
    final bool valid = _selected.length >= _minimum;
    final double progress = _selected.length / _maxSelections;
    final String query = _query.trim().toLowerCase();
    final List<_PickableSubject> visible = query.isEmpty
        ? _subjects
        : _subjects
            .where((_PickableSubject s) =>
                s.name.toLowerCase().contains(query) ||
                s.slug.contains(query))
            .toList();

    return Scaffold(
      backgroundColor: context.cardLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top bar: back + title + spacer (Stitch layout) --------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: <Widget>[
                      _RoundBack(onBack: () => Navigator.of(context).pop()),
                      const Spacer(),
                      Text('Subject Selection',
                          style: RenanceText.displayMd.copyWith(fontSize: 20)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: <Widget>[
                      // Requirements card --------------------------------
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33141C2D),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'JAMB REQUIREMENTS',
                                        style: RenanceText.overline
                                            .copyWith(color: context.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text.rich(
                                        TextSpan(
                                          children: <InlineSpan>[
                                            const TextSpan(text: 'Selected: '),
                                            TextSpan(
                                              text:
                                                  '${_selected.length}/$_maxSelections',
                                              style: RenanceText.displayMd
                                                  .copyWith(
                                                fontSize: 20,
                                                color: full
                                                    ? context.ink
                                                    : RenanceColors.emerald,
                                              ),
                                            ),
                                          ],
                                          style: RenanceText.displayMd
                                              .copyWith(fontSize: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.surfaceVariant,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.info_outline,
                                          size: 14,
                                          color: context.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                          widget.mandatoryEnglish
                                              ? 'English mandatory'
                                              : '1 - 4 subjects',
                                          style: RenanceText.labelMono
                                              .copyWith(
                                                  fontSize: 11,
                                                  color: RenanceColors
                                                      .textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 6,
                                child: Stack(
                                  children: <Widget>[
                                    ColoredBox(
                                      color: context.surfaceVariant,
                                      child: const SizedBox.expand(),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progress.clamp(0.0, 1.0),
                                      child: ColoredBox(
                                        color: full
                                            ? context.ink
                                            : RenanceColors.emerald,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Search -------------------------------------------
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextField(
                          onChanged: (String v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search subjects',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            filled: true,
                            fillColor: context.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      // Available Subjects header ------------------------
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('Available Subjects',
                                style: RenanceText.sectionTitle),
                            Text('Tap to select',
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary)),
                          ],
                        ),
                      ),
                      // Subject rows -------------------------------------
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No subject matches "$_query"',
                                style: RenanceText.bodySecondary.copyWith(
                                    color: context.textSecondary)),
                          ),
                        )
                      else
                        for (final _PickableSubject s in visible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SubjectTile(
                              subject: s,
                              selected: selected(s.slug),
                              mandatory:
                                  widget.mandatoryEnglish && s.slug == 'english',
                              dimmed: !selected(s.slug) &&
                                  full &&
                                  !(widget.mandatoryEnglish &&
                                      s.slug == 'english'),
                              onTap: () => _toggle(s.slug),
                            ),
                          ),
                    ],
                  ),
                ),
                // Sticky confirm bar ------------------------------------
                _StartBar(
                  enabled: valid,
                  onStart: _confirm,
                  label: widget.mandatoryEnglish
                      ? 'Confirm Subjects'
                      : 'Confirm Subjects',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 40px circular back button, surface-container fill (Stitch top bar).
class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBack,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, size: 20, color: context.ink),
        ),
      ),
    );
  }
}

/// One subject row: 48px icon tile, name, and the right-side check
/// circle. Selected = surface-container bg with the emerald 2px border;
/// mandatory English uses the black primary style.
class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.selected,
    required this.mandatory,
    required this.dimmed,
    required this.onTap,
  });

  final _PickableSubject subject;
  final bool selected;
  final bool mandatory;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tileColor = mandatory
        ? context.ink
        : selected
            ? RenanceColors.emerald
            : context.surfaceContainer;
    final Color tileIconColor =
        (mandatory || selected) ? Colors.white : context.textSecondary;
    final Color borderColor = mandatory
        ? context.ink
        : selected
            ? RenanceColors.emerald
            : Colors.transparent;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Material(
        color: selected || mandatory ? context.surfaceContainer : context.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(subject.icon, size: 24, color: tileIconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(subject.name,
                          style: RenanceText.bodyMedium.copyWith(
                              fontSize: 16, color: context.ink)),
                      const SizedBox(height: 2),
                      if (mandatory)
                        Row(
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: RenanceColors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Mandatory',
                                style: RenanceText.caption.copyWith(
                                    color: context.textSecondary)),
                          ],
                        ),
                    ],
                  ),
                ),
                _CheckCircle(filled: selected || mandatory, black: mandatory),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 24px round check: outline when empty; emerald with white check when
/// selected; black for the mandatory English row.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.filled, required this.black});

  final bool filled;
  final bool black;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? (black ? context.ink : RenanceColors.emerald)
            : Colors.transparent,
        border: filled
            ? null
            : Border.all(color: context.outlineLight),
      ),
      alignment: Alignment.center,
      child: filled
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : const SizedBox.shrink(),
    );
  }
}

/// Sticky confirm bar: 40% opacity until the selection is valid.
class _StartBar extends StatelessWidget {
  const _StartBar({required this.enabled, required this.onStart, required this.label});

  final bool enabled;
  final VoidCallback onStart;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x00F9F9FF),
            Color(0xE6F9F9FF),
            Color(0xFFF9F9FF),
          ],
          stops: <double>[0.0, 0.4, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.inverseChip,
                borderRadius: BorderRadius.circular(10),
                boxShadow: enabled
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: TextButton(
                onPressed: enabled ? onStart : null,
                style: TextButton.styleFrom(
                  foregroundColor: context.onInverseChip,
                  disabledForegroundColor:
                      context.onInverseChip.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.rocket_launch, size: 20),
                    const SizedBox(width: 8),
                    Text(label,
                        style: RenanceText.bodyMedium
                            .copyWith(color: context.onInverseChip)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
