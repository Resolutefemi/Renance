/// The GLOBAL tactile 3D enforcement layer - the theme-level twin of the
/// web's globals.css "TACTILE 3D PRESS SYSTEM" block.
///
/// Founder directive 2026-10-19 ("make everything on the mobile app 3D,
/// all the buttons, all the icons"): every stock Material button -
/// FilledButton, ElevatedButton, OutlinedButton, their .icon variants -
/// renders as a physical key with NO per-call-site work:
///
///  * a solid darker bottom edge (4px) extruded below the face,
///  * pressing sinks the label 2px while the edge collapses 4 -> 2,
///  * the edge derives color-mix(face 68%, black) from the LIVE token,
///    exactly the web's derivation, so the seed palette keeps working.
///
/// The recipe rides `ButtonStyle.backgroundBuilder`, which Flutter clips
/// to the button's own shape - the same border-box model the web's
/// `border-bottom: 4px` uses, so the ledge can never paint outside its
/// key. TextButton stays a styled text link (the web renders its text
/// actions flat: "See all", "Sync now", dialog cancels) - only FILLED
/// surfaces grow the extruded edge, exactly like the website.
library;

import 'package:flutter/material.dart';

import 'tactile.dart' show mixTowardBlack;
import 'theme.dart';

/// The web's key label: `.key-btn` is 13.5px w800, dashboard CTAs are
/// 14px w700-800; 14 w800 carries both across the app.
const double kKeyFontSize = 14;
const FontWeight kKeyWeight = FontWeight.w800;

/// The filled tactile key style - the theme default for FilledButton
/// and ElevatedButton (the web's `button.bg-primary` global rule).
///
/// [face]   - the button's background token (primary / macaw / error /
///            on-surface dark key...).
/// [onFace] - the label ink (white, or the seeded dark ink on green).
/// [edgeMix]- the web's color-mix percentage toward black (68 for
///            primary faces, 70-72 for macaw/error/on-surface).
ButtonStyle tactileFilledKeyStyle({
  required Color face,
  required Color onFace,
  double edgeMix = 0.68,
  BorderRadius radius = RenanceRadius.button,
  double height = 52,
  EdgeInsetsGeometry? padding,
  double fontSize = kKeyFontSize,
  FontWeight fontWeight = kKeyWeight,
}) {
  final edge = mixTowardBlack(face, edgeMix);
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(face),
    foregroundColor: WidgetStatePropertyAll<Color>(onFace),
    // No M3 elevation blur, no ripple wash - the sink IS the feedback
    // (the web's key-btn has no ripple either).
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: radius)),
    side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
    padding:
        WidgetStatePropertyAll<EdgeInsetsGeometry>(padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    minimumSize: WidgetStatePropertyAll<Size>(Size(64, height)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.center,
    textStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(
      fontFamily: 'Nunito',
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.0,
      color: onFace,
    )),
    backgroundBuilder: (BuildContext context, Set<WidgetState> states,
        Widget? child) {
      final pressed = states.contains(WidgetState.pressed);
      final disabled = states.contains(WidgetState.disabled);
      return _TactileKeyBackground(
        face: face,
        edge: edge,
        radius: radius,
        restingEdge: 4,
        pressed: pressed,
        disabled: disabled,
        child: child,
      );
    },
  );
}

/// The WHITE tactile key - the theme default for OutlinedButton (the
/// web's `.hero-cta-secondary` / `.key-btn.bg-card`): card face, 2px
/// swan outline, a hard 4px ledge derived from the outline token,
/// press sink like every other key.
ButtonStyle tactileWhiteKeyStyle({
  required Color face,
  required Color outline,
  required Color ink,
  BorderRadius radius = RenanceRadius.button,
  double height = 52,
  EdgeInsetsGeometry? padding,
  double fontSize = kKeyFontSize,
  FontWeight fontWeight = kKeyWeight,
}) {
  final edge = mixTowardBlack(outline, 0.78);
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(face),
    foregroundColor: WidgetStatePropertyAll<Color>(ink),
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: radius)),
    side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
    padding:
        WidgetStatePropertyAll<EdgeInsetsGeometry>(padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    minimumSize: WidgetStatePropertyAll<Size>(Size(64, height)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.center,
    textStyle: WidgetStatePropertyAll<TextStyle>(TextStyle(
      fontFamily: 'Nunito',
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.0,
      color: ink,
    )),
    backgroundBuilder: (BuildContext context, Set<WidgetState> states,
        Widget? child) {
      final pressed = states.contains(WidgetState.pressed);
      final disabled = states.contains(WidgetState.disabled);
      return _TactileKeyBackground(
        face: face,
        edge: edge,
        radius: radius,
        restingEdge: 4,
        pressed: pressed,
        disabled: disabled,
        outline: outline,
        child: child,
      );
    },
  );
}

/// The text-action style - the theme default for TextButton. The web
/// renders text actions flat ("See all", "Sync now", dialog closes) in
/// the small-text primary ink: `color-mix(primary 72%, #000)` on light,
/// lifted toward iguana on the dark canvas - never the raw bright seed.
ButtonStyle tactileTextActionStyle({
  required Color ink,
  required Color wash,
}) {
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll<Color>(ink),
    backgroundColor: const WidgetStatePropertyAll<Color?>(null),
    overlayColor: WidgetStatePropertyAll<Color>(wash),
    elevation: const WidgetStatePropertyAll<double>(0),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 36)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const WidgetStatePropertyAll<TextStyle>(TextStyle(
      fontFamily: 'Nunito',
      fontSize: kKeyFontSize,
      fontWeight: kKeyWeight,
      height: 1.0,
    )),
  );
}

/// The icon-key style - the theme default for IconButton: the web's
/// 36px squircle press chip (PageBar back, header bells: `h-9 w-9
/// rounded-xl hover:bg-polar`), 22px glyph, no M3 48px bloat.
ButtonStyle tactileIconKeyStyle({
  required Color ink,
  required Color wash,
}) {
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll<Color>(ink),
    overlayColor: WidgetStatePropertyAll<Color>(wash),
    fixedSize: const WidgetStatePropertyAll<Size>(Size(36, 36)),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(36, 36)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.all(6)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    iconSize: const WidgetStatePropertyAll<double>(22),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    textStyle: const WidgetStatePropertyAll<TextStyle>(TextStyle(
      fontFamily: 'Nunito',
      fontSize: kKeyFontSize,
      fontWeight: kKeyWeight,
      height: 1.0,
    )),
  );
}

/// The painted key body behind every themed filled/outlined button:
/// face plate, extruded bottom edge (4px resting -> 2px pressed), the
/// 2px press sink on the label, disabled 55% opacity (the web's
/// `.key-btn:disabled`), and the optional 2px outline for white keys.
class _TactileKeyBackground extends StatelessWidget {
  const _TactileKeyBackground({
    required this.face,
    required this.edge,
    required this.radius,
    required this.restingEdge,
    required this.pressed,
    required this.disabled,
    this.outline,
    this.child,
  });

  final Color face;
  final Color edge;
  final BorderRadius radius;
  final double restingEdge;
  final bool pressed;
  final bool disabled;
  final Color? outline;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double ledge = pressed ? 2 : restingEdge;
    Widget body = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // face plate
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: face,
              borderRadius: radius,
              border: outline == null
                  ? null
                  : Border.all(color: outline!, width: 2),
            ),
          ),
        ),
        // extruded bottom edge, clipped into the key's rounded corners.
        // On white keys it insets INSIDE the 2px outline instead of
        // painting over it.
        Positioned(
          left: outline == null ? 0 : 2,
          right: outline == null ? 0 : 2,
          bottom: outline == null ? 0 : 2,
          height: ledge,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: edge,
              borderRadius: BorderRadius.vertical(
                bottom: radius.bottomLeft,
              ),
            ),
          ),
        ),
        // the press sink: the label drops as the edge collapses
        if (pressed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: child,
          )
        else
          child!,
      ],
    );
    if (disabled) body = Opacity(opacity: 0.55, child: body);
    return body;
  }
}
