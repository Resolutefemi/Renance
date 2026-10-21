import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'config.dart';
import 'controllers.dart';
import 'learn_controller.dart';
import 'models.dart';
import 'notifications.dart';
import 'storage.dart';
import 'ui/auth_screens.dart';
import 'ui/verify_screen.dart';
import 'ui/exam_screen.dart' show ExamScreen;
import 'ui/home_screen.dart';
import 'ui/school_screens.dart' show SchoolHomeScreen;
import 'ui/school_home_v2.dart'
    show SchoolWorkspaceScreen, SchoolClassesScreen, SchoolResultsScreen,
        SchoolTeachersScreen, SchoolIdCardsScreen, SchoolRouteArgs;
import 'ui/splash_screen.dart' show SplashScreen;
import 'ui/theme.dart';
import 'update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Device notifications (founder directive 2026-10-04): ready before
  // the first frame so download completions and review nudges can drop.
  await RenanceNotifications.init();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // Secure local storage (founder directive 2026-10-11): the auth token
  // boots from the OS-grade encrypted store (Android
  // EncryptedSharedPreferences / iOS Keychain) before the first frame,
  // so a saved session is live from the very first route and survives
  // app closes and device restarts. Only an explicit Sign Out under the
  // profile ever returns the student to the login page.
  final SessionStore session = await SessionStore.load(prefs);
  final ApiClient api = ApiClient(
    baseUrl: apiBaseUrl,
    token: () => session.token,
  );
  final PackStore store = DbPackStore();
  final ThemeController theme = ThemeController(prefs: prefs);
  // Founder directive 2026-10-19 (the pixel-parity overhaul): the app
  // must open looking EXACTLY like renance.app, which runs the default
  // brand green. Devices that carry an old Chrome-style seed pick
  // (e.g. Chrome Blue from earlier testing) read as "the app looks
  // nothing like the website". This ONE-TIME migration clears the
  // stored seed so the update lands on the website's default palette;
  // the Appearance picker stays and a fresh pick re-tints everything.
  await theme.migrateSeedToWebDefault();

  runApp(
    RenanceApp(
      api: api,
      session: session,
      store: store,
      theme: theme,
      prefs: prefs,
    ),
  );
}

class RenanceApp extends StatelessWidget {
  const RenanceApp({
    super.key,
    required this.api,
    required this.session,
    required this.store,
    required this.theme,
    required this.prefs,
  });

  final ApiClient api;
  final SessionStore session;
  final PackStore store;
  final ThemeController theme;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ApiClient>.value(value: api),
        Provider<SessionStore>.value(value: session),
        Provider<PackStore>.value(value: store),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<StudentController>(
          create: (_) => StudentController(api: api, store: store, prefs: prefs),
        ),
        ChangeNotifierProvider<SyncController>(
          create: (_) => SyncController(api: api, store: store),
        ),
        ChangeNotifierProvider<SchoolController>(
          create: (_) => SchoolController(
            api: api,
            store: store,
            session: session,
          ),
        ),
        ChangeNotifierProvider<ExamController>(
          create: (_) => ExamController(api: api, store: store),
        ),
        ChangeNotifierProvider<LessonsController>(
          create: (_) => LessonsController(api: api, store: store),
        ),
        ChangeNotifierProvider<LessonNarrator>(
          create: (_) => LessonNarrator(),
        ),
        // The learn wallet (gems, hearts, streak, freeze, league) - the
        // web's useLearnStats hook as a provider.
        ChangeNotifierProvider<LearnController>(
          create: (_) => LearnController(api: api, prefs: prefs)
            ..hydrate()
            ..refresh(),
        ),
      ],
      child: AnimatedBuilder(
        animation: theme,
        builder: (BuildContext context, Widget? _) {
          // The Chrome-style seed palette (Settings → Seed Color),
          // resolved for the active tier and handed to both the
          // MaterialApp themes and the mode scope, so one seed repaints
          // every screen - the web's CSS custom properties in Flutter.
          final SeedPalette? palette = theme.palette;
          return MaterialApp(
            title: 'Renance',
            debugShowCheckedModeBanner: false,
            theme: buildRenanceTheme(seed: palette),
            darkTheme: buildRenanceDarkTheme(seed: palette),
            themeMode: theme.materialMode,
            builder: (BuildContext context, Widget? child) =>
                RenanceModeScope(
                  mode: theme.mode,
                  palette: palette,
                  child: child ?? const SizedBox.shrink(),
                ),
            initialRoute: '/',
            routes: <String, WidgetBuilder>{
              '/': (_) => const _StartupGate(),
              '/home': (_) => const HomeScreen(),
              '/verify': (_) => const VerifyScreen(),
              '/school': (_) => const SchoolWorkspaceScreen(),
              '/school-legacy': (_) => const SchoolHomeScreen(),
            },
            onGenerateRoute: (RouteSettings settings) {
              // /login and /register (founder bugfix 2026-10-05): moved
              // out of the static map so the FOR STUDENTS / FOR SCHOOLS
              // tab can travel as the route argument - "sign up for
              // school" opens the SCHOOL sign-up form and the school
              // sign-up's "Sign in" opens the SCHOOL sign-in, instead of
              // both dropping the caller back on the student side.
              if (settings.name == '/login') {
                final AuthAudience audience =
                    settings.arguments is AuthAudience
                        ? settings.arguments! as AuthAudience
                        : AuthAudience.students;
                return MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(initialAudience: audience),
                );
              }
              if (settings.name == '/register') {
                final AuthAudience audience =
                    settings.arguments is AuthAudience
                        ? settings.arguments! as AuthAudience
                        : AuthAudience.students;
                return MaterialPageRoute<void>(
                  builder: (_) => RegisterScreen(initialAudience: audience),
                );
              }
              if (settings.name == '/exam') {
                final ExamMeta exam = settings.arguments! as ExamMeta;
                return MaterialPageRoute<void>(
                  builder: (_) => ExamScreen(exam: exam),
                );
              }
              // The rebuilt school workspace's deep-linkable screens
              // (Task MOB-SCHOOL): classes / results / teachers / id cards.
              const String schoolDetailPrefix = '/school/';
              final String name = settings.name ?? '';
              if (name.startsWith(schoolDetailPrefix) &&
                  settings.arguments is SchoolRouteArgs) {
                final SchoolRouteArgs args =
                    settings.arguments! as SchoolRouteArgs;
                final String tail = name.substring(schoolDetailPrefix.length);
                final WidgetBuilder? builder = switch (tail) {
                  'classes' => (_) => SchoolClassesScreen(
                      schoolId: args.schoolId, isManager: args.isManager),
                  'results' => (_) => SchoolResultsScreen(
                      schoolId: args.schoolId, isManager: args.isManager),
                  'teachers' => (_) => SchoolTeachersScreen(schoolId: args.schoolId),
                  'idcards' => (_) => SchoolIdCardsScreen(
                      schoolId: args.schoolId, isManager: args.isManager),
                  _ => null,
                };
                if (builder != null) {
                  return MaterialPageRoute<void>(builder: builder);
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Startup gate (founder directive 2026-10-04): shared/sideloaded builds
/// never open the app - they are sent to the Play Store - and a stale
/// store build is asked to update before practising. The check fails
/// OPEN (offline / old channel) so no student is ever locked out by a
/// network hiccup; CI and local testing bypass it with
/// `--dart-define=RENANCE_BYPASS_UPDATE_GATE=true`.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<GateVerdict> _verdict;

  @override
  void initState() {
    super.initState();
    _verdict = checkUpdateGate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GateVerdict>(
      future: _verdict,
      builder: (BuildContext context, AsyncSnapshot<GateVerdict> snap) {
        // While the one-shot check runs (and whenever it fails), the
        // splash keeps animating - the gate only ever LOCKS on a
        // definitive not-from-store / outdated verdict.
        if (snap.hasData &&
            (snap.data == GateVerdict.notFromStore ||
                snap.data == GateVerdict.outdated)) {
          return UpdateGateScreen(verdict: snap.data!);
        }
        return const SplashScreen();
      },
    );
  }
}
