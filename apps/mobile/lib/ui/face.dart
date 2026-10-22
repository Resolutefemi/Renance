/// RenanceFace - one widget for every human face in the app (the
/// founder's 2026-10-22 identity pass, web parity with
/// components/person-avatar.tsx): an uploaded profile photo from R2
/// wins, then one of the 50 baked-in avatar SVGs, then the classic
/// initial letter. Used by the profile header, feed, search,
/// suggestions, leaderboard and public profiles so a photo set in one
/// place shows up everywhere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'learn_bits.dart' show avatarColorFor;

/// The asset path of one of the 50 baked-in avatars.
String avatarAsset(String key) => 'assets/avatars/$key.svg';

/// True when [key] names one of the baked-in avatars.
bool isAvatarKey(String? key) {
  if (key == null) return false;
  final RegExp k = RegExp(r'^avatar-\d{2}$');
  return k.hasMatch(key);
}

class RenanceFace extends StatelessWidget {
  const RenanceFace({
    super.key,
    this.name,
    this.username,
    this.avatar,
    this.photoUrl,
    this.size = 40,
    this.ring = false,
  });

  /// Display name / handle - the fallback letter and the colour seed.
  final String? name;
  final String? username;

  /// The baked-in avatar key ('avatar-01'..'avatar-50').
  final String? avatar;

  /// The ABSOLUTE URL of the uploaded R2 photo (wins over [avatar]).
  final String? photoUrl;

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final String seed = (name?.isNotEmpty == true ? name : username) ?? '?';
    final String initial = seed.isNotEmpty ? seed.substring(0, 1).toUpperCase() : '?';
    final String? src = photoUrl?.isNotEmpty == true ? photoUrl : null;
    final String? avatarKey = isAvatarKey(avatar) ? avatar : null;

    final Widget inner = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The deterministic initial-letter disc: always painted, so
            // a failed photo/asset load still leaves a face behind.
            ColoredBox(
              color: avatarColorFor(seed),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.42,
                  ),
                ),
              ),
            ),
            if (avatarKey != null)
              SvgPicture.asset(
                avatarAsset(avatarKey),
                fit: BoxFit.cover,
                semanticsLabel: name ?? 'avatar',
              ),
            if (src != null)
              Image.network(
                src,
                fit: BoxFit.cover,
                errorBuilder: (_, Object __, StackTrace? ___) =>
                    const SizedBox.shrink(),
                // The API host sleeps; a slow photo should not flash
                // the letter at every scroll pass.
                frameBuilder: (BuildContext c, Widget child, int? frame,
                        bool wasLoaded) =>
                    frame == null
                        ? Opacity(opacity: 0, child: child)
                        : AnimatedOpacity(
                            opacity: 1,
                            duration: const Duration(milliseconds: 150),
                            child: child,
                          ),
              ),
          ],
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring
            ? Border.all(
                width: 2,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: inner,
    );
  }
}
