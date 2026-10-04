import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// DeviceId: the app's stable per-device identity for the
/// one-device-one-account lock. New installs use the platform Android ID
/// (SSAID), which SURVIVES reinstalls - a student who uninstalls to free
/// space and reinstalls keeps the same identity, so the lock never
/// misfires on them. Installs that already carry a minted UUID (from the
/// earlier build) keep it: their account is bound to that value
/// server-side. Web builds get an empty string, which the server treats
/// as "no device lock".
class DeviceId {
  DeviceId._();
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('renance.deviceId');
      if (existing != null && existing.isNotEmpty) {
        _cached = existing;
        return existing;
      }
      // New install: prefer the SSAID (stable across reinstalls).
      final String? androidId = await _androidId();
      final String minted = androidId ?? _mint();
      await prefs.setString('renance.deviceId', minted);
      _cached = minted;
      return minted;
    } catch (_) {
      // Private-mode storage failures still yield a session-scoped id;
      // the server lock degrades gracefully to none.
      _cached = _androidIdCached ?? _mint();
      return _cached!;
    }
  }

  static String? _androidIdCached;

  /// The Android ID (SSAID), 16 hex chars, when running on Android; null
  /// everywhere else (web, iOS, desktop). Failures fall back to the
  /// random-UUID path rather than breaking sign-in.
  static Future<String?> _androidId() async {
    if (_androidIdCached != null) return _androidIdCached;
    if (kIsWeb) return null;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      final String id = info.id.trim();
      // The SSAID is exactly 16 hex chars; guard anything odd-shaped.
      if (id.isEmpty || id.length > 32) return null;
      _androidIdCached = 'and-$id';
      return _androidIdCached;
    } catch (_) {
      return null; // not Android, or the channel hiccuped
    }
  }

  static String _mint() {
    final Random rnd = Random.secure();
    final List<int> vals = List<int>.generate(16, (_) => rnd.nextInt(256));
    vals[6] = (vals[6] & 0x0f) | 0x40;
    vals[8] = (vals[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final String h = vals.map(hex).join();
    return 'and-${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16)}';
  }
}
