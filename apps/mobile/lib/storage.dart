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

/// A flashcard grade waiting to reach the server (offline queue entry).
class PendingCardGrade {
  const PendingCardGrade({
    required this.id,
    required this.cardId,
    required this.deckCode,
    required this.grade,
    required this.createdAt,
  });

  final String id; // unique queue key
  final String cardId;
  final String deckCode;
  final String grade; // again | hard | good
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cardId': cardId,
        'deckCode': deckCode,
        'grade': grade,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory PendingCardGrade.fromJson(Map<String, dynamic> j) =>
      PendingCardGrade(
        id: (j['id'] ?? '') as String,
        cardId: (j['cardId'] ?? '') as String,
        deckCode: (j['deckCode'] ?? '') as String,
        grade: (j['grade'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] ?? 0) as int),
      );
}

// --------------------------------------------------------------- pack store

abstract class PackStore {
  Future<void> savePack(Bundle bundle, String sha);
  Future<Bundle?> loadPack(String code, String sha);
  Future<Set<String>> downloadedCodes();

  /// On-device footprint per pack code (bytes) for the storage meter.
  Future<Map<String, int>> packSizes();

  /// Removes one downloaded pack (Downloads screen swipe/delete).
  Future<void> removePack(String code);

  /// Drops every downloaded pack (Settings → storage).
  Future<void> clearPacks();

  Future<void> queueSubmission(PendingSubmission submission);
  Future<List<PendingSubmission>> pendingSubmissions();
  Future<void> removeSubmission(String id);

  // ---- flashcards (ROADMAP #7): offline deck cache + progress + queue ----

  /// Caches the deck list for offline browsing.
  Future<void> saveDeckMetas(List<FlashcardDeckMeta> decks);
  Future<List<FlashcardDeckMeta>> cachedDeckMetas();

  /// Caches one full deck (cards included) for offline voice study.
  Future<void> saveDeck(FlashcardDeck deck);
  Future<FlashcardDeck?> loadDeck(String code);

  /// Local mirror of the server's Leitner state (optimistic UI + offline).
  Future<void> saveCardProgress(List<CardProgress> rows);
  Future<List<CardProgress>> loadCardProgress();

  /// Offline grades queue — flushed FIFO by SyncController.retryPending.
  Future<void> queueCardGrade(PendingCardGrade grade);
  Future<List<PendingCardGrade>> pendingCardGrades();
  Future<void> removeCardGrade(String id);
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

  static const _cardTables = [
    '''
    CREATE TABLE flashcard_decks (
      code TEXT PRIMARY KEY,
      json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE card_progress_cache (
      card_id TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE pending_card_grades (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''',
  ];

  static Future<Database> _defaultOpen() async => openDatabase(
        p.join(await getDatabasesPath(), 'renance.db'),
        version: 2,
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
          for (final ddl in _cardTables) {
            await db.execute(ddl);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            for (final ddl in _cardTables) {
              await db.execute(ddl);
            }
          }
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
  Future<Map<String, int>> packSizes() async {
    final db = await _open();
    final rows = await db.query('packs',
        columns: <String>['code', 'json']);
    return <String, int>{
      for (final r in rows)
        r['code']! as String: (r['json']! as String).length,
    };
  }

  @override
  Future<void> removePack(String code) async {
    final db = await _open();
    await db.delete('packs', where: 'code = ?', whereArgs: <Object?>[code]);
  }

  @override
  Future<void> clearPacks() async {
    final db = await _open();
    await db.delete('packs');
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

  @override
  Future<void> saveDeckMetas(List<FlashcardDeckMeta> decks) async {
    final db = await _open();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in decks) {
      batch.insert(
        'flashcard_decks',
        <String, Object?>{
          'code': d.code,
          'json': jsonEncode(d.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<FlashcardDeckMeta>> cachedDeckMetas() async {
    final db = await _open();
    final rows = await db.query('flashcard_decks', orderBy: 'code ASC');
    return rows
        .map((r) => FlashcardDeckMeta.fromJson(
            (jsonDecode(r['json']! as String) as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> saveDeck(FlashcardDeck deck) async {
    final db = await _open();
    await db.insert(
      'flashcard_decks',
      <String, Object?>{
        'code': deck.code,
        'json': jsonEncode(deck.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<FlashcardDeck?> loadDeck(String code) async {
    final db = await _open();
    final rows = await db.query('flashcard_decks',
        where: 'code = ?', whereArgs: <Object?>[code], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return FlashcardDeck.fromJson(
          (jsonDecode(rows.first['json']! as String) as Map).cast<String, dynamic>());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveCardProgress(List<CardProgress> rows) async {
    final db = await _open();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      batch.insert(
        'card_progress_cache',
        <String, Object?>{
          'card_id': r.cardId,
          'payload': jsonEncode(r.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<CardProgress>> loadCardProgress() async {
    final db = await _open();
    final rows = await db.query('card_progress_cache');
    return rows
        .map((r) => CardProgress.fromJson(
            (jsonDecode(r['payload']! as String) as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> queueCardGrade(PendingCardGrade grade) async {
    final db = await _open();
    await db.insert(
      'pending_card_grades',
      <String, Object?>{
        'id': grade.id,
        'card_id': grade.cardId,
        'payload': jsonEncode(grade.toJson()),
        'created_at': grade.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<PendingCardGrade>> pendingCardGrades() async {
    final db = await _open();
    final rows =
        await db.query('pending_card_grades', orderBy: 'created_at ASC');
    return rows
        .map((r) => PendingCardGrade.fromJson(
            (jsonDecode(r['payload']! as String) as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> removeCardGrade(String id) async {
    final db = await _open();
    await db.delete('pending_card_grades',
        where: 'id = ?', whereArgs: <Object?>[id]);
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
  Future<Map<String, int>> packSizes() async => <String, int>{
        for (final e in _packs.entries) e.key: e.value.title.length * 128,
      };

  @override
  Future<void> removePack(String code) async => _packs.remove(code);

  @override
  Future<void> clearPacks() async => _packs.clear();

  @override
  Future<void> queueSubmission(PendingSubmission submission) async =>
      _pending[submission.id] = submission;

  @override
  Future<List<PendingSubmission>> pendingSubmissions() async =>
      _pending.values.toList();

  @override
  Future<void> removeSubmission(String id) async => _pending.remove(id);

  final Map<String, FlashcardDeck> _decks = <String, FlashcardDeck>{};
  final Map<String, CardProgress> _cardProgress = <String, CardProgress>{};
  final Map<String, PendingCardGrade> _pendingGrades =
      <String, PendingCardGrade>{};

  @override
  Future<void> saveDeckMetas(List<FlashcardDeckMeta> decks) async {
    for (final d in decks) {
      _decks[d.code] = FlashcardDeck(
        code: d.code,
        title: d.title,
        cardCount: d.cardCount,
        subject: d.subject,
        body: d.body,
        cards: const <FlashcardCard>[],
      );
    }
  }

  @override
  Future<List<FlashcardDeckMeta>> cachedDeckMetas() async =>
      _decks.values
          .map((d) => FlashcardDeckMeta(
                code: d.code,
                title: d.title,
                cardCount: d.cardCount,
                subject: d.subject,
                body: d.body,
              ))
          .toList();

  @override
  Future<void> saveDeck(FlashcardDeck deck) async =>
      _decks[deck.code] = deck;

  @override
  Future<FlashcardDeck?> loadDeck(String code) async => _decks[code];

  @override
  Future<void> saveCardProgress(List<CardProgress> rows) async {
    for (final r in rows) {
      _cardProgress[r.cardId] = r;
    }
  }

  @override
  Future<List<CardProgress>> loadCardProgress() async =>
      _cardProgress.values.toList();

  @override
  Future<void> queueCardGrade(PendingCardGrade grade) async =>
      _pendingGrades[grade.id] = grade;

  @override
  Future<List<PendingCardGrade>> pendingCardGrades() async =>
      _pendingGrades.values.toList();

  @override
  Future<void> removeCardGrade(String id) async => _pendingGrades.remove(id);
}
