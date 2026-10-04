/// Offline attendance, Task MOB-SCHOOL (founder directive 2026-10-04):
/// "Attendance works offline too - student details saved on the mobile
/// app AND on the database, auto-sync when network returns."
///
/// Three pieces:
///  * [SchoolRosterCache] - the classes + per-class rosters + previously
///    loaded register days, cached on the device (SharedPreferences JSON)
///    so the register screen renders offline. The SERVER stays the source
///    of truth for the roster: the cache is only ever a read snapshot of
///    the last successful load.
///  * [SchoolAttendanceQueue] - the append-only queue of register sheets
///    saved while offline. One entry per class + day (the latest save of
///    a day replaces the earlier queued copy of that same day), each
///    stamped with the device id and marked synced:false. Flushing replays
///    each sheet through the normal save endpoint, so the server's
///    per-student upsert remains the merge point (attendance rows are
///    append-only with device id; roster authority never leaves the DB).
///  * [AttendanceAutoSync] - a connectivity_plus listener that fires the
///    flush callback the moment any usable connection returns.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// One day's register saved on the device while offline.
@immutable
class OfflineAttendanceSession {
  const OfflineAttendanceSession({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.day,
    required this.entries,
    required this.deviceId,
    required this.markedAt,
    this.synced = false,
  });

  /// Stable identity: school + class + day (a re-save of the same day
  /// replaces its queue entry instead of piling up duplicates).
  final String id;
  final String schoolId;
  final String classId;
  final String day; // YYYY-MM-DD
  final List<AttendanceEntryModel> entries;
  final String deviceId;
  final DateTime markedAt;
  final bool synced;

  static String buildId(String schoolId, String classId, String day) =>
      '$schoolId|$classId|$day';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'schoolId': schoolId,
        'classId': classId,
        'day': day,
        'entries': entries
            .map((AttendanceEntryModel e) => e.toJson())
            .toList(growable: false),
        'deviceId': deviceId,
        'markedAt': markedAt.toIso8601String(),
        'synced': synced,
      };

  factory OfflineAttendanceSession.fromJson(Map<String, dynamic> j) =>
      OfflineAttendanceSession(
        id: (j['id'] ?? '') as String,
        schoolId: (j['schoolId'] ?? '') as String,
        classId: (j['classId'] ?? '') as String,
        day: (j['day'] ?? '') as String,
        entries: ((j['entries'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => AttendanceEntryModel.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(growable: false),
        deviceId: (j['deviceId'] ?? '') as String,
        markedAt: DateTime.tryParse((j['markedAt'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        synced: (j['synced'] ?? false) as bool,
      );
}

/// The append-only offline queue (SharedPreferences JSON store).
class SchoolAttendanceQueue {
  SchoolAttendanceQueue._();

  static const String _kKey = 'renance.school.attendance.queue.v1';

  /// Every queued session, oldest first, synced ones included (they are
  /// pruned right after a successful flush).
  static List<OfflineAttendanceSession> load(SharedPreferences prefs) {
    final String? raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return <OfflineAttendanceSession>[];
    try {
      final List<dynamic> rows = jsonDecode(raw) as List<dynamic>;
      return rows
          .map((dynamic e) => OfflineAttendanceSession.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on FormatException {
      return <OfflineAttendanceSession>[];
    }
  }

  static Future<void> _save(SharedPreferences prefs,
      List<OfflineAttendanceSession> sessions) async {
    await prefs.setString(
      _kKey,
      jsonEncode(
          sessions.map((OfflineAttendanceSession s) => s.toJson()).toList()),
    );
  }

  /// Queues (or replaces) one day's register. Returns the pending count.
  static Future<int> enqueue(SharedPreferences prefs,
      OfflineAttendanceSession session) async {
    final List<OfflineAttendanceSession> all = load(prefs)
      ..removeWhere((OfflineAttendanceSession s) => s.id == session.id);
    all.add(session);
    await _save(prefs, all);
    return all.where((OfflineAttendanceSession s) => !s.synced).length;
  }

  /// The sheets still waiting for the network, oldest first.
  static List<OfflineAttendanceSession> pending(SharedPreferences prefs) =>
      load(prefs)
          .where((OfflineAttendanceSession s) => !s.synced)
          .toList(growable: false);

  /// Marks a sheet delivered (and prunes it - the server now owns it).
  static Future<void> markSynced(SharedPreferences prefs, String id) async {
    final List<OfflineAttendanceSession> all = load(prefs)
      ..removeWhere((OfflineAttendanceSession s) => s.id == id);
    await _save(prefs, all);
  }

  /// Drops a sheet permanently (server rejected it with a permanent
  /// decision, e.g. the teacher's assignment was revoked).
  static Future<void> remove(SharedPreferences prefs, String id) async {
    final List<OfflineAttendanceSession> all = load(prefs)
      ..removeWhere((OfflineAttendanceSession s) => s.id == id);
    await _save(prefs, all);
  }

  /// The queued sheet for one class + day, if the device holds one.
  static OfflineAttendanceSession? sessionFor(
          SharedPreferences prefs, String schoolId, String classId, String day) =>
      load(prefs)
          .where((OfflineAttendanceSession s) =>
              !s.synced &&
              s.schoolId == schoolId &&
              s.classId == classId &&
              s.day == day)
          .firstOrNull;
}

/// The device's read-only snapshot of the roster (classes + students per
/// class) and of previously loaded register days. Keyed per school.
class SchoolRosterCache {
  SchoolRosterCache._();

  static const String _kClassesKey = 'renance.school.roster.classes.v1';
  static const String _kStudentsKey = 'renance.school.roster.students.v1';
  static const String _kDayKey = 'renance.school.roster.days.v1';

  // ---- classes ----------------------------------------------------------

  static Future<void> cacheClasses(
      SharedPreferences prefs, String schoolId, List<SchoolClassInfo> classes) async {
    final Map<String, dynamic> all = _readMap(prefs, _kClassesKey);
    all[schoolId] = classes
        .map((SchoolClassInfo c) => <String, dynamic>{
              'id': c.id,
              'name': c.name,
              'level': c.level,
              'seq': c.seq,
            })
        .toList(growable: false);
    await _writeMap(prefs, _kClassesKey, all);
  }

  static List<SchoolClassInfo> cachedClasses(
          SharedPreferences prefs, String schoolId) {
    final Map<String, dynamic> all = _readMap(prefs, _kClassesKey);
    final dynamic rows = all[schoolId];
    if (rows is! List) return <SchoolClassInfo>[];
    return rows
        .map((dynamic e) =>
            SchoolClassInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  // ---- students per class -----------------------------------------------

  static Future<void> cacheStudents(SharedPreferences prefs, String schoolId,
      String classId, List<SchoolStudentModel> students) async {
    final Map<String, dynamic> all = _readMap(prefs, _kStudentsKey);
    all['$schoolId|$classId'] = students
        .map((SchoolStudentModel s) => s.toJson())
        .toList(growable: false);
    await _writeMap(prefs, _kStudentsKey, all);
  }

  static List<SchoolStudentModel> cachedStudents(
      SharedPreferences prefs, String schoolId, String classId) {
    final Map<String, dynamic> all = _readMap(prefs, _kStudentsKey);
    final dynamic rows = all['$schoolId|$classId'];
    if (rows is! List) return <SchoolStudentModel>[];
    return rows
        .map((dynamic e) => SchoolStudentModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  // ---- one loaded register day (the server copy) -------------------------

  static Future<void> cacheAttendanceDay(
      SharedPreferences prefs,
      String schoolId,
      String classId,
      String day,
      List<AttendanceEntryModel> entries) async {
    final Map<String, dynamic> all = _readMap(prefs, _kDayKey);
    all['$schoolId|$classId|$day'] = entries
        .map((AttendanceEntryModel e) => e.toJson())
        .toList(growable: false);
    await _writeMap(prefs, _kDayKey, all);
  }

  static List<AttendanceEntryModel> cachedAttendanceDay(
      SharedPreferences prefs, String schoolId, String classId, String day) {
    final Map<String, dynamic> all = _readMap(prefs, _kDayKey);
    final dynamic rows = all['$schoolId|$classId|$day'];
    if (rows is! List) return <AttendanceEntryModel>[];
    return rows
        .map((dynamic e) => AttendanceEntryModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  // ---- helpers -----------------------------------------------------------

  static Map<String, dynamic> _readMap(SharedPreferences prefs, String key) {
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeMap(
      SharedPreferences prefs, String key, Map<String, dynamic> map) async {
    await prefs.setString(key, jsonEncode(map));
  }
}

/// Listens for connectivity and fires the flush callback whenever any
/// usable connection appears. Re-entrant safe: a flush already in flight
/// swallows the next trigger.
class AttendanceAutoSync {
  AttendanceAutoSync({required this.flush});

  /// Replays every queued sheet. Returns how many synced.
  final Future<int> Function() flush;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _running = false;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.isEmpty || results.first == ConnectivityResult.none) {
          return;
        }
        tick();
      },
      onError: (Object _) {}, // never let a platform error kill the app
    );
  }

  /// One flush attempt (also callable from a "Sync now" button).
  Future<void> tick() async {
    if (_running) return;
    _running = true;
    try {
      final int synced = await flush();
      if (synced > 0) {
        debugPrint('School attendance auto-sync delivered $synced sheet(s)');
      }
    } catch (_) {
      // Transient: the next connectivity change tries again.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
