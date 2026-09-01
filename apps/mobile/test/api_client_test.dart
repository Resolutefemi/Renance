import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:renance/api_client.dart';
import 'package:renance/models.dart';

void main() {
  group('ApiClient against canned responses', () {
    test('register returns token + user', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async {
          expect(request.url.path, '/auth/register');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'token': 'jwt-abc',
              'user': <String, dynamic>{
                'id': 'u-1',
                'username': 'adaobi',
                'profileCompleted': false,
              },
            }),
            201,
          );
        }),
      );
      final AuthTokens res = await api.register('adaobi', 'password123');
      expect(res.token, 'jwt-abc');
      expect(res.user.profileCompleted, isFalse);
    });

    test('login 401 surfaces the server error code', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async => http.Response(
              jsonEncode(<String, dynamic>{
                'error': <String, String>{
                  'code': 'invalid_credentials',
                  'message': 'invalid username or password',
                },
              }),
              401,
            )),
      );
      await expectLater(
        api.login('adaobi', 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'status', 401)
              .having((ApiException e) => e.code, 'code', 'invalid_credentials'),
        ),
      );
    });

    test('manifest parses exams', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async {
          expect(request.headers['Authorization'], 'Bearer tok-1');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'version': 'era2-g1',
              'exams': <dynamic>[
                <String, dynamic>{
                  'code': 'jamb-biology-mock',
                  'title': 'JAMB Biology',
                  'questionCount': 15,
                  'totalMarks': 15,
                  'body': 'JAMB',
                  'bundleSha256': 'a' * 64,
                  'sizeBytes': 10,
                },
              ],
            }),
            200,
          );
        }),
        token: () => 'tok-1',
      );
      final Manifest m = await api.manifest();
      expect(m.exams.single.code, 'jamb-biology-mock');
      expect(m.exams.single.body, 'JAMB');
    });

    test('submit accepts 202 empty body', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async {
          expect(request.url.path, '/attempts/a-1/submit');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode(<String, dynamic>{'attemptId': 'a-1', 'status': 'grading'}),
            202,
          );
        }),
      );
      await api.submit('a-1', <String, String>{'q1': 'B'}, 95000);
    });

    test('attempt polls into a graded result', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async => http.Response(
              jsonEncode(<String, dynamic>{
                'attemptId': 'a-1',
                'code': 'jamb-english-mock',
                'status': 'graded',
                'result': <String, dynamic>{
                  'score': 12,
                  'total': 20,
                  'breakdown': <dynamic>[],
                },
              }),
              200,
            )),
      );
      final AttemptView v = await api.attempt('a-1');
      expect(v.status, 'graded');
      expect(v.result!.score, 12);
    });

    test('socket failure becomes NetworkException', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://fake',
        client: MockClient((http.Request request) async {
          throw const SocketException('offline');
        }),
      );
      await expectLater(
        api.manifest(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
