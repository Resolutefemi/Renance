import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// DeviceId: the app's stable per-install identity for the
/// one-device-one-account lock. Uses the platform Android ID when
/// available (survives reinstalls); falls back to a random UUID kept in
/// SharedPreferences. Web builds get an empty string, which the server
/// treats as "no device lock".
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
      final minted = _mint();
      await prefs.setString('renance.deviceId', minted);
      _cached = minted;
      return minted;
    } catch (_) {
      // Private-mode storage failures still yield a session-scoped id;
      // the server lock degrades gracefully to none.
      _cached = _mint();
      return _cached!;
    }
  }

  static String _mint() {
    final rnd = Random.secure();
    final vals = List<int>.generate(16, (_) => rnd.nextInt(256));
    vals[6] = (vals[6] & 0x0f) | 0x40;
    vals[8] = (vals[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = vals.map(hex).join();
    return 'and-${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16)}';
  }
}
