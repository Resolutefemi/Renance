import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'ui/msymbols.dart';
import 'ui/tactile.dart';

/// UpdateGate - the founder's "no shared APKs" directive:
///
///   1. Play-store install check: if the app was NOT installed from
///      Google Play (sideloaded / shared APK / AAB extracted), it shows a
///      full-screen gate that sends the student to the Play Store listing
///      instead of opening Renance.
///   2. Force update: a lightweight version check against a version
///      endpoint; when the store build is newer than the running one, the
///      same gate appears until the student updates.
///
/// The channel methods live in MainActivity.kt (`renance/update`):
///   String getInstallSource()  -> package name of the store that
///                                 installed us ("" when sideloaded)
///   int getVersionCode()       -> the running build's versionCode
///
/// The version check honours the store gate's debug bypass: when the
/// founder builds with `--dart-define=RENANCE_BYPASS_UPDATE_GATE=true`
/// (CI / local testing), the gate never locks the app.
const String _kPlayStorePackage = 'com.android.vending';
const String _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=dev.renance.renance';

/// ANTI-SHARE GATE - master switch (founder directive 2026-10-05):
///
///   false  = the whole gate SLEEPS: sideloaded copies open normally,
///            testing is never disturbed. THIS IS THE CURRENT STATE
///            while Renance is not yet on the Play Store.
///   true   = the gate wakes up: shared/sideloaded APKs are sent to the
///            Play Store listing and outdated store builds are locked
///            behind the update screen.
///
/// FLIP TO TRUE THE DAY RENANCE GOES LIVE ON THE PLAY STORE - change
/// this one constant, rebuild, ship. (The old per-build bypass
/// --dart-define=RENANCE_BYPASS_UPDATE_GATE=true still works on top of
/// this for CI and local test runs.)
const bool kAntiShareGateEnabled = false;

// The version check hits the study API directly (renance.app/api/app-version
// is a Vercel rewrite to this same route, but the API host is the
// source of truth and answers even while a web deploy is mid-flight).
const String _kVersionEndpoint =
    'https://renance-api.onrender.com/app-version';
const bool _kBypass =
    bool.fromEnvironment('RENANCE_BYPASS_UPDATE_GATE', defaultValue: false);

enum GateVerdict { ok, notFromStore, outdated }

/// One startup check; cached for the session.
Future<GateVerdict> checkUpdateGate() async {
  if (_kBypass) return GateVerdict.ok;
  // Founder directive 2026-10-05: the anti-share gate is OFF until
  // Renance is live on the Play Store - every verdict is "ok" so a
  // sideloaded test build opens straight into the app.
  if (!kAntiShareGateEnabled) return GateVerdict.ok;
  if (!Platform.isAndroid) return GateVerdict.ok;
  String source = '';
  int versionCode = 0;
  try {
    source = await const MethodChannel('renance/update')
            .invokeMethod<String>('getInstallSource') ??
        '';
    versionCode =
        await const MethodChannel('renance/update').invokeMethod<int>('getVersionCode') ?? 0;
  } on PlatformException {
    // Channel missing (very old build / iOS): never lock the student out.
    return GateVerdict.ok;
  }
  if (source != _kPlayStorePackage) return GateVerdict.notFromStore;

  // Store build: compare against the published versionCode, fail open.
  try {
    final http.Response res = await http
        .get(Uri.parse(_kVersionEndpoint))
        .timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final dynamic body = jsonDecode(res.body);
      final int latest = (body is Map && body['versionCode'] is num)
          ? body['versionCode'].toInt()
          : 0;
      if (latest > versionCode) return GateVerdict.outdated;
    }
  } catch (_) {
    // Offline or endpoint cold: never brick the app on a failed check.
  }
  return GateVerdict.ok;
}

/// The blocking screen. No back-door: PopScope swallows the back button so
/// a shared copy cannot be nudged past the gate.
class UpdateGateScreen extends StatelessWidget {
  const UpdateGateScreen({super.key, required this.verdict});

  final GateVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final bool shared = verdict == GateVerdict.notFromStore;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 96,
                  width: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10DA11),
                    shape: BoxShape.circle,
                  ),
                  child: const MsIcon('school',
                      size: 46, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  shared
                      ? 'This copy of Renance was not installed from Google Play'
                      : 'A new version of Renance is live',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3C3C46),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  shared
                      ? 'Shared copies can be tampered with and miss the latest '
                          'questions, banks and security fixes. Install the '
                          'official Renance app from the Play Store - it takes '
                          'less than a minute and all your progress syncs.'
                      : 'Update to keep practising. New banks, faster screens and '
                          'important fixes are waiting on the Play Store.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF777777),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TactileButton(
                  face: const Color(0xFF10DA11),
                  onFace: Colors.white,
                  height: 52,
                  radius: BorderRadius.circular(14),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  onPressed: () => launchUrl(Uri.parse(_kPlayStoreUrl),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Get Renance on Google Play'),
                ),
                const SizedBox(height: 12),
                if (shared)
                  const Text(
                    'renance.app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF9AA7B4)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
