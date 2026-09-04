import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'config.dart';
import 'controllers.dart';
import 'models.dart';
import 'storage.dart';
import 'ui/auth_screens.dart';
import 'ui/exam_screen.dart' show ExamScreen;
import 'ui/home_screen.dart';
import 'ui/splash_screen.dart' show SplashScreen;
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final SessionStore session = SessionStore(prefs);
  final ApiClient api = ApiClient(
    baseUrl: apiBaseUrl,
    token: () => session.token,
  );
  final PackStore store = DbPackStore();
  final ThemeController theme = ThemeController(prefs: prefs);

  runApp(RenanceApp(api: api, session: session, store: store, theme: theme));
}

class RenanceApp extends StatelessWidget {
  const RenanceApp({
    super.key,
    required this.api,
    required this.session,
    required this.store,
    required this.theme,
  });

  final ApiClient api;
  final SessionStore session;
  final PackStore store;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ApiClient>.value(value: api),
        Provider<SessionStore>.value(value: session),
        Provider<PackStore>.value(value: store),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<StudentController>(
          create: (_) => StudentController(api: api, store: store),
        ),
        ChangeNotifierProvider<SyncController>(
          create: (_) => SyncController(api: api, store: store),
        ),
        ChangeNotifierProvider<ExamController>(
          create: (_) => ExamController(api: api, store: store),
        ),
        ChangeNotifierProvider<LessonsController>(
          create: (_) => LessonsController(api: api, store: store),
        ),
        ChangeNotifierProvider<FlashcardsController>(
          create: (_) => FlashcardsController(api: api, store: store),
        ),
      ],
      child: AnimatedBuilder(
        animation: theme,
        builder: (BuildContext context, Widget? _) => MaterialApp(
          title: 'Renance',
          debugShowCheckedModeBanner: false,
          theme: buildRenanceTheme(),
          darkTheme: buildRenanceDarkTheme(),
          themeMode: theme.materialMode,
          initialRoute: '/',
          routes: <String, WidgetBuilder>{
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => const HomeScreen(),
          },
          onGenerateRoute: (RouteSettings settings) {
            if (settings.name == '/exam') {
              final ExamMeta exam = settings.arguments! as ExamMeta;
              return MaterialPageRoute<void>(
                builder: (_) => ExamScreen(exam: exam),
              );
            }
            return null;
          },
        ),
      ),
    );
  }
}
