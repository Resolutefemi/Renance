import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renance/ui/msymbols.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/storage.dart';
import 'package:renance/ui/auth_screens.dart';
import 'package:renance/ui/renance_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpAuth(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SessionStore session = SessionStore(await SharedPreferences.getInstance());
  final ApiClient api = ApiClient(
    baseUrl: 'http://fake',
    client: MockClient((http.Request request) async => http.Response(
        jsonEncode(<String, dynamic>{'error': <String, String>{'code': 'x'}}),
        500)),
  );
  final PackStore store = MemoryPackStore();
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ApiClient>.value(value: api),
        Provider<SessionStore>.value(value: session),
        Provider<PackStore>.value(value: store),
        ChangeNotifierProvider<SyncController>(
          create: (_) => SyncController(api: api, store: store),
        ),
        ChangeNotifierProvider<ExamController>(
          create: (_) => ExamController(api: api, store: store),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('RenanceMark animates without exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: RenanceMark(size: 48, busy: true))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('register captures email + password (current doctrine)',
      (WidgetTester tester) async {
    await _pumpAuth(tester, const RegisterScreen());
    // The email-only capture is the shipped doctrine: no username field,
    // the verify link mails to the address (registerFull).
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('login renders the mockup layout', (WidgetTester tester) async {
    await _pumpAuth(tester, const LoginScreen());
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    // The password toggle rides the site's own Material Symbols font
    // (MsIcon), not the stock Material Icons IconData.
    expect(
      find.byWidgetPredicate((Widget w) => w is MsIcon && w.name == 'visibility_off'),
      findsOneWidget,
    );
  });
}
