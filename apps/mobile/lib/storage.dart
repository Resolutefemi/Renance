/// Persistence for the offline-first mobile shell.
///
/// Session: JWT + cached user in SharedPreferences.
/// Packs:   downloaded bundles + queued submissions in local SQLite
///          (the ERA-2 doctrine: phone stores only what you downloaded,
///          and nothing here ever contains answer material).
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

// ---------------------------------------------------------------- session

class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kToken = 'renance.token';
  static const _kUser = 'renance.user';

  String? get token => _prefs.getString(_kToken);

  AppUser? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String token, AppUser user) async {
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }
}

// ------------------------------------------------------------- submissions

/// A completed exam waiting to be graded server-side (offline queue entry).
class PendingSubmission {
  const PendingSubmission({
    required this.id,
    required this.code,
    required this.attemptId,
    required this.answers,
    required this.durationMs,
    required this.createdAt,
  });

  final String id; // attemptId doubles as the queue key
  final String code;
  final String attemptId;
  final Map<String, String> answers;
  final int durationMs;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'attemptId': attemptId,
        'answers': answers,
        'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory PendingSubmission.fromJson(Map<String, dynamic> j) =>
      PendingSubmission(
        id: (j['id'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        attemptId: (j['attemptId'] ?? '') as String,
        answers: ((j['answers'] as Map<dynamic, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        durationMs: (j['durationMs'] ?? 0) as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] ?? 0) as int),
      );
}

// --------------------------------------------------------------- pack store

abstract class PackStore {
  Future<void> savePack(Bundle bundle, String sha);
  Future<Bundle?> loadPack(String code, String sha);
  Future<Set<String>> downloadedCodes();
  Future<void> queueSubmission(PendingSubmission submission);
  Future<List<PendingSubmission>> pendingSubmissions();
  Future<void> removeSubmission(String id);
}

/// Production implementation backed by sqflite.
class DbPackStore implements PackStore {
  DbPackStore({Future<Database> Function()? opener}) : _opener = opener;

  final Future<Database> Function()? _opener;
  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final open = _opener ?? _defaultOpen;
    final db = await open();
    _db = db;
    return db;
  }

  static Future<Database> _defaultOpen() async => openDatabase(
        p.join(await getDatabasesPath(), 'renance.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE packs (
              code TEXT PRIMARY KEY,
              sha TEXT NOT NULL,
              title TEXT NOT NULL,
              json TEXT NOT NULL,
              downloaded_at INTEGER NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE pending_submissions (
              attempt_id TEXT PRIMARY KEY,
              code TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )''');
        },
      );

  @override
  Future<void> savePack(Bundle bundle, String sha) async {
    final db = await _open();
    await db.insert(
      'packs',
      <String, Object?>{
        'code': bundle.code,
        'sha': sha,
        'title': bundle.title,
        'json': jsonEncode(bundle.toJson()),
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Bundle?> loadPack(String code, String sha) async {
    final db = await _open();
    final rows = await db.query('packs',
        where: 'code = ? AND sha = ?', whereArgs: <Object?>[code, sha], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return Bundle.fromJson(
          (jsonDecode(rows.first['json']! as String) as Map).cast<String, dynamic>());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Set<String>> downloadedCodes() async {
    final db = await _open();
    final rows = await db.query('packs', columns: <String>['code']);
    return rows.map((r) => r['code']! as String).toSet();
  }

  @override
  Future<void> queueSubmission(PendingSubmission submission) async {
    final db = await _open();
    await db.insert(
      'pending_submissions',
      <String, Object?>{
        'attempt_id': submission.attemptId,
        'code': submission.code,
        'payload': jsonEncode(submission.toJson()),
        'created_at': submission.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<PendingSubmission>> pendingSubmissions() async {
    final db = await _open();
    final rows = await db.query('pending_submissions', orderBy: 'created_at ASC');
    return rows
        .map((r) => PendingSubmission.fromJson(
            (jsonDecode(r['payload']! as String) as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> removeSubmission(String id) async {
    final db = await _open();
    await db
        .delete('pending_submissions', where: 'attempt_id = ?', whereArgs: <Object?>[id]);
  }
}

/// In-memory double for widget/controller tests.
class MemoryPackStore implements PackStore {
  final Map<String, Bundle> _packs = <String, Bundle>{};
  final Map<String, PendingSubmission> _pending = <String, PendingSubmission>{};

  @override
  Future<void> savePack(Bundle bundle, String sha) async =>
      _packs[bundle.code] = bundle;

  @override
  Future<Bundle?> loadPack(String code, String sha) async => _packs[code];

  @override
  Future<Set<String>> downloadedCodes() async => _packs.keys.toSet();

  @override
  Future<void> queueSubmission(PendingSubmission submission) async =>
      _pending[submission.id] = submission;

  @override
  Future<List<PendingSubmission>> pendingSubmissions() async =>
      _pending.values.toList();

  @override
  Future<void> removeSubmission(String id) async => _pending.remove(id);
}
