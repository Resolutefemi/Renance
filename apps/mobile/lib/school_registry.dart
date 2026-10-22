/// The school registry - the website's 1,108-school dataset bundled as
/// an asset (founder directive 2026-10-22: "there are up to 1000
/// schools a user can pick on the website", the mobile picker must
/// match). Slugs/short names/full names mirror
/// data/university/schools.json on the web, so a pick made on either
/// surface stays the same school.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One school row from the registry.
class SchoolEntry {
  const SchoolEntry({
    required this.slug,
    required this.short,
    required this.name,
    required this.type,
    required this.state,
    required this.live,
  });

  final String slug;
  final String short;
  final String name;

  /// university | polytechnic | college-of-education
  final String type;
  final String state;

  /// True when the school has a live course bank on the desk.
  final bool live;

  factory SchoolEntry.fromJson(Map<String, dynamic> j) => SchoolEntry(
        slug: (j['slug'] ?? '') as String,
        short: (j['short'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? 'university') as String,
        state: (j['state'] ?? '') as String,
        live: (j['live'] ?? false) as bool,
      );
}

class SchoolRegistry {
  SchoolRegistry._();

  static List<SchoolEntry>? _cache;

  /// Loads (once) and returns all 1,108 schools, website order.
  static Future<List<SchoolEntry>> all() async {
    final List<SchoolEntry>? cached = _cache;
    if (cached != null) return cached;
    try {
      final String raw = await rootBundle.loadString('assets/schools.json');
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      final List<SchoolEntry> list = ((j['schools'] ?? const <dynamic>[])
              as List<dynamic>)
          .map((dynamic e) =>
              SchoolEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _cache = list;
      return list;
    } catch (_) {
      // A broken asset must never brick the picker; the hand-written
      // desk map in university_screens.dart still works.
      _cache = const <SchoolEntry>[];
      return _cache!;
    }
  }

  /// Case-insensitive substring search over short + full name + state,
  /// ranked: prefix matches on the short code first, then live schools,
  /// then the rest - the website's findSchoolByName behaviour.
  static Future<List<SchoolEntry>> search(String query, {int limit = 60}) async {
    final String q = query.trim().toLowerCase();
    final List<SchoolEntry> schools = await all();
    if (q.isEmpty) {
      return schools.take(limit).toList();
    }
    final List<SchoolEntry> scored = <SchoolEntry>[];
    final List<SchoolEntry> weak = <SchoolEntry>[];
    for (final SchoolEntry s in schools) {
      final String short = s.short.toLowerCase();
      final String name = s.name.toLowerCase();
      final bool strong = short.startsWith(q) ||
          name.startsWith(q) ||
          short.contains(q) ||
          name.contains(q);
      final bool softer =
          strong || s.state.toLowerCase().contains(q) || s.type.contains(q);
      if (softer) {
        (strong ? scored : weak).add(s);
      }
    }
    int rank(SchoolEntry s) => s.live ? 0 : 1;
    scored.sort((SchoolEntry a, SchoolEntry b) => rank(a).compareTo(rank(b)));
    weak.sort((SchoolEntry a, SchoolEntry b) => rank(a).compareTo(rank(b)));
    return <SchoolEntry>[...scored, ...weak].take(limit).toList();
  }

  /// Looks one school up by exact slug (the stored pick key).
  static Future<SchoolEntry?> bySlug(String slug) async {
    final List<SchoolEntry> schools = await all();
    for (final SchoolEntry s in schools) {
      if (s.slug == slug) return s;
    }
    return null;
  }
}
