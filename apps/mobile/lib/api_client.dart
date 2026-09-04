/// HTTP client for the Go study-api. The [http.Client] and token lookup are
/// injectable so tests can run against a MockClient with zero network.
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'models.dart';

/// The server answered with a defined error (400/401/404/409/...).
/// Treat as a PERMANENT decision — retrying will not help.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// No usable path to the server (offline, timeout, refused).
/// Treat as TRANSIENT — queue work and retry when connectivity returns.
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
  })  : _base = baseUrl.endsWith('/')
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
  }) async {
    final uri = Uri.parse('$_base$path');
    final http.Response res;
    try {
      final http.StreamedResponse streamed = await _client
          .send(http.Request(method, uri)
            ..headers.addAll(_headers())
            ..body = body == null ? '' : jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw NetworkException('No connection to Renance servers (${e.message})');
    } on http.ClientException catch (e) {
      throw NetworkException('Renance servers unreachable (${e.message})');
    } on TimeoutException {
      throw NetworkException('Renance servers timed out — try again');
    }
    final dynamic decoded;
    if (res.body.isEmpty) {
      decoded = null;
    } else {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        throw ApiException(res.statusCode, 'bad_response',
            'Server sent something we could not read');
      }
    }
    if (res.statusCode >= 400) {
      final err = (decoded as Map<dynamic, dynamic>?)?['error'] as Map<dynamic, dynamic>?;
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
    final data = await _send('POST', '/auth/register',
        body: <String, String>{'username': username, 'password': password},
        auth: false) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  Future<AuthTokens> login(String username, String password) async {
    final data = await _send('POST', '/auth/login',
        body: <String, String>{'username': username, 'password': password},
        auth: false) as Map<dynamic, dynamic>;
    return AuthTokens(
      token: (data['token'] ?? '') as String,
      user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  /// Exchanges a Google ID token (from google_sign_in) for a Renance
  /// session — the server verifies it against Google's JWKS and issues
  /// the same 12h JWT the credential flow returns.
  Future<AuthTokens> authWithGoogle(String idToken) async {
    final data = await _send('POST', '/auth/google',
        body: <String, String>{'credential': idToken},
        auth: false) as Map<dynamic, dynamic>;
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
    final data = await _send('PUT', '/me/profile', body: <String, dynamic>{
      'fullName': fullName,
      'institution': institution,
      'gradeLevel': gradeLevel,
      'exams': exams,
      if (targetYear != null) 'targetYear': targetYear,
    }) as Map<dynamic, dynamic>;
    return Profile.fromJson((data['profile'] as Map).cast<String, dynamic>());
  }

  // --------------------------------------------------------------- content

  Future<Manifest> manifest() async {
    final data = await _send('GET', '/manifest') as Map<dynamic, dynamic>;
    return Manifest.fromJson(data.cast<String, dynamic>());
  }

  Future<Bundle> bundle(String code) async {
    final data = await _send('GET', '/bundles/$code') as Map<dynamic, dynamic>;
    return Bundle.fromJson(data.cast<String, dynamic>());
  }

  // -------------------------------------------------------------- attempts

  /// Starts an attempt. [adaptive] asks the server to rank the paper
  /// weak-topic-first from the student's own review state (ROADMAP #5).
  Future<AttemptStarted> createAttempt(String code, {bool adaptive = false}) async {
    final data = await _send('POST', '/attempts',
        body: <String, dynamic>{
          'code': code,
          if (adaptive) 'adaptive': true,
        }) as Map<dynamic, dynamic>;
    return AttemptStarted.fromJson(data.cast<String, dynamic>());
  }

  /// Submits answers for grading. The engine grades asynchronously (202).
  Future<void> submit(
    String attemptId,
    Map<String, String> answers,
    int durationMs,
  ) async {
    await _send('POST', '/attempts/$attemptId/submit', body: <String, dynamic>{
      'answers': answers.entries
          .map((e) =>
              <String, String>{'questionId': e.key, 'selected': e.value})
          .toList(),
      'durationMs': durationMs,
    });
  }

  Future<AttemptView> attempt(String attemptId) async {
    final data = await _send('GET', '/attempts/$attemptId') as Map<dynamic, dynamic>;
    return AttemptView.fromJson(data.cast<String, dynamic>());
  }

  // ----------------------------------------------------------- gamification

  /// Streaks, XP and badge ledger. The server returns a zero state for a
  /// scholar with no graded attempts — never a 404.
  Future<GamificationSummary> gamification() async {
    final data = await _send('GET', '/me/gamification') as Map<dynamic, dynamic>;
    return GamificationSummary.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------ paper history

  /// The student's paper history, newest first. Feeds the launcher's
  /// recent-activity card, the review tab and completion metrics.
  Future<List<AttemptRow>> attempts() async {
    final data = await _send('GET', '/me/attempts') as Map<dynamic, dynamic>;
    return ((data['attempts'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            AttemptRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // --------------------------------------------------------- spaced repetition

  /// The SM-2 review queue: topics due today + upcoming + stats. The
  /// server returns empty lists for a scholar with no graded attempts —
  /// never a 404.
  Future<ReviewSummary> reviewQueue() async {
    final data = await _send('GET', '/me/review') as Map<dynamic, dynamic>;
    return ReviewSummary.fromJson(data.cast<String, dynamic>());
  }

  /// Per-question review of a graded paper: picks, correct letters and
  /// the explanations stored with the sealed keys. 409 until graded.
  Future<AttemptReview> attemptReview(String attemptId) async {
    final data =
        await _send('GET', '/attempts/$attemptId/review') as Map<dynamic, dynamic>;
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
}
