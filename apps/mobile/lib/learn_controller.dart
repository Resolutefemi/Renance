/// The Learn controller - the mobile twin of the web's useLearnStats
/// hook + the lesson completion celebration wiring.
///
/// Holds the learner wallet (gems, hearts, streak, freeze count,
/// league, daily goal), refreshes it from GET /learn/profile, caches it
/// in prefs (the web's localStorage `renance.learnStats`) so the header
/// chips render instantly on cold start, and exposes the actions the
/// shell needs: buying shop items, opening chests, claiming quests.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'learn_models.dart';

/// Storage key for the cached wallet (web parity: the same fields the
/// web's learn-stats hook persists in localStorage).
const String kLearnStatsKey = 'renance.learnStats';

class LearnController extends ChangeNotifier {
  LearnController({required this.api, required this.prefs});

  final ApiClient api;
  final SharedPreferences prefs;

  LearnProfile? _profile;
  bool _loading = false;

  /// The cached wallet; falls back to the web's offline defaults
  /// (hearts 5, unlimited on, league Bronze) so the header chips always
  /// render a sane value.
  LearnProfile get profile => _profile ?? LearnProfile.fallback;

  bool get loading => _loading;

  int get gems => profile.gems;
  int get hearts => profile.hearts;
  int get streak => profile.streak;
  int get freezeCount => profile.freezeCount;
  int get dailyGoal => profile.dailyGoal;
  String get league => profile.league;

  /// True when a wallet was loaded at least once this session.
  bool get hasProfile => _profile != null;

  Map<String, dynamic> _toJson(LearnProfile p) => <String, dynamic>{
    'hearts': p.hearts,
    'unlimitedHearts': p.unlimitedHearts,
    'gems': p.gems,
    'xp': p.xp,
    'streak': p.streak,
    'dailyGoal': p.dailyGoal,
    'todayXp': p.todayXp,
    'superActive': p.superActive,
    'boostActive': p.boostActive,
    'freezeCount': p.freezeCount,
    'league': p.league,
    'courseCount': p.courseCount,
    'topicsDone': p.topicsDone,
    'perfectCount': p.perfectCount,
    'institutionType': p.institutionType,
    'department': p.department,
    'departmentName': p.departmentName,
  };

  /// Cold-start cache read (no network): paints the header chips with
  /// the last known wallet while the first /learn/profile flies.
  void hydrate() {
    if (_profile != null) return;
    final String? raw = prefs.getString(kLearnStatsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        _profile = LearnProfile.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // A corrupt cache is dropped - the live fetch replaces it.
    }
  }

  /// Refresh the wallet from the server. Quiet: failures leave the
  /// cached value untouched (the web's hook behaves the same).
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final LearnProfile p = await api.learnProfile();
      _profile = p;
      _persist(p);
    } catch (_) {
      // Offline: keep the cached wallet.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _persist(LearnProfile p) {
    try {
      prefs.setString(kLearnStatsKey, jsonEncode(_toJson(p)));
    } catch (_) {
      // prefs write failures never break the app.
    }
  }

  /// Apply a wallet the server just handed back (lesson completion,
  /// shop purchase, chest open) without another round-trip.
  void apply(LearnProfile? p) {
    if (p == null) return;
    _profile = p;
    _persist(p);
    notifyListeners();
  }

  /// Patch fields on the wallet (daily goal changes, desk saves).
  Future<LearnProfile> patchProfile({
    int? dailyGoal,
    String? institutionType,
    String? department,
    bool setDesk = false,
  }) async {
    final LearnProfile p = await api.learnPatchProfile(
      dailyGoal: dailyGoal,
      institutionType: institutionType,
      department: department,
      setDesk: setDesk,
    );
    apply(p);
    return p;
  }

  /// Buy one shop item; returns the refreshed shop (wallet + items).
  Future<ShopResponse> buy(String item) async {
    final ShopResponse shop = await api.learnBuy(item);
    final Map<String, dynamic> j = _toJson(profile)
      ..['gems'] = shop.gems
      ..['hearts'] = shop.hearts;
    apply(LearnProfile.fromJson(j));
    return shop;
  }

  /// Open one unit chest; the result carries the gem payout.
  Future<ChestOpenResult> openChest(String chestKey) async {
    final ChestOpenResult res = await api.learnOpenChest(chestKey);
    final Map<String, dynamic> j = _toJson(profile)
      ..['gems'] = res.gemsTotal;
    apply(LearnProfile.fromJson(j));
    return res;
  }

  /// Claim one quest; returns the gems won.
  Future<int> claimQuest(String questKey) async {
    final int gems = await api.learnClaimQuest(questKey);
    if (gems > 0) {
      final Map<String, dynamic> j = _toJson(profile)
        ..['gems'] = profile.gems + gems;
      apply(LearnProfile.fromJson(j));
    }
    return gems;
  }
}
