/// HTTP client for the Go study-api. The [http.Client] and token lookup are
/// injectable so tests can run against a MockClient with zero network.
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'learn_models.dart';
import 'models.dart';

/// The server answered with a defined error (400/401/404/409/...).
/// Treat as a PERMANENT decision, retrying will not help.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message, [this.body]);
  final int statusCode;
  final String code;
  final String message;

  /// The full decoded response payload when the server answered with one
  /// (error envelope included). The blocked login's 403 email_unverified
  /// carries the restricted session token + the signup address here, and
  /// the sign-in screen needs both to drive the verify screen.
  final Map<dynamic, dynamic>? body;

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
    // 60s floor (founder bugfix 2026-10-05, "Renance server timed out"):
    // the free-tier host sleeps when idle and the first caller eats the
    // wake-up - a 20s window kept timing out on perfectly good requests.
    Duration timeout = const Duration(seconds: 60),
    bool? retryOnTimeout,
  }) async {
    final uri = Uri.parse('$_base$path');
    // GETs are idempotent - on a wake-up timeout the host is almost
    // certainly up seconds later, so one quiet retry is free goodwill.
    // POSTs never auto-retry (a doubled submit can double-create); the
    // auth callers handle their own recovery instead.
    final bool shouldRetry = retryOnTimeout ?? method == 'GET';
    final int maxAttempts = shouldRetry ? 2 : 1;
    http.Response? res;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final http.StreamedResponse streamed = await _client
            .send(
              http.Request(method, uri)
                ..headers.addAll(_headers())
                ..body = body == null ? '' : jsonEncode(body),
            )
            .timeout(timeout);
        res = await http.Response.fromStream(streamed);
        break;
      } on SocketException {
        // Raw OS errors read "Failed host lookup: 'renance-api.onrender.com'"
        // - the API host must never leak into student-facing offline copy
        // (founder rule), so the raw message is dropped entirely.
        throw NetworkException(
          'No connection to Renance servers. Check your internet and try again.',
        );
      } on http.ClientException {
        throw NetworkException(
          'Renance servers are unreachable. Check your connection and try again.',
        );
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw NetworkException(
            'Renance servers took too long - they may be waking up. '
            'Give it a few seconds and try again.',
          );
        }
        // The wake-up ping happened; give the host a beat, then go again.
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    // Unreachable in practice: every path either assigns [res] and
    // breaks, or throws. The guard keeps the null-safety checker happy.
    if (res == null) {
      throw NetworkException(
        'Renance servers took too long - they may be waking up. '
        'Give it a few seconds and try again.',
      );
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
        decoded is Map<dynamic, dynamic> ? decoded : null,
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
    final Map<dynamic, dynamic> data;
    try {
      data = await _send(
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
        timeout: const Duration(seconds: 90),
      ) as Map<dynamic, dynamic>;
    } on NetworkException {
      // Founder bugfix 2026-10-05 ("Renance server timed out" then "email
      // already existed"): the first request can cross the wire, create
      // the account and mail the link, yet answer after the phone gave
      // up. Before showing any error, quietly try to SIGN IN with the
      // credentials just submitted - if the account landed, the signup
      // continues exactly where it should, no dead end, no 409 wall.
      final AuthTokens? recovered = await _recoverSignupSession(
        identifier: username,
        password: password,
        audience: 'students',
      );
      if (recovered != null) return recovered;
      rethrow;
    }
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// Wake-up recovery for a signup whose response never came back
  /// (founder bugfix 2026-10-05). Waits out the host wake-up, then
  /// attempts a sign-in with the credentials the signup just used.
  /// Returns the session when the account really landed (a restricted
  /// email-unverified session counts - the caller routes to the confirm
  /// screen), null when the account is NOT there (the caller shows the
  /// original network error and the student can simply retry).
  Future<AuthTokens?> _recoverSignupSession({
    required String identifier,
    required String password,
    required String audience,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    try {
      return await loginFull(
        identifier,
        password: password,
        audience: audience,
      );
    } on ApiException catch (e) {
      if (e.code == 'email_unverified' && e.body != null) {
        final String? token = e.body!['token'] as String?;
        final dynamic userRaw = e.body!['user'];
        if (token != null && token.isNotEmpty && userRaw is Map) {
          return AuthTokens(
            token: token,
            user: AppUser.fromJson(userRaw.cast<String, dynamic>()),
          );
        }
      }
      // invalid credentials / device lock / anything else: the signup
      // truly did not land - let the original error speak.
      return null;
    } on NetworkException {
      // The host is still not answering; the caller's original timeout
      // message is the honest one.
      return null;
    }
  }

  Future<AuthTokens> login(String username, String password) async {
    return loginFull(username, password: password);
  }

  /// Login with the app's device id: a device bound to another account
  /// is refused server-side (one device, one account). [audience] carries
  /// the tab the sign-in happened under ("students" / "schools"): the
  /// founder directive of 2026-10-02 keeps school workplace accounts and
  /// student accounts separate, server-side.
  ///
  /// Founder bugfix (2026-10-02, "password login broken for months"):
  /// the field accepts "Username or email", but the payload always rode
  /// the `username` key - so an EMAIL login (e.g. the founder's own
  /// ariyooluwafemi487@gmail.com) was looked up as a username and
  /// answered "invalid credentials" even with the right password. An
  /// email-shaped identifier now travels in the `email` field the
  /// server's email-first lookup reads (the web always did this).
  Future<AuthTokens> loginFull(
    String username, {
    required String password,
    String? deviceId,
    String? audience,
  }) async {
    final String identifier = username.trim();
    final bool looksLikeEmail = identifier.contains('@');
    final data = await _send(
      'POST',
      '/auth/login',
      body: <String, dynamic>{
        // Email-shaped identifiers ride the `email` key (the email-first
        // lookup); usernames keep the legacy `username` key.
        if (looksLikeEmail) 'email': identifier,
        if (!looksLikeEmail) 'username': identifier,
        'password': password,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        if (audience != null && audience.isNotEmpty) 'audience': audience,
      },
      auth: false,
      // A sign-in changes nothing server-side, so one quiet retry beats
      // a "timed out" wall when the free-tier host is mid-wake-up.
      retryOnTimeout: true,
      timeout: const Duration(seconds: 90),
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// Forgot password (founder directive, 2026-10-02): request a
  /// single-use reset link by email or username. The link opens the web
  /// reset page in any browser (the phone's included) - the response is
  /// uniform so accounts cannot be enumerated.
  Future<void> forgotPassword(String identifier) async {
    await _send(
      'POST',
      '/auth/forgot-password',
      body: <String, dynamic>{
        'identifier': identifier,
        'return': 'app',
      },
      auth: false,
    );
  }

  /// Exchanges a Google ID token (from google_sign_in) for a Renance
  /// session, the server verifies it against Google's JWKS and issues
  /// the same 12h JWT the credential flow returns. The device id rides
  /// along so the one-account-per-device lock covers Google sign-ins on
  /// the app too (empty = web-style, no lock).
  Future<AuthTokens> authWithGoogle(String idToken, {String? deviceId}) async {
    final data = await _send(
      'POST',
      '/auth/google',
      body: <String, dynamic>{
        'credential': idToken,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
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

  /// Re-issues the email confirmation mail for the signed-in account.
  /// The server keeps a one-minute cooldown between sends.
  Future<void> resendVerification() async {
    await _send('POST', '/auth/resend-verification', body: <String, dynamic>{});
  }

  /// Consumes the 6-digit email confirmation code (founder directive
  /// 2026-10-05, the mailed-link era is over): the student types the
  /// code from the mail into the verify screen and this posts it to
  /// /auth/verify-email. A wrong or expired code raises ApiException.
  Future<void> verifyEmail(String code) async {
    await _send(
      'POST',
      '/auth/verify-email',
      body: <String, dynamic>{'code': code},
    );
  }

  /// Account self-deletion (founder directive 2026-10-05): DELETE /me
  /// wipes the account and EVERY row tied to it server-side - profile,
  /// exam attempts and answers, results, sessions, streaks, awards,
  /// daily results, arena seats, school memberships, entitlements,
  /// payments, AI chats/memories/artifacts, password resets - inside
  /// study.purge_user(), one transaction, nothing left behind.
  Future<void> deleteAccount() async {
    await _send('DELETE', '/me');
  }

  /// Swaps a restricted (unverified-signup) session for a fully seated
  /// one: after the mailed link is consumed, /me reports emailVerified
  /// flipped true and this re-mints the stored token so the study
  /// surface opens without another sign-in. Still-unconfirmed accounts
  /// keep the 403 email_unverified.
  Future<AuthTokens> refreshSession() async {
    final data = await _send(
      'POST',
      '/auth/refresh',
      body: <String, dynamic>{},
    ) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// Wrong-email rescue: swaps the signup address for [email]. The old
  /// address is removed from the database and a fresh 6-digit
  /// confirmation code mails to the new inbox only; verification resets
  /// until the new code is consumed.
  Future<void> changeEmail(String email) async {
    await _send('POST', '/me/change-email',
        body: <String, dynamic>{'email': email, 'return': 'app'});
  }

  /// Saves the profile. [username] is the handle picked during
  /// onboarding (or renamed later) - the server echoes the refreshed
  /// identity back so the caller can update the stored session user
  /// without a second round-trip. Founder directive 2026-10-02: the app
  /// asks for the username right after signup, exactly like the web.
  Future<ProfileSaveResult> updateProfile({
    required String fullName,
    required String institution,
    required String gradeLevel,
    required List<String> exams,
    int? targetYear,
    String? username,
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
        if (username != null && username.isNotEmpty) 'username': username,
      },
    ) as Map<dynamic, dynamic>;
    return ProfileSaveResult(
      profile: Profile.fromJson(
          (data['profile'] as Map).cast<String, dynamic>()),
      user: data['user'] is Map
          ? AppUser.fromJson(
              (data['user'] as Map).cast<String, dynamic>())
          : null,
    );
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
        // INTEGER milliseconds, verbatim: the old `v.toDouble()` made
        // Dart emit "1956.0" style floats and the server's int64 map
        // 400'd every submission (founder screenshot bug, 2026-09-28).
        // Dart ints encode as JSON ints; the server also rounds any
        // legacy float a stale build sends (attempts.go float64 map).
        if (questionMs.isNotEmpty)
          'questionMs': Map<String, int>.from(questionMs),
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

  // -------------------------------------------------------------- leaderboard

  /// A focus ladder (GET /leaderboard/focus?focus=...). [focus] is
  /// "jamb" (ranked on the official UTME aggregate out of 400), "waec"
  /// or "neco" (ranked on best paper percentage). The caller's own row
  /// rides along as "me" even outside the top 25.
  Future<LeaderboardData> leaderboardFocus({required String focus}) async {
    final data = await _send(
      'GET',
      '/leaderboard/focus?focus=$focus',
    ) as Map<dynamic, dynamic>;
    return LeaderboardData.fromJson(data.cast<String, dynamic>());
  }

  /// The streak ladder (GET /leaderboard/streak): the students still
  /// showing up day after day, ranked by their current streak.
  Future<LeaderboardData> leaderboardStreak() async {
    final data =
        await _send('GET', '/leaderboard/streak') as Map<dynamic, dynamic>;
    return LeaderboardData.fromJson(data.cast<String, dynamic>());
  }

  /// The daily challenge board (GET /daily/{body}/leaderboard): today's
  /// one sprint, everyone worldwide, first-write-wins.
  Future<LeaderboardData> dailyLeaderboard({String body = 'jamb'}) async {
    final data = await _send(
      'GET',
      '/daily/${Uri.encodeComponent(body)}/leaderboard',
    ) as Map<dynamic, dynamic>;
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
  /// returns the session token. The device id rides along so the
  /// one-device-one-account rule covers school sign-ups too (founder
  /// directive 2026-10-02; dormant until the server's DEVICE_LOCK
  /// switch is set to true).
  Future<AuthTokens> schoolRegister({
    required String schoolName,
    required String schoolType,
    required String fullName,
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final Map<dynamic, dynamic> data;
    try {
      data = await _send(
        'POST',
        '/school/auth/register',
        body: <String, dynamic>{
          'schoolName': schoolName,
          'schoolType': schoolType,
          'fullName': fullName,
          'email': email,
          'password': password,
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        },
        auth: false,
        timeout: const Duration(seconds: 90),
      ) as Map<dynamic, dynamic>;
    } on NetworkException {
      // Same wake-up recovery as the student signup (founder bugfix
      // 2026-10-05): the school may exist on the server even though the
      // response never made it back - try signing in before erroring.
      final AuthTokens? recovered = await _recoverSignupSession(
        identifier: email,
        password: password,
        audience: 'schools',
      );
      if (recovered != null) return recovered;
      rethrow;
    }
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

  /// The class+subject pairs taught in the school (GET
  /// /school/class-subjects) - the same pair list the web portal's
  /// syllabus pickers are built from.
  Future<List<SchoolClassSubjectPair>> schoolClassSubjects(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/class-subjects?schoolId=${Uri.encodeComponent(schoolId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['pairs'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolClassSubjectPair.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// One class + subject's live syllabus from the database
  /// (GET /school/syllabus): every term with its scheme of work and
  /// topics. The mobile twin of the web portal's syllabus fetch - the
  /// syllabus tab reads the school's own work straight from online.
  Future<List<SchoolSyllabusTerm>> schoolSyllabus(
    String schoolId,
    String classId,
    String subjectId,
  ) async {
    final data = await _send(
      'GET',
      '/school/syllabus?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}'
      '&subjectId=${Uri.encodeComponent(subjectId)}',
      timeout: const Duration(seconds: 60),
    ) as Map<dynamic, dynamic>;
    final List<SchoolSyllabusTerm> terms = <SchoolSyllabusTerm>[
      for (final dynamic t in (data['terms'] ?? const <dynamic>[]) as List<dynamic>)
        SchoolSyllabusTerm.fromJson((t as Map).cast<String, dynamic>()),
    ]..sort((SchoolSyllabusTerm a, SchoolSyllabusTerm b) => a.term.compareTo(b.term));
    return terms;
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

  // ------------------------------------------- school staff + results (MOB-SCHOOL)

  /// The school's subjects (English Studies, Mathematics, ...) for the
  /// pickers and the score entry desk.
  Future<List<SchoolSubjectInfo>> schoolSubjects(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/subjects?schoolId=${Uri.encodeComponent(schoolId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['subjects'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolSubjectInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Every staff member of the school joined with the account identity
  /// (management only) - the Teachers screen list.
  Future<List<SchoolMemberSummaryModel>> schoolMembers(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/members?schoolId=${Uri.encodeComponent(schoolId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['members'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SchoolMemberSummaryModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The class+subject assignments. Teachers may only read their own
  /// (memberId must be their member id); management may read any member's.
  Future<List<SchoolAssignmentModel>> schoolAssignments(
      String schoolId, String memberId) async {
    final data = await _send(
      'GET',
      '/school/assignments?schoolId=${Uri.encodeComponent(schoolId)}'
      '&memberId=${Uri.encodeComponent(memberId)}',
    ) as Map<dynamic, dynamic>;
    return ((data['assignments'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SchoolAssignmentModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Management creates a teacher account (POST /school/teachers). The
  /// teacher signs in with the email + password under For Schools.
  Future<SchoolMemberSummaryModel> schoolCreateTeacher(
    String schoolId, {
    required String fullName,
    required String email,
    required String password,
    String staffCode = '',
  }) async {
    final data = await _send(
      'POST',
      '/school/teachers',
      body: <String, dynamic>{
        'schoolId': schoolId,
        'fullName': fullName,
        'email': email,
        'password': password,
        'staffCode': staffCode,
      },
    ) as Map<dynamic, dynamic>;
    final Map<String, dynamic> member =
        ((data['member'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>();
    return SchoolMemberSummaryModel.fromJson(<String, dynamic>{
      'member': member,
      'username': (data['username'] ?? '') as String,
      'email': email,
    });
  }

  /// Grants (or revokes) one teacher's right to a class+subject
  /// (POST /school/assignments, management only).
  Future<void> schoolSetAssignment(
    String schoolId, {
    required String memberId,
    required String classId,
    required String subjectId,
    required bool remove,
  }) async {
    await _send(
      'POST',
      '/school/assignments',
      body: <String, dynamic>{
        'schoolId': schoolId,
        'memberId': memberId,
        'classId': classId,
        'subjectId': subjectId,
        'remove': remove,
      },
    );
  }

  /// The class broadsheet grid: every student's report card row for one
  /// class + term (+ session). Teachers see what their assignment allows.
  Future<List<SchoolResultModel>> schoolResults(
    String schoolId, {
    required String classId,
    required int term,
    String session = '',
  }) async {
    final data = await _send(
      'GET',
      '/school/results?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}'
      '&term=$term&session=${Uri.encodeComponent(session)}',
    ) as Map<dynamic, dynamic>;
    return ((data['results'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SchoolResultModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// One student's full result sheet (school name + items + reports).
  Future<SchoolResultModel> schoolResultSheet(
    String schoolId, {
    required String studentId,
    required int term,
    String session = '',
  }) async {
    final data = await _send(
      'GET',
      '/school/result-sheet?schoolId=${Uri.encodeComponent(schoolId)}'
      '&studentId=${Uri.encodeComponent(studentId)}'
      '&term=$term&session=${Uri.encodeComponent(session)}',
    ) as Map<dynamic, dynamic>;
    return SchoolResultModel.fromJson(
        ((data['result'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// Fills one subject's scores for one student (PUT /school/result-item;
  /// CA1/CA2 max 20 each, exam max 60). Teachers only for their assigned
  /// class+subject; a finalized result is sealed.
  Future<SchoolResultItemModel> schoolSaveResultItem(
    String schoolId, {
    required String studentId,
    required String classId,
    required String subjectId,
    required int term,
    required String session,
    required num ca1,
    required num ca2,
    required num exam,
  }) async {
    final data = await _send(
      'PUT',
      '/school/result-item',
      body: <String, dynamic>{
        'schoolId': schoolId,
        'studentId': studentId,
        'classId': classId,
        'subjectId': subjectId,
        'term': term,
        'session': session,
        'ca1': ca1,
        'ca2': ca2,
        'exam': exam,
      },
    ) as Map<dynamic, dynamic>;
    return SchoolResultItemModel.fromJson(
        ((data['item'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// The issued ID cards ledger (management only on the server; teachers
  /// get the roster-built preview instead).
  Future<List<SchoolIdCardModel>> schoolIdCards(
    String schoolId, {
    String classId = '',
    String session = '',
  }) async {
    final data = await _send(
      'GET',
      '/school/id-cards?schoolId=${Uri.encodeComponent(schoolId)}'
      '&classId=${Uri.encodeComponent(classId)}'
      '&session=${Uri.encodeComponent(session)}',
    ) as Map<dynamic, dynamic>;
    return ((data['cards'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolIdCardModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Batch-issues cards for every active student in scope (management).
  Future<int> schoolIssueIdCards(
    String schoolId, {
    String classId = '',
    required String session,
  }) async {
    final data = await _send(
      'POST',
      '/school/id-cards',
      body: <String, dynamic>{
        'schoolId': schoolId,
        'classId': classId,
        'session': session,
      },
    ) as Map<dynamic, dynamic>;
    return ((data['issued'] ?? 0) as num).toInt();
  }

  /// The subscription summary (plan, expiry, trial countdown).
  Future<SchoolPlanModel> schoolPlan(String schoolId) async {
    final data = await _send(
      'GET',
      '/school/plan?schoolId=${Uri.encodeComponent(schoolId)}',
    ) as Map<dynamic, dynamic>;
    return SchoolPlanModel.fromJson(data.cast<String, dynamic>());
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

  // -------------------------------------------------- renance ai studio

  /// The corpus the AI is bridged into: exam banks + question count.
  Future<AiBridgeStats> aiBridgeStats() async {
    final data = await _send('GET', '/ai/bridge/stats')
        as Map<dynamic, dynamic>;
    return AiBridgeStats(
      exams: (data['exams'] ?? 0) as int,
      questions: (data['questions'] ?? 0) as int,
    );
  }

  /// The student's chat threads, newest first (folder optional).
  Future<List<AiStudioChat>> aiChats({String? folder}) async {
    final String q = (folder == null || folder.isEmpty)
        ? ''
        : '?folder=${Uri.encodeComponent(folder)}';
    final data = await _send('GET', '/ai/chats$q') as Map<dynamic, dynamic>;
    return ((data['chats'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            AiStudioChat.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Opens a thread (optionally named and parked in a folder).
  Future<AiStudioChat> aiCreateChat({String? title, String? folder}) async {
    final data = await _send(
      'POST',
      '/ai/chats',
      body: <String, dynamic>{
        if (title != null && title.isNotEmpty) 'title': title,
        if (folder != null && folder.isNotEmpty) 'folder': folder,
      },
    ) as Map<dynamic, dynamic>;
    return AiStudioChat.fromJson(
        ((data['chat'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// One thread with its full message history.
  Future<AiStudioChatThread> aiGetChat(String id) async {
    final data = await _send('GET', '/ai/chats/$id') as Map<dynamic, dynamic>;
    return AiStudioChatThread.fromJson(data.cast<String, dynamic>());
  }

  /// Renames and/or moves a thread between folders.
  Future<void> aiUpdateChat(String id, {String? title, String? folder}) =>
      _send('PATCH', '/ai/chats/$id', body: <String, dynamic>{
        if (title != null) 'title': title,
        if (folder != null) 'folder': folder,
      }).then((_) {});

  /// Deletes a thread and its messages.
  Future<void> aiDeleteChat(String id) =>
      _send('DELETE', '/ai/chats/$id').then((_) {});

  /// Folders with their thread counts.
  Future<List<AiStudioFolder>> aiFolders() async {
    final data = await _send('GET', '/ai/folders') as Map<dynamic, dynamic>;
    return ((data['folders'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            AiStudioFolder.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Sends one turn; the server persists both messages, grounds the
  /// reply on memories + the past-question bridge and returns the pair.
  Future<AiStudioChatTurn> aiSendMessage(String chatId, String content,
      {String? classSlug, String? subjectSlug}) async {
    final data = await _send(
      'POST',
      '/ai/chats/$chatId/messages',
      timeout: const Duration(seconds: 90),
      body: <String, dynamic>{
        'content': content,
        if (classSlug != null && classSlug.isNotEmpty) 'class': classSlug,
        if (subjectSlug != null && subjectSlug.isNotEmpty)
          'subject': subjectSlug,
      },
    ) as Map<dynamic, dynamic>;
    return AiStudioChatTurn.fromJson(data.cast<String, dynamic>());
  }

  /// The student's durable memories.
  Future<List<AiStudioMemory>> aiMemories() async {
    final data = await _send('GET', '/ai/memories') as Map<dynamic, dynamic>;
    return ((data['memories'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            AiStudioMemory.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Remembers one fact.
  Future<AiStudioMemory> aiAddMemory(String content) async {
    final data = await _send('POST', '/ai/memories',
        body: <String, String>{'content': content}) as Map<dynamic, dynamic>;
    return AiStudioMemory.fromJson(
        ((data['memory'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// Forgets one fact.
  Future<void> aiDeleteMemory(int id) =>
      _send('DELETE', '/ai/memories/$id').then((_) {});

  /// Generates a quiz, saved as a shareable artifact.
  Future<AiStudioArtifact> aiGenerateQuiz({
    String? title,
    required List<String> topics,
    required String difficulty,
    required int count,
    String? body,
  }) async =>
      _aiGenerate('/ai/quiz', <String, dynamic>{
        if (title != null && title.isNotEmpty) 'title': title,
        'topics': topics,
        'difficulty': difficulty,
        'count': count,
        if (body != null && body.isNotEmpty) 'body': body,
      });

  /// Generates a study note in the house template.
  Future<AiStudioArtifact> aiGenerateNote({
    required String topic,
    String? subject,
    String? classLevel,
    String template = 'detailed',
  }) async =>
      _aiGenerate('/ai/notes', <String, dynamic>{
        'topic': topic,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (classLevel != null && classLevel.isNotEmpty)
          'classLevel': classLevel,
        'template': template,
      });

  /// Saves any text (a chat reply) as a note artifact.
  Future<AiStudioArtifact> aiNoteFromText({
    required String title,
    required String content,
  }) async =>
      _aiGenerate('/ai/notes/from-text', <String, dynamic>{
        'title': title,
        'content': content,
      });

  /// Generates a Nigerian-format school lesson note.
  Future<AiStudioArtifact> aiGenerateLessonNote({
    required String subject,
    required String classLevel,
    required String topic,
    String term = 'First Term',
    int duration = 40,
  }) async =>
      _aiGenerate('/ai/lesson-note', <String, dynamic>{
        'subject': subject,
        'classLevel': classLevel,
        'topic': topic,
        'term': term,
        'duration': duration,
      });

  /// Generates a NotebookLM-style notebook.
  Future<AiStudioArtifact> aiGenerateNotebook({
    String? title,
    required String subject,
    String? classLevel,
    required List<String> topics,
  }) async =>
      _aiGenerate('/ai/notebook', <String, dynamic>{
        if (title != null && title.isNotEmpty) 'title': title,
        'subject': subject,
        if (classLevel != null && classLevel.isNotEmpty)
          'classLevel': classLevel,
        'topics': topics,
      });

  Future<AiStudioArtifact> _aiGenerate(
      String path, Map<String, dynamic> body) async {
    final data = await _send('POST', path,
        timeout: const Duration(seconds: 90), body: body) as Map<dynamic, dynamic>;
    return AiStudioArtifact.fromJson(
        ((data['artifact'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// The student's generated documents (kind optional).
  Future<List<AiStudioArtifact>> aiArtifacts({String? kind}) async {
    final String q = (kind == null || kind.isEmpty)
        ? ''
        : '?type=${Uri.encodeComponent(kind)}';
    final data = await _send('GET', '/ai/artifacts$q') as Map<dynamic, dynamic>;
    return ((data['artifacts'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            AiStudioArtifact.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// One artifact by id (the async-generation poll: the row starts
  /// pending and the document lands when the provider answers).
  Future<AiStudioArtifact> aiGetArtifact(String id) async {
    final data = await _send('GET', '/ai/artifacts/$id') as Map<dynamic, dynamic>;
    return AiStudioArtifact.fromJson(
        ((data['artifact'] ?? const <String, dynamic>{}) as Map)
            .cast<String, dynamic>());
  }

  /// Waits for a pending artifact until the document lands (or the
  /// error / the deadline does). Rethrows the generator's error text.
  Future<AiStudioArtifact> aiWaitForArtifact(AiStudioArtifact start,
      {int hintCount = 0}) async {
    // Large quizzes generate in server-side chunks (10 questions per
    // provider call), so the wait scales with the ordered count: a
    // 40-question paper gets ~5.5 minutes, a small one stays near two.
    int seconds = 90;
    if (start.kind == 'quiz') {
      final int n = hintCount > 0 ? hintCount : 10;
      seconds = (45 + n * 7).clamp(90, 340);
    }
    final DateTime deadline = DateTime.now().add(Duration(seconds: seconds));
    AiStudioArtifact art = start;
    while (DateTime.now().isBefore(deadline)) {
      final bool pending = art.data['pending'] == true;
      if (!pending) {
        final Object? err = art.data['error'];
        if (err != null && err.toString().isNotEmpty) {
          throw ApiException(502, 'ai_failed', err.toString());
        }
        return art;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        art = await aiGetArtifact(art.id);
      } on Exception {
        // transient poll failure: keep waiting
      }
    }
    throw ApiException(
        504, 'generation_timeout', 'Still writing - open your documents in a moment, it lands there automatically.');
  }

  /// Deletes a document.
  Future<void> aiDeleteArtifact(String id) =>
      _send('DELETE', '/ai/artifacts/$id').then((_) {});

  /// (Re)issues a quiz's public share slug.
  Future<String> aiShareArtifact(String id) async {
    final data = await _send('POST', '/ai/artifacts/$id/share')
        as Map<dynamic, dynamic>;
    return (data['shareSlug'] ?? '') as String;
  }
  // -------------------------------------------------- learn & social parity
  // The web's Learn module (courses hub, lesson player, quests, league,
  // shop, chests) and social layer (feed, follows, public profiles),
  // field-for-field with apps/web/lib/learn.ts + lib/social.ts. Every
  // method here rides the same transport as the rest of the client.

  /// GET /learn/profile - the learner wallet (hearts, gems, streak,
  /// league, freeze count, daily goal).
  Future<LearnProfile> learnProfile() async {
    final dynamic data = await _send('GET', '/learn/profile');
    return LearnProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// PATCH /learn/profile - daily goal or the tertiary desk pair.
  Future<LearnProfile> learnPatchProfile({
    int? dailyGoal,
    String? institutionType,
    String? department,
    bool setDesk = false,
  }) async {
    final dynamic data = await _send(
      'PATCH',
      '/learn/profile',
      body: <String, dynamic>{
        if (dailyGoal != null) 'dailyGoal': dailyGoal,
        if (institutionType != null) 'institutionType': institutionType,
        if (department != null) 'department': department,
        if (setDesk) 'setDesk': true,
      },
    );
    return LearnProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/catalog - the browsable course catalog (paged).
  Future<(List<CatalogItem>, int)> learnCatalog({
    String body = '',
    String q = '',
    String faculty = '',
    String itype = '',
    int page = 1,
    int pageSize = 24,
  }) async {
    final Map<String, String> query = <String, String>{
      if (body.isNotEmpty) 'body': body,
      if (q.isNotEmpty) 'q': q,
      if (faculty.isNotEmpty) 'faculty': faculty,
      if (itype.isNotEmpty) 'itype': itype,
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final dynamic data = await _send('GET', '/learn/catalog?$query');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    final List<CatalogItem> items = ((j['items'] ?? const <dynamic>[])
            as List<dynamic>)
        .map((dynamic e) => CatalogItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (items, ((j['total'] ?? 0) as num).toInt());
  }

  /// GET /learn/my-courses - the desk's course list.
  Future<List<MyCourse>> learnMyCourses() async {
    final dynamic data = await _send('GET', '/learn/my-courses');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['courses'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => MyCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /learn/my-courses - replace the course list (checkbox saves).
  Future<bool> learnSetMyCourses(List<String> courseIds) async {
    final dynamic data = await _send(
      'POST',
      '/learn/my-courses',
      body: <String, dynamic>{'courseIds': courseIds},
      retryOnTimeout: false,
    );
    if (data is Map) return data['ok'] == true;
    return data != null;
  }

  /// GET /learn/courses/{id} - the PATH ladder document.
  Future<CoursePathModel> learnCoursePath(String courseId) async {
    final dynamic data = await _send('GET', '/learn/courses/$courseId');
    return CoursePathModel.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/topics/{id}/content - the lesson document, or null
  /// while the server is still writing it (the 202 generating state).
  Future<LessonDoc?> learnLessonContent(String topicId) async {
    final dynamic data = await _send('GET', '/learn/topics/$topicId/content');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    if (j['status'] == 'generating') return null;
    return LessonDoc.fromJson(j);
  }

  /// POST /learn/progress - bank a finished lesson run.
  Future<CompleteResult> learnProgress({
    required String topicId,
    required int correct,
    required int total,
    required int maxCombo,
    required List<String> mistakes,
    bool abandoned = false,
  }) async {
    final dynamic data = await _send(
      'POST',
      '/learn/progress',
      body: <String, dynamic>{
        'topicId': topicId,
        'correct': correct,
        'total': total,
        'maxCombo': maxCombo,
        'mistakes': mistakes,
        'abandoned': abandoned,
      },
    );
    return CompleteResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/quests - the daily/weekly/monthly challenge set.
  Future<QuestsResponse> learnQuests() async {
    final dynamic data = await _send('GET', '/learn/quests');
    return QuestsResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /learn/quests - claim one quest's gem reward.
  Future<int> learnClaimQuest(String questKey) async {
    final dynamic data = await _send(
      'POST',
      '/learn/quests',
      body: <String, dynamic>{'questKey': questKey},
    );
    return ((data as Map)['gems'] as num?)?.toInt() ?? 0;
  }

  /// GET /learn/shop - the gem shop.
  Future<ShopResponse> learnShop() async {
    final dynamic data = await _send('GET', '/learn/shop');
    return ShopResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /learn/shop - buy one item with gems.
  Future<ShopResponse> learnBuy(String item) async {
    final dynamic data = await _send(
      'POST',
      '/learn/shop',
      body: <String, dynamic>{'item': item},
      retryOnTimeout: false,
    );
    return ShopResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/leaderboard - one league tier's weekly board
  /// ([league] null = your own tier).
  Future<LeagueBoard> learnLeague({int? league}) async {
    final dynamic data = await _send(
      'GET',
      league == null ? '/learn/leaderboard' : '/learn/leaderboard?league=$league',
    );
    return LeagueBoard.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /learn/chests - open one unit chest.
  Future<ChestOpenResult> learnOpenChest(String chestKey) async {
    final dynamic data = await _send(
      'POST',
      '/learn/chests',
      body: <String, dynamic>{'chestKey': chestKey},
      retryOnTimeout: false,
    );
    return ChestOpenResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/course-desk - the tertiary semester shelves.
  Future<DeskShelves> learnCourseDesk() async {
    final dynamic data = await _send('GET', '/learn/course-desk');
    return DeskShelves.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/course-desk/others - borrowable courses, paged.
  Future<(List<DeskCourse>, int)> learnCourseDeskOthers({
    int offset = 0,
    int limit = 100,
  }) async {
    final dynamic data =
        await _send('GET', '/learn/course-desk/others?offset=$offset&limit=$limit');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    final List<DeskCourse> items = ((j['items'] ?? const <dynamic>[])
            as List<dynamic>)
        .map((dynamic e) => DeskCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (items, ((j['total'] ?? 0) as num).toInt());
  }

  /// GET /learn/search - desk search by code / title / topic.
  Future<List<DeskCourse>> learnSearch(String q) async {
    final dynamic data = await _send('GET', '/learn/search?q=${Uri.encodeQueryComponent(q)}');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['items'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => DeskCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /learn/ai-match - paste course titles, get grounded matches.
  ///
  /// Retry-hardened (founder report 2026-10-20: "the find my courses
  /// with ai is not working"): the pass is a pure READ (a catalogue
  /// search - nothing is written), so unlike other POSTs a silent
  /// second attempt is safe. Probed live: the endpoint answers 200 in
  /// 18-29s when warm, but the FIRST calls after the host wakes up
  /// were dying as bare 502s (empty body, ~30-38s) before settling.
  /// One quiet retry turns that wake-up churn into a win instead of a
  /// dead finder; 5xx and network faults retry, 4xx (auth, bad body)
  /// surfaces immediately.
  Future<List<AIMatchLine>> learnAiMatch(String text) async {
    const Duration pause = Duration(milliseconds: 1600);
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final dynamic data = await _send(
          'POST',
          '/learn/ai-match',
          body: <String, dynamic>{'text': text},
          timeout: const Duration(seconds: 90),
        );
        final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
        return ((j['lines'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                AIMatchLine.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } on ApiException catch (e) {
        final bool retryable = e.statusCode >= 500;
        if (retryable && attempt < 2) {
          await Future<void>.delayed(pause);
          continue;
        }
        rethrow;
      } on NetworkException {
        if (attempt < 2) {
          await Future<void>.delayed(pause);
          continue;
        }
        rethrow;
      }
    }
    // Unreachable: the loop returns or throws on every path.
    throw NetworkException(
      'Renance servers are unreachable. Check your connection and try again.',
    );
  }

  /// GET /learn/departments - the department list for an institution
  /// kind (University / Polytechnic / College of Education).
  Future<List<DeskDepartment>> learnDepartments(String itype) async {
    final dynamic data = await _send('GET', '/learn/departments?itype=$itype');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['departments'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => DeskDepartment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /learn/flags - report a broken lesson question.
  Future<bool> learnFlagQuestion({
    required String source,
    required String questionId,
    String courseCode = '',
    required String reason,
    String details = '',
  }) async {
    final dynamic data = await _send(
      'POST',
      '/learn/flags',
      body: <String, dynamic>{
        'source': source,
        'questionId': questionId,
        'courseCode': courseCode,
        'reason': reason,
        'details': details,
      },
      retryOnTimeout: false,
    );
    return data != null;
  }

  /// POST /learn/course-requests - "can't find my course".
  Future<bool> learnRequestCourse({
    required String institutionType,
    required String schoolName,
    String department = '',
    String code = '',
    String title = '',
    String topics = '',
  }) async {
    final dynamic data = await _send(
      'POST',
      '/learn/course-requests',
      body: <String, dynamic>{
        'institutionType': institutionType,
        'schoolName': schoolName,
        'department': department,
        'code': code,
        'title': title,
        'topics': topics,
      },
      retryOnTimeout: false,
    );
    return data != null;
  }

  /// GET /learn/practice - the mistakes practice set.
  Future<PracticeSet> learnPractice() async {
    final dynamic data = await _send('GET', '/learn/practice');
    return PracticeSet.fromJson((data as Map).cast<String, dynamic>());
  }

  /// POST /learn/practice - grade a practice run.
  Future<CompleteResult> learnSubmitPractice({
    required int correct,
    required int total,
    required List<String> resolvedIds,
  }) async {
    final dynamic data = await _send(
      'POST',
      '/learn/practice',
      body: <String, dynamic>{
        'correct': correct,
        'total': total,
        'resolvedIds': resolvedIds,
      },
    );
    return CompleteResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/review - the unit review set.
  Future<PracticeSet> learnReviewSet(String courseId, int unit) async {
    final dynamic data = await _send(
      'GET',
      '/learn/review?courseId=$courseId&unit=$unit',
    );
    return PracticeSet.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /learn/revision - the 50-question unit revision paper.
  Future<PracticeSet> learnRevisionSet(String courseId, int unit) async {
    final dynamic data = await _send(
      'GET',
      '/learn/revision?courseId=$courseId&unit=$unit',
    );
    return PracticeSet.fromJson((data as Map).cast<String, dynamic>());
  }

  // ---------------------------------------------------------------- social

  /// GET /social/feed - one page of the milestone feed.
  Future<List<SocialPost>> socialFeed({int? before, int limit = 25}) async {
    final dynamic data = await _send(
      'GET',
      '/social/feed?limit=$limit${before == null ? '' : '&before=$before'}',
    );
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['posts'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SocialPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /social/posts/{id}/like - toggle the heart.
  Future<(int, bool)> socialLike(int postId) async {
    final dynamic data = await _send('POST', '/social/posts/$postId/like');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return (((j['likes'] ?? 0) as num).toInt(), (j['liked'] ?? false) as bool);
  }

  /// GET /social/posts/{id}/comments - the thread, oldest first.
  Future<List<SocialComment>> socialComments(int postId) async {
    final dynamic data = await _send('GET', '/social/posts/$postId/comments');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['comments'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SocialComment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /social/posts/{id}/comments - add a comment (<= 300 chars).
  Future<List<SocialComment>> socialAddComment(int postId, String body) async {
    final dynamic data = await _send(
      'POST',
      '/social/posts/$postId/comments',
      body: <String, dynamic>{'body': body},
      retryOnTimeout: false,
    );
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    return ((j['comments'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SocialComment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /social/users/{username}/follow - toggle the follow edge.
  Future<bool> socialFollow(String username) async {
    final dynamic data =
        await _send('POST', '/social/users/$username/follow');
    return ((data as Map)['following'] ?? false) as bool;
  }

  /// GET /social/users/{username} - the public profile + posts.
  Future<(PublicProfile, List<SocialPost>)> socialPublicProfile(
    String username,
  ) async {
    final dynamic data = await _send('GET', '/social/users/$username');
    final Map<String, dynamic> j = (data as Map).cast<String, dynamic>();
    final PublicProfile profile = PublicProfile.fromJson(
      (j['profile'] as Map).cast<String, dynamic>(),
    );
    final List<SocialPost> posts = ((j['posts'] ?? const <dynamic>[])
            as List<dynamic>)
        .map((dynamic e) => SocialPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (profile, posts);
  }

  /// GET /social/connections - my followers + following.
  Future<SocialConnections> socialConnections() async {
    final dynamic data = await _send('GET', '/social/connections');
    return SocialConnections.fromJson((data as Map).cast<String, dynamic>());
  }

  /// GET /leaderboard/gems - the diamond board (7th leaderboard).
  Future<GemsLeaderboardData> leaderboardGems() async {
    final dynamic data = await _send('GET', '/leaderboard/gems');
    return GemsLeaderboardData.fromJson((data as Map).cast<String, dynamic>());
  }
}

/// Corpus size behind the AI bridge.
class AiBridgeStats {
  const AiBridgeStats({required this.exams, required this.questions});
  final int exams;
  final int questions;
}

/// One studio chat thread.
class AiStudioChat {
  const AiStudioChat({
    required this.id,
    required this.folder,
    required this.title,
    required this.updatedAt,
  });
  factory AiStudioChat.fromJson(Map<String, dynamic> j) => AiStudioChat(
        id: (j['id'] ?? '') as String,
        folder: (j['folder'] ?? 'General') as String,
        title: (j['title'] ?? 'New chat') as String,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ??
            DateTime.now(),
      );
  final String id;
  final String folder;
  final String title;
  final DateTime updatedAt;
}

/// A thread plus its messages.
class AiStudioChatThread {
  const AiStudioChatThread({required this.chat, required this.messages});
  factory AiStudioChatThread.fromJson(Map<String, dynamic> j) =>
      AiStudioChatThread(
        chat: AiStudioChat.fromJson(
            ((j['chat'] ?? const <String, dynamic>{}) as Map)
                .cast<String, dynamic>()),
        messages: ((j['messages'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => AiStudioMessage.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );
  final AiStudioChat chat;
  final List<AiStudioMessage> messages;
}

/// One persisted message turn.
class AiStudioMessage {
  const AiStudioMessage({
    required this.id,
    required this.role,
    required this.content,
    this.thinking,
    this.bridged = 0,
  });
  factory AiStudioMessage.fromJson(Map<String, dynamic> j) => AiStudioMessage(
        id: (j['id'] ?? 0) as int,
        role: (j['role'] ?? 'user') as String,
        content: (j['content'] ?? '') as String,
        thinking: j['thinking'] as String?,
        bridged: (j['bridged'] ?? 0) as int,
      );
  final int id;
  final String role; // user | assistant
  final String content;
  final String? thinking;
  final int bridged;
}

/// One turn exchange: the persisted pair + the phases to replay.
class AiStudioChatTurn {
  const AiStudioChatTurn({
    required this.userMessage,
    required this.assistantMessage,
    required this.mode,
    required this.bridged,
    this.memorySaved = false,
  });
  factory AiStudioChatTurn.fromJson(Map<String, dynamic> j) =>
      AiStudioChatTurn(
        userMessage: AiStudioMessage.fromJson(
            ((j['userMessage'] ?? const <String, dynamic>{}) as Map)
                .cast<String, dynamic>()),
        assistantMessage: AiStudioMessage.fromJson(
            ((j['assistantMessage'] ?? const <String, dynamic>{}) as Map)
                .cast<String, dynamic>()),
        mode: (j['mode'] ?? 'ai') as String,
        bridged: (j['bridged'] ?? 0) as int,
        memorySaved: (j['memorySaved'] ?? false) as bool,
      );
  final AiStudioMessage userMessage;
  final AiStudioMessage assistantMessage;
  final String mode;
  final int bridged;
  final bool memorySaved;
}

/// A folder with its thread count.
class AiStudioFolder {
  const AiStudioFolder({required this.name, required this.count});
  factory AiStudioFolder.fromJson(Map<String, dynamic> j) => AiStudioFolder(
        name: (j['name'] ?? 'General') as String,
        count: (j['count'] ?? 0) as int,
      );
  final String name;
  final int count;
}

/// One durable memory.
class AiStudioMemory {
  const AiStudioMemory({required this.id, required this.content});
  factory AiStudioMemory.fromJson(Map<String, dynamic> j) => AiStudioMemory(
        id: (j['id'] ?? 0) as int,
        content: (j['content'] ?? '') as String,
      );
  final int id;
  final String content;
}

/// One generated document (quiz | note | notebook | lesson_note).
class AiStudioArtifact {
  const AiStudioArtifact({
    required this.id,
    required this.kind,
    required this.title,
    required this.data,
    this.subject = '',
    this.classLevel = '',
    this.shareSlug = '',
  });
  factory AiStudioArtifact.fromJson(Map<String, dynamic> j) =>
      AiStudioArtifact(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? 'note') as String,
        title: (j['title'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        classLevel: (j['classLevel'] ?? '') as String,
        shareSlug: (j['shareSlug'] ?? '') as String,
        data: (j['data'] ?? const <String, dynamic>{}) as Map<dynamic, dynamic>,
      );
  final String id;
  final String kind; // quiz | note | notebook | lesson_note
  final String title;
  final String subject;
  final String classLevel;
  final String shareSlug;
  final Map<dynamic, dynamic> data;
}

/// One Renance AI exchange's answer.
class AiChatReply {
  const AiChatReply({required this.text, required this.mode});
  final String text;
  final String mode; // ai (the canned 'guide' mode was removed 2026-10-12)
}

/// The billing catalog (public): plans, redemption table, WhatsApp.
class PlanCatalog {
  const PlanCatalog({
    required this.plans,
    required this.redemptions,
    required this.paystackEnabled,
    required this.whatsapp,
    this.studentBillingEnabled = true,
  });

  final List<PremiumPlan> plans;
  final List<RenRedemption> redemptions;
  final bool paystackEnabled;
  final String whatsapp;
  /// False while the founder's "everyone rides premium for now" window
  /// is on: paywalls show the all-unlocked banner instead of buy buttons.
  final bool studentBillingEnabled;

  factory PlanCatalog.fromJson(Map<String, dynamic> j) => PlanCatalog(
        plans: ((j['plans'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => PremiumPlan.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        redemptions: ((j['redemptions'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => RenRedemption.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        paystackEnabled: (j['paystackEnabled'] ?? false) as bool,
        whatsapp: (j['whatsapp'] ?? '') as String,
        studentBillingEnabled: (j['studentBillingEnabled'] ?? true) as bool,
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
    this.scope = 'all',
    this.tier = 0,
    this.features = const <String>[],
  });

  final String code;
  final String label;
  final int amountNaira;
  final int durationDays;
  final String perks;
  /// "jamb" bounds the annual plan to JAMB papers; "all" opens every body.
  final String scope;
  /// Ladder rank: 1 jamb < 2 basic < 3 standard < 4 premium.
  final int tier;
  /// The per-tier bullet list the catalog owns.
  final List<String> features;

  factory PremiumPlan.fromJson(Map<String, dynamic> j) => PremiumPlan(
        code: (j['code'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        amountNaira: ((j['amountNaira'] ?? 0) as num).toInt(),
        durationDays: ((j['durationDays'] ?? 0) as num).toInt(),
        perks: (j['perks'] ?? '') as String,
        scope: (j['scope'] ?? 'all') as String,
        tier: ((j['tier'] ?? 0) as num).toInt(),
        features: ((j['features'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => e.toString())
            .toList(),
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
