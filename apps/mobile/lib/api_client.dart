/// HTTP client for the Go study-api. The [http.Client] and token lookup are
/// injectable so tests can run against a MockClient with zero network.
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'models.dart';

/// The server answered with a defined error (400/401/404/409/...).
/// Treat as a PERMANENT decision, retrying will not help.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// No usable path to the server (offline, timeout, refused).
/// Treat as TRANSIENT, queue work and retry when connectivity returns.
class NetworkException implements Exception {
  NetworkException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    String? Function()? token,
  }) : _base = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client(),
       _token = token;

  final String _base;
  final http.Client _client;
  final String? Function()? _token;

  Map<String, String> _headers() {
    final t = _token?.call();
    return <String, String>{
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse('$_base$path');
    final http.Response res;
    try {
      final http.StreamedResponse streamed = await _client
          .send(
            http.Request(method, uri)
              ..headers.addAll(_headers())
              ..body = body == null ? '' : jsonEncode(body),
          )
          .timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw NetworkException('No connection to Renance servers (${e.message})');
    } on http.ClientException catch (e) {
      throw NetworkException('Renance servers unreachable (${e.message})');
    } on TimeoutException {
      throw NetworkException('Renance servers timed out, try again');
    }
    final dynamic decoded;
    if (res.body.isEmpty) {
      decoded = null;
    } else {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        throw ApiException(
          res.statusCode,
          'bad_response',
          'Server sent something we could not read',
        );
      }
    }
    if (res.statusCode >= 400) {
      final err =
          (decoded as Map<dynamic, dynamic>?)?['error']
              as Map<dynamic, dynamic>?;
      throw ApiException(
        res.statusCode,
        (err?['code'] ?? 'error').toString(),
        (err?['message'] ?? 'Request failed (${res.statusCode})').toString(),
      );
    }
    return decoded;
  }

  // ------------------------------------------------------------------ auth

  Future<AuthTokens> register(String username, String password) async {
    return registerFull(username, password: password);
  }

  /// Manual signup with the full payload: the app's device id (one
  /// device, one account) and where the confirmation mail should send
  /// the student back ("app").
  Future<AuthTokens> registerFull(
    String username, {
    required String password,
    String? email,
    String? deviceId,
    String? referral,
  }) async {
    final data = await _send(
      'POST',
      '/auth/register',
      body: <String, dynamic>{
        'username': username,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        'verifyReturn': 'app',
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        if (referral != null && referral.isNotEmpty) 'referral': referral,
      },
      auth: false,
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  Future<AuthTokens> login(String username, String password) async {
    return loginFull(username, password: password);
  }

  /// Login with the app's device id: a device bound to another account
  /// is refused server-side (one device, one account).
  Future<AuthTokens> loginFull(
    String username, {
    required String password,
    String? deviceId,
  }) async {
    final data = await _send(
      'POST',
      '/auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
      auth: false,
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// Exchanges a Google ID token (from google_sign_in) for a Renance
  /// session, the server verifies it against Google's JWKS and issues
  /// the same 12h JWT the credential flow returns.
  Future<AuthTokens> authWithGoogle(String idToken) async {
    final data = await _send(
      'POST',
      '/auth/google',
      body: <String, String>{'credential': idToken},
      auth: false,
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  Future<MeResult> me() async {
    final data = await _send('GET', '/me') as Map<dynamic, dynamic>;
    return MeResult.fromJson(data.cast<String, dynamic>());
  }

  Future<Profile> updateProfile({
    required String fullName,
    required String institution,
    required String gradeLevel,
    required List<String> exams,
    int? targetYear,
  }) async {
    final data = await _send(
      'PUT',
      '/me/profile',
      body: <String, dynamic>{
        'fullName': fullName,
        'institution': institution,
        'gradeLevel': gradeLevel,
        'exams': exams,
        if (targetYear != null) 'targetYear': targetYear,
      },
    ) as Map<dynamic, dynamic>;
    return Profile.fromJson((data['profile'] as Map).cast<String, dynamic>());
  }

  // --------------------------------------------------------------- content

  Future<Manifest> manifest() async {
    final data = await _send('GET', '/manifest') as Map<dynamic, dynamic>;
    return Manifest.fromJson(data.cast<String, dynamic>());
  }

  Future<Bundle> bundle(String code) async {
    // Multi-megabyte question banks over a Nigerian mobile connection
    // blow way past the 20s RPC budget - pack downloads get a patient
    // 120s window so 'download not working' stops being a timeout.
    final data = await _send(
      'GET',
      '/bundles/$code',
      timeout: const Duration(seconds: 120),
    ) as Map<dynamic, dynamic>;
    return Bundle.fromJson(data.cast<String, dynamic>());
  }

  /// Stores the daily CBT subject combination (PUT /me/daily-subjects).
  /// The server then composes every daily sprint from exactly these
  /// subjects, so the app and the web play the same paper.
  Future<void> setDailySubjects(List<String> subjects) async {
    await _send(
      'PUT',
      '/me/daily-subjects',
      body: <String, dynamic>{'subjects': subjects},
    );
  }

  /// The students currently in the arena (GET /arena/players): idle,
  /// online, each with their Ren Points. The lobby's Active Now list.
  Future<List<ArenaPlayer>> arenaPlayers() async {
    final data = await _send('GET', '/arena/players') as Map<dynamic, dynamic>;
    final List<dynamic> rows = (data['players'] as List<dynamic>?) ?? const [];
    return <ArenaPlayer>[
      for (final row in rows)
        ArenaPlayer.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  /// Today's daily challenge for one exam body (GET /daily/{body}).
  /// Returns the paper code + day; the tile opens it like any exam.
  Future<DailyInfo> daily(String body) async {
    final data = await _send(
      'GET',
      '/daily/${Uri.encodeComponent(body)}',
    ) as Map<dynamic, dynamic>;
    return DailyInfo.fromJson(data.cast<String, dynamic>());
  }

  // -------------------------------------------------------------- attempts

  /// Starts an attempt. [adaptive] asks the server to rank the paper
  /// weak-topic-first from the student's own review state (ROADMAP #5).
  Future<AttemptStarted> createAttempt(
    String code, {
    bool adaptive = false,
  }) async {
    final data = await _send(
      'POST',
      '/attempts',
      body: <String, dynamic>{'code': code, if (adaptive) 'adaptive': true},
    ) as Map<dynamic, dynamic>;
    return AttemptStarted.fromJson(data.cast<String, dynamic>());
  }

  /// Submits answers for grading. The engine grades asynchronously (202).
  /// questionMs is the per-question dwell map (pacing telemetry) that
  /// grading folds into the official UTME slip's time-used column.
  Future<void> submit(
    String attemptId,
    Map<String, String> answers,
    int durationMs, {
    Map<String, int> questionMs = const <String, int>{},
  }) async {
    await _send(
      'POST',
      '/attempts/$attemptId/submit',
      body: <String, dynamic>{
        'answers': answers.entries
            .map(
              (e) => <String, String>{'questionId': e.key, 'selected': e.value},
            )
            .toList(),
        'durationMs': durationMs,
        if (questionMs.isNotEmpty)
          'questionMs': questionMs.map((k, v) => MapEntry(k, v.toDouble())),
      },
    );
  }

  Future<AttemptView> attempt(String attemptId) async {
    final data =
        await _send('GET', '/attempts/$attemptId') as Map<dynamic, dynamic>;
    return AttemptView.fromJson(data.cast<String, dynamic>());
  }

  // ----------------------------------------------------------- gamification

  /// Streaks, XP and badge ledger. The server returns a zero state for a
  /// scholar with no graded attempts, never a 404.
  Future<GamificationSummary> gamification() async {
    final data =
        await _send('GET', '/me/gamification') as Map<dynamic, dynamic>;
    return GamificationSummary.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------ paper history

  /// The student's paper history, newest first. Feeds the launcher's
  /// recent-activity card, the review tab and completion metrics.
  Future<List<AttemptRow>> attempts() async {
    final data = await _send('GET', '/me/attempts') as Map<dynamic, dynamic>;
    return ((data['attempts'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              AttemptRow.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  // --------------------------------------------------------- spaced repetition

  /// The SM-2 review queue: topics due today + upcoming + stats. The
  /// server returns empty lists for a scholar with no graded attempts ,
  /// never a 404.
  Future<ReviewSummary> reviewQueue() async {
    final data = await _send('GET', '/me/review') as Map<dynamic, dynamic>;
    return ReviewSummary.fromJson(data.cast<String, dynamic>());
  }

  /// Per-question review of a graded paper: picks, correct letters and
  /// the explanations stored with the sealed keys. 409 until graded.
  Future<AttemptReview> attemptReview(String attemptId) async {
    final data = await _send(
      'GET',
      '/attempts/$attemptId/review',
    ) as Map<dynamic, dynamic>;
    return AttemptReview.fromJson(data.cast<String, dynamic>());
  }

  // ---------------------------------------------------------------- syllabus

  /// The syllabus map for one exam body ("jamb", "university-modules"…):
  /// the curriculum tree overlaid with the student's mastery state. 404
  /// for bodies with no shipped tree.
  Future<SyllabusTree> syllabus(String bodySlug) async {
    final data =
        await _send('GET', '/syllabus/$bodySlug') as Map<dynamic, dynamic>;
    return SyllabusTree.fromJson(data.cast<String, dynamic>());
  }

  // ---------------------------------------------------------------- fatigue

  /// Logs one sitting's telemetry (ROADMAP #6) and returns the server's
  /// fatigue signal, the same pure rule the app mirrors locally.
  Future<FatigueSignal> logSession({
    required String startedAt,
    String? endedAt,
    String? attemptId,
    String? code,
    int? durationMs,
    List<int> latenciesMs = const <int>[],
  }) async {
    final data = await _send(
      'POST',
      '/me/sessions',
      body: <String, dynamic>{
        'startedAt': startedAt,
        if (endedAt != null) 'endedAt': endedAt,
        if (attemptId != null && attemptId.isNotEmpty) 'attemptId': attemptId,
        if (code != null && code.isNotEmpty) 'code': code,
        if (durationMs != null) 'durationMs': durationMs,
        'latenciesMs': latenciesMs,
      },
    ) as Map<dynamic, dynamic>;
    return FatigueSignal.fromJson(
      ((data['fatigue'] ?? const <String, dynamic>{}) as Map)
          .cast<String, dynamic>(),
    );
  }

  /// The current take-a-break advisory (home banner state).
  Future<FatigueState> fatigue() async {
    final data = await _send('GET', '/me/fatigue') as Map<dynamic, dynamic>;
    return FatigueState.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------- flashcards

  /// Deck list (meta only, no cards).
  Future<List<FlashcardDeckMeta>> flashcardDecks() async {
    final data = await _send('GET', '/flashcards') as Map<dynamic, dynamic>;
    return ((data['decks'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              FlashcardDeckMeta.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// One deck with its full card stack.
  Future<FlashcardDeck> flashcardDeck(String code) async {
    final data =
        await _send('GET', '/flashcards/$code') as Map<dynamic, dynamic>;
    return FlashcardDeck.fromJson(data.cast<String, dynamic>());
  }

  /// The student's Leitner state for every card they have touched.
  Future<List<CardProgress>> cardProgress() async {
    final data =
        await _send('GET', '/me/cards/progress') as Map<dynamic, dynamic>;
    return ((data['progress'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              CardProgress.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  // ---------------------------------------------------------------- lessons

  /// Lesson list (meta only, ROADMAP #8).
  Future<List<LessonMeta>> lessons() async {
    final data = await _send('GET', '/lessons') as Map<dynamic, dynamic>;
    return ((data['lessons'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              LessonMeta.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  /// One lesson with its full sections.
  Future<Lesson> lesson(String slug) async {
    final data = await _send('GET', '/lessons/$slug') as Map<dynamic, dynamic>;
    return Lesson.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------------ career

  /// The curated career bridge (ROADMAP #18): scholarships + course
  /// paths, committed data boot-validated server-side, safe to cache.
  Future<CareerData> career() async {
    final data = await _send('GET', '/career') as Map<dynamic, dynamic>;
    return CareerData.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------------- tutor

  /// Whether an AI provider key is configured server-side. Without one,
  /// the tutor runs in deterministic technique-hint mode (ROADMAP #9).
  Future<bool> tutorAiEnabled() async {
    final data = await _send('GET', '/tutor/status') as Map<dynamic, dynamic>;
    return (data['aiEnabled'] ?? false) as bool;
  }

  /// One Socratic exchange anchored to a graded attempt + question. The
  /// server checks ownership and graded status before answering.
  Future<TutorReply> tutorChat({
    required String attemptId,
    required String questionId,
    required List<TutorTurn> messages,
  }) async {
    final data = await _send(
      'POST',
      '/attempts/$attemptId/tutor',
      body: <String, dynamic>{
        'questionId': questionId,
        'messages': messages.map((m) => m.toJson()).toList(),
      },
    ) as Map<dynamic, dynamic>;
    return TutorReply.fromJson(data.cast<String, dynamic>());
  }

  /// Batch-grades flashcards; returns the updated rows in input order.
  Future<List<CardProgress>> gradeCards(List<FlashcardGrade> grades) async {
    final data = await _send(
      'POST',
      '/me/cards/progress',
      body: <String, dynamic>{
        'grades': grades
            .map(
              (g) => <String, dynamic>{
                'cardId': g.cardId,
                'deckCode': g.deckCode,
                'grade': g.grade,
              },
            )
            .toList(),
      },
    ) as Map<dynamic, dynamic>;
    return ((data['progress'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              CardProgress.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  // -------------------------------------------------------------- leaderboard

  /// The all-time XP board (GET /leaderboard/xp). The caller's own row
  /// rides along as "me" even outside the top 25.
  Future<LeaderboardData> leaderboardXp() async {
    final data =
        await _send('GET', '/leaderboard/xp') as Map<dynamic, dynamic>;
    return LeaderboardData.fromJson(data.cast<String, dynamic>());
  }

  /// The arena standings (GET /leaderboard/arena); [period] is
  /// "week" (default) or "all".
  Future<LeaderboardData> leaderboardArena({String period = 'week'}) async {
    final data = await _send(
      'GET',
      '/leaderboard/arena?period=$period',
    ) as Map<dynamic, dynamic>;
    return LeaderboardData.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------- school platform

  /// School sign-up (For Schools): creates the account, the school and
  /// the management membership, seeds the Nigerian curriculum and
  /// returns the session token.
  Future<AuthTokens> schoolRegister({
    required String schoolName,
    required String schoolType,
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/school/auth/register',
      body: <String, String>{
        'schoolName': schoolName,
        'schoolType': schoolType,
        'fullName': fullName,
        'email': email,
        'password': password,
      },
      auth: false,
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// The caller's school memberships (management + teacher workspaces).
  Future<List<SchoolContextModel>> schoolMe() async {
    final data = await _send('GET', '/school/me') as Map<dynamic, dynamic>;
    return ((data['schools'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolContextModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The whole read-only school pack: classes, subjects and every
  /// syllabus with scheme of work + topics + notes. Same 120s patience
  /// as exam bundles - school packs can be megabytes of notes.
  Future<SchoolPack> schoolPack(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/pack/$schoolId',
      timeout: const Duration(seconds: 120),
    ) as Map<dynamic, dynamic>;
    return SchoolPack.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------- corpus

  /// The national curriculum corpus class list (Nursery 1 to SSS 3),
  /// read straight from the codebase files the API ships with. No
  /// Neon involvement: the corpus never lives in the database.
  Future<List<CorpusClassModel>> corpusClasses() async {
    final data = await _send('GET', '/school/corpus/classes') as Map<dynamic, dynamic>;
    return <CorpusClassModel>[
      for (final dynamic c in (data['classes'] ?? const <dynamic>[]) as List<dynamic>)
        CorpusClassModel.fromJson((c as Map).cast<String, dynamic>()),
    ];
  }

  /// Every term's scheme of work for one corpus class + subject.
  Future<List<CorpusSchemeTermModel>> corpusSchemes(
    String classId,
    String subject,
  ) async {
    final data = await _send(
      'GET',
      '/school/corpus/schemes/${Uri.encodeComponent(classId)}/${Uri.encodeComponent(subject)}',
      timeout: const Duration(seconds: 60),
    ) as Map<dynamic, dynamic>;
    return <CorpusSchemeTermModel>[
      for (final dynamic t in (data['terms'] ?? const <dynamic>[]) as List<dynamic>)
        CorpusSchemeTermModel.fromJson(((t as Map)['data'] as Map? ?? const <String, dynamic>{})
            .cast<String, dynamic>()),
    ]..sort((CorpusSchemeTermModel a, CorpusSchemeTermModel b) => a.term.compareTo(b.term));
  }

  /// Every term's lesson notes for one corpus class + subject.
  Future<List<CorpusNotesTermModel>> corpusNotes(
    String classId,
    String subject,
  ) async {
    final data = await _send(
      'GET',
      '/school/corpus/notes/${Uri.encodeComponent(classId)}/${Uri.encodeComponent(subject)}',
      timeout: const Duration(seconds: 60),
    ) as Map<dynamic, dynamic>;
    return <CorpusNotesTermModel>[
      for (final dynamic t in (data['terms'] ?? const <dynamic>[]) as List<dynamic>)
        CorpusNotesTermModel.fromJson(((t as Map)['data'] as Map? ?? const <String, dynamic>{})
            .cast<String, dynamic>()),
    ]..sort((CorpusNotesTermModel a, CorpusNotesTermModel b) => a.term.compareTo(b.term));
  }

  /// The school's classes (with enrolled counts) for the roster pickers.
  Future<List<SchoolClassInfo>> schoolClasses(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/classes?schoolId=${Uri.encodeComponent(schoolId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['classes'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolClassInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The enrolled students of one class (or the whole school). Any staff
  /// member may read the roster; writes stay management-only.
  Future<List<SchoolStudentModel>> schoolStudents(
    String schoolId, {
    String classId = '',
  }) async {
    final data = await _send(
      'GET',
      '/school/students?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['students'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolStudentModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Enroll one student with full details (management only).
  Future<SchoolStudentModel> schoolCreateStudent(
    String schoolId, {
    required String classId,
    required String fullName,
    required String admissionNo,
    required String sex,
    required String session,
    String dob = '',
    String guardianName = '',
    String guardianPhone = '',
    String address = '',
  }) async {
    final data = await _send(
      'POST',
      '/school/students?schoolId=${Uri.encodeComponent(schoolId)}',
      body: <String, dynamic>{
        'schoolId': schoolId,
        'classId': classId,
        'fullName': fullName,
        'admissionNo': admissionNo,
        'sex': sex,
        'session': session,
        'dob': dob,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'address': address,
      },
    ) as Map<dynamic, dynamic>;
    return SchoolStudentModel.fromJson(
        ((data['student'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// Edit one student's details (management only).
  Future<SchoolStudentModel> schoolUpdateStudent(
    String schoolId,
    SchoolStudentModel student,
  ) async {
    final data = await _send(
      'PUT',
      '/school/student?schoolId=${Uri.encodeComponent(schoolId)}',
      body: student.toJson(),
    ) as Map<dynamic, dynamic>;
    return SchoolStudentModel.fromJson(
        ((data['student'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// One day's register for a class: empty list = nothing marked yet.
  Future<List<AttendanceEntryModel>> attendanceDay(
    String schoolId,
    String classId,
    String day,
  ) async {
    final data = await _send(
      'GET',
      '/school/attendance?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}&day=${Uri.encodeComponent(day)}',
    ) as Map<dynamic, dynamic>;
    return ((data['entries'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => AttendanceEntryModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Save (or re-mark) a day's register. Management may mark any class;
  /// a teacher only the classes assigned to them.
  Future<int> saveAttendance(
    String schoolId,
    String classId,
    String day,
    List<AttendanceEntryModel> entries,
  ) async {
    final data = await _send(
      'POST',
      '/school/attendance?schoolId=${Uri.encodeComponent(schoolId)}',
      body: <String, dynamic>{
        'classId': classId,
        'day': day,
        'entries': entries.map((AttendanceEntryModel e) => e.toJson()).toList(),
      },
    ) as Map<dynamic, dynamic>;
    return (data['saved'] ?? 0) as int;
  }

  /// Attendance rates per student across a date window.
  Future<List<AttendanceSummaryRowModel>> attendanceSummary(
    String schoolId,
    String classId,
    String from,
    String to,
  ) async {
    final data = await _send(
      'GET',
      '/school/attendance-summary?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}'
      '&from=${Uri.encodeComponent(from)}&to=${Uri.encodeComponent(to)}',
    ) as Map<dynamic, dynamic>;
    return ((data['summary'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => AttendanceSummaryRowModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ------------------------------------------------------------ renance ai

  /// One Renance AI exchange: the whole visible history (up to 12 turns)
  /// plus optional school-corpus grounding (class + subject slugs).
  Future<AiChatReply> aiChat(
    List<Map<String, String>> messages, {
    String? classSlug,
    String? subjectSlug,
  }) async {
    final data = await _send(
      'POST',
      '/ai/chat',
      body: <String, dynamic>{
        'messages': messages,
        if (classSlug != null && classSlug.isNotEmpty) 'class': classSlug,
        if (subjectSlug != null && subjectSlug.isNotEmpty) 'subject': subjectSlug,
      },
    ) as Map<dynamic, dynamic>;
    return AiChatReply(
      text: (data['reply'] ?? '') as String,
      mode: (data['mode'] ?? 'ai') as String,
    );
  }

  // --------------------------------------------------------------- billing

  /// The plan catalog: premium tiers, REN redemption rates, whether
  /// Paystack is connected and the founder's WhatsApp line.
  Future<PlanCatalog> billingPlans() async {
    final data = await _send('GET', '/billing/plans', auth: false)
        as Map<dynamic, dynamic>;
    return PlanCatalog.fromJson(data.cast<String, dynamic>());
  }

  /// The signed-in student's entitlement (premium, coins, verification).
  Future<Entitlement> entitlement() async {
    final data = await _send('GET', '/me') as Map<dynamic, dynamic>;
    return Entitlement.fromJson(
        ((data['entitlement'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// Starts a Paystack charge; returns the hosted checkout URL. 503
  /// (paystack_unavailable) surfaces as an ApiException the paywall
  /// renders with the WhatsApp fallback.
  Future<String> initializePaystack(String plan) async {
    final data = await _send(
      'POST',
      '/billing/paystack/initialize',
      body: <String, String>{'plan': plan},
    ) as Map<dynamic, dynamic>;
    return (data['authorizationUrl'] ?? '') as String;
  }

  /// Exchanges REN coins for premium days; the refreshed entitlement
  /// rides back.
  Future<Entitlement> redeemCoins(String code) async {
    final data = await _send(
      'POST',
      '/billing/redeem',
      body: <String, String>{'code': code},
    ) as Map<dynamic, dynamic>;
    return Entitlement.fromJson(
        ((data['entitlement'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }
}

/// One Renance AI exchange's answer.
class AiChatReply {
  const AiChatReply({required this.text, required this.mode});
  final String text;
  final String mode; // ai | guide
}

/// The billing catalog (public): plans, redemption table, WhatsApp.
class PlanCatalog {
  const PlanCatalog({
    required this.plans,
    required this.redemptions,
    required this.paystackEnabled,
    required this.whatsapp,
  });

  final List<PremiumPlan> plans;
  final List<RenRedemption> redemptions;
  final bool paystackEnabled;
  final String whatsapp;

  factory PlanCatalog.fromJson(Map<String, dynamic> j) => PlanCatalog(
        plans: ((j['plans'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => PremiumPlan.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        redemptions: ((j['redemptions'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => RenRedemption.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        paystackEnabled: (j['paystackEnabled'] ?? false) as bool,
        whatsapp: (j['whatsapp'] ?? '') as String,
      );
}

/// One purchasable premium tier.
class PremiumPlan {
  const PremiumPlan({
    required this.code,
    required this.label,
    required this.amountNaira,
    required this.durationDays,
    required this.perks,
  });

  final String code;
  final String label;
  final int amountNaira;
  final int durationDays;
  final String perks;

  factory PremiumPlan.fromJson(Map<String, dynamic> j) => PremiumPlan(
        code: (j['code'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        amountNaira: ((j['amountNaira'] ?? 0) as num).toInt(),
        durationDays: ((j['durationDays'] ?? 0) as num).toInt(),
        perks: (j['perks'] ?? '') as String,
      );
}

/// One REN coin exchange rate.
class RenRedemption {
  const RenRedemption({
    required this.code,
    required this.label,
    required this.coins,
  });

  final String code;
  final String label;
  final int coins;

  factory RenRedemption.fromJson(Map<String, dynamic> j) => RenRedemption(
        code: (j['code'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        coins: ((j['coins'] ?? 0) as num).toInt(),
      );
}

/// One user's entitlement row: premium flag + type + expiry, the REN
/// wallet, and email verification. The Neon console shape.
class Entitlement {
  const Entitlement({
    required this.premiumRole,
    required this.premiumType,
    required this.premiumExpiresAt,
    required this.renCoins,
    required this.emailVerified,
  });

  final bool premiumRole;
  final String premiumType;
  final DateTime? premiumExpiresAt;
  final int renCoins;
  final bool emailVerified;

  /// Premium is live: role on, and the expiry (when stamped) still ahead.
  bool get premiumActive =>
      premiumRole &&
      (premiumExpiresAt == null || premiumExpiresAt!.isAfter(DateTime.now()));

  factory Entitlement.fromJson(Map<String, dynamic> j) => Entitlement(
        premiumRole: (j['premiumRole'] ?? false) as bool,
        premiumType: (j['premiumType'] ?? '') as String,
        premiumExpiresAt: j['premiumExpiresAt'] == null
            ? null
            : DateTime.tryParse(j['premiumExpiresAt'].toString()),
        renCoins: ((j['renCoins'] ?? 0) as num).toInt(),
        emailVerified: (j['emailVerified'] ?? false) as bool,
      );
}
