// Theme-tier flip harness.
//
// Pumps every screen under each of the three Appearance tiers (light,
// mixed, dark) and saves a golden PNG per (screen, tier) pair so the
// three tiers can be flipped through side by side and anything that
// reads wrong in a tier can be flagged.
//
// Opt-in: RENANCE_GOLDENS=1 flutter test test/theme_flip_golden_test.dart
//   --update-goldens
// Skipped in normal runs (and in CI) because golden renders depend on
// local fonts and are regenerated artifacts, not committed baselines.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';
import 'package:renance/ui/ai_generator_screen.dart';
import 'package:renance/ui/arena_lobby_screen.dart';
import 'package:renance/ui/arena_match_screen.dart';
import 'package:renance/ui/auth_screens.dart';
import 'package:renance/ui/badge_detail_screen.dart';
import 'package:renance/ui/career_bridge_screen.dart';
import 'package:renance/ui/certificate_wallet_screen.dart';
import 'package:renance/ui/downloads_screen.dart';
import 'package:renance/ui/exam_mode_setup_screen.dart';
import 'package:renance/ui/exam_screen.dart' show ExamScreen;
import 'package:renance/ui/fatigue_nudge.dart';
import 'package:renance/ui/flashcards_screen.dart';
import 'package:renance/ui/gamification_hub_screen.dart';
import 'package:renance/ui/home_screen.dart';
import 'package:renance/ui/jamb_subject_selection_screen.dart';
import 'package:renance/ui/lessons_screen.dart';
import 'package:renance/ui/library_screen.dart';
import 'package:renance/ui/notifications_screen.dart';
import 'package:renance/ui/offline_share_screen.dart';
import 'package:renance/ui/onboarding_sheet.dart';
import 'package:renance/ui/pack_detail_screen.dart';
import 'package:renance/ui/patron_portal_screen.dart';
import 'package:renance/ui/practice_setup_screen.dart';
import 'package:renance/ui/profile_screen.dart';
import 'package:renance/ui/progress_screen.dart';
import 'package:renance/ui/review_screen.dart';
import 'package:renance/ui/search_screen.dart';
import 'package:renance/ui/settings_screen.dart';
import 'package:renance/ui/study_plan_screen.dart';
import 'package:renance/ui/splash_screen.dart';
import 'package:renance/ui/syllabus_screen.dart';
import 'package:renance/ui/theme.dart';
import 'package:renance/ui/tutor_screen.dart';
import 'package:renance/ui/university_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake infrastructure
// ---------------------------------------------------------------------------

/// In-memory PackStore so screens get believable data with no sqflite.
class MemPackStore extends PackStore {
  final Map<String, Bundle> packs = <String, Bundle>{};
  final Map<String, int> sizes = <String, int>{
    'jamb-biology-mock': 1048576,
    'jamb-chemistry-mock': 2097152,
  };
  final List<PendingSubmission> subs = <PendingSubmission>[];
  final List<PendingCardGrade> grades = <PendingCardGrade>[];
  List<FlashcardDeckMeta> decks = const <FlashcardDeckMeta>[];
  final Map<String, FlashcardDeck> deckBodies = <String, FlashcardDeck>{};
  List<CardProgress> cardProgress = const <CardProgress>[];
  List<LessonMeta> lessonMetas = const <LessonMeta>[];
  final Map<String, Lesson> lessonBodies = <String, Lesson>{};

  @override
  Future<void> savePack(Bundle bundle, String sha) async =>
      packs[bundle.code] = bundle;

  @override
  Future<Bundle?> loadPack(String code, String sha) async => packs[code];

  @override
  Future<Bundle?> loadPackByCode(String code) async => packs[code];

  @override
  Future<Set<String>> downloadedCodes() async => packs.keys.toSet();

  @override
  Future<Map<String, int>> packSizes() async => sizes;

  @override
  Future<void> removePack(String code) async => packs.remove(code);

  @override
  Future<void> clearPacks() async => packs.clear();

  @override
  Future<void> queueSubmission(PendingSubmission s) async => subs.add(s);

  @override
  Future<List<PendingSubmission>> pendingSubmissions() async => subs;

  @override
  Future<void> removeSubmission(String id) async =>
      subs.removeWhere((PendingSubmission s) => s.id == id);

  @override
  Future<void> saveDeckMetas(List<FlashcardDeckMeta> d) async => decks = d;

  @override
  Future<List<FlashcardDeckMeta>> cachedDeckMetas() async => decks;

  @override
  Future<void> saveDeck(FlashcardDeck d) async => deckBodies[d.code] = d;

  @override
  Future<FlashcardDeck?> loadDeck(String code) async => deckBodies[code];

  @override
  Future<void> saveCardProgress(List<CardProgress> rows) async =>
      cardProgress = rows;

  @override
  Future<List<CardProgress>> loadCardProgress() async => cardProgress;

  @override
  Future<void> queueCardGrade(PendingCardGrade g) async => grades.add(g);

  @override
  Future<List<PendingCardGrade>> pendingCardGrades() async => grades;

  @override
  Future<void> removeCardGrade(String id) async =>
      grades.removeWhere((PendingCardGrade g) => g.id == id);

  @override
  Future<void> saveLessonMetas(List<LessonMeta> l) async => lessonMetas = l;

  @override
  Future<List<LessonMeta>> cachedLessonMetas() async => lessonMetas;

  @override
  Future<void> saveLesson(Lesson l) async => lessonBodies[l.slug] = l;

  @override
  Future<Lesson?> loadLesson(String slug) async => lessonBodies[slug];
}

/// Canned API: the endpoints whose shapes we know return demo data,
/// everything else answers a clean 404 error body (error panes are part
/// of the UI too and deserve the tier audit).
http.Client fakeApi() {
  return MockClient((http.Request request) async {
    final String p = request.url.path;
    Map<String, dynamic> body = <String, dynamic>{
      'error': <String, String>{'code': 'not_found', 'message': 'demo'},
    };
    int status = 404;

    if (p == '/me') {
      body = <String, dynamic>{
        'user': <String, dynamic>{
          'id': 'u-1',
          'username': 'adaobi',
          'profileCompleted': true,
        },
        'profile': <String, dynamic>{
          'fullName': 'Adaobi Okonkwo',
          'institution': 'Government College, Lagos',
          'gradeLevel': 'SS3',
          'exams': <String>['JAMB'],
          'completed': true,
          'targetYear': 2027,
        },
      };
      status = 200;
    } else if (p == '/me/gamification') {
      body = <String, dynamic>{
        'state': <String, dynamic>{
          'currentStreak': 12,
          'bestStreak': 19,
          'totalXp': 3240,
          'totalCorrect': 210,
          'attempts': 24,
          'level': 7,
          'lastActive': '2026-09-03',
        },
        'awards': <Map<String, dynamic>>[
          <String, dynamic>{
            'code': 'first_blood',
            'earnedAt': '2026-09-01T10:00:00Z',
          },
          <String, dynamic>{
            'code': 'xp_500',
            'earnedAt': '2026-09-02T10:00:00Z',
          },
        ],
      };
      status = 200;
    } else if (p == '/manifest') {
      body = <String, dynamic>{
        'version': 'demo',
        'exams': <dynamic>[
          <String, dynamic>{
            'code': 'jamb-biology-mock',
            'title': 'JAMB Biology',
            'questionCount': 15,
            'totalMarks': 15,
            'body': 'JAMB',
            'bundleSha256': 'a' * 64,
            'sizeBytes': 1048576,
          },
          <String, dynamic>{
            'code': 'jamb-chemistry-mock',
            'title': 'JAMB Chemistry',
            'questionCount': 12,
            'totalMarks': 12,
            'body': 'JAMB',
            'bundleSha256': 'b' * 64,
            'sizeBytes': 2097152,
          },
        ],
      };
      status = 200;
    } else if (p == '/me/attempts') {
      body = <String, dynamic>{
        'attempts': <dynamic>[
          <String, dynamic>{
            'attemptId': 'a-1',
            'code': 'jamb-biology-mock',
            'status': 'graded',
            'startedAt': '2026-09-01T10:00:00Z',
            'submittedAt': '2026-09-01T10:24:00Z',
            'durationMs': 1440000,
            'score': 11,
            'total': 15,
          },
        ],
      };
      status = 200;
    } else if (p == '/me/review') {
      body = <String, dynamic>{
        'dueToday': <dynamic>[],
        'upcoming': <dynamic>[],
        'stats': <String, dynamic>{'dueCount': 0, 'streakDays': 12},
      };
      status = 200;
    } else if (p == '/me/fatigue') {
      body = <String, dynamic>{
        'level': 'none',
        'suggestBreak': false,
        'minutesToday': 42.0,
        'minutesLast3h': 18.0,
        'sessionsToday': 2,
        'reason': '',
      };
      status = 200;
    }

    return http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
}

// ---------------------------------------------------------------------------
// Harness: same wiring as RenanceApp, one screen per pump
// ---------------------------------------------------------------------------

const ExamMeta kDemoExam = ExamMeta(
  code: 'jamb-biology-mock',
  title: 'JAMB Biology',
  questionCount: 15,
  totalMarks: 15,
  bundleSha256: 'demo',
  body: 'JAMB',
  durationMinutes: 40,
);

class Harness {
  Harness(this.mode)
      : api = ApiClient(baseUrl: 'http://fake', client: fakeApi()),
        store = MemPackStore(),
        theme = null;

  final RenanceThemeMode mode;
  final ApiClient api;
  final MemPackStore store;
  ThemeController? theme;

  Future<List<SingleChildWidget>> providers() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'renance.theme': mode.name,
      'renance.token': 'tok-demo',
      'renance.user': jsonEncode(<String, dynamic>{
        'id': 'u-1',
        'username': 'adaobi',
        'profileCompleted': true,
      }),
    });
    final SharedPreferences p = await SharedPreferences.getInstance();
    final SessionStore session = SessionStore(p);
    final ThemeController t = ThemeController(prefs: p);
    theme = t;
    return <SingleChildWidget>[
      Provider<ApiClient>.value(value: api),
      Provider<SessionStore>.value(value: session),
      Provider<PackStore>.value(value: store),
      ChangeNotifierProvider<ThemeController>.value(value: t),
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
    ];
  }
}

WidgetBuilder screenFor(String name) {
  switch (name) {
    case 'splash':
      return (_) => const SplashScreen();
    case 'login':
      return (_) => const LoginScreen();
    case 'register':
      return (_) => const RegisterScreen();
    case 'home':
      return (_) => const HomeScreen();
    case 'university_home':
      return (c) => UniversityHomeTab(
            student: c.read<StudentController>(),
            sync: c.read<SyncController>(),
            onGoTab: (_) {},
          );
    case 'library':
      return (_) => LibraryScreen(
            onOpenExam: (BuildContext c, ExamMeta e,
                {int? durationOverrideMinutes, bool untimed = false}) {},
          );
    case 'review':
      return (_) => const ReviewScreen();
    case 'review_detail':
      return (_) => const ReviewDetailScreen(attemptId: 'a-1');
    case 'search':
      return (_) => const SearchScreen();
    case 'settings':
      return (_) => const SettingsScreen();
    case 'downloads':
      return (_) => const DownloadsScreen();
    case 'notifications':
      return (_) => const NotificationsScreen();
    case 'profile':
      return (_) => ProfileScreen(onGoTab: (_) {});
    case 'exam_mode_setup':
      return (_) => ExamModeSetupScreen(
            exams: const <ExamMeta>[kDemoExam],
            downloaded: const <String>{'jamb-biology-mock'},
            onBegin: (BuildContext c, ExamMeta e) {},
          );
    case 'jamb_subjects':
      return (_) => const JambSubjectSelectionScreen();
    case 'practice_setup':
      return (_) => const PracticeSetupScreen();
    case 'pack_detail':
      return (_) => PackDetailScreen(
            exam: kDemoExam,
            onStart: (BuildContext c, ExamMeta e,
                {int? durationOverrideMinutes, bool untimed = false}) {},
          );
    case 'badge_detail':
      return (_) => BadgeDetailScreen(
            spec: const BadgeSpec(
              code: 'streak_7',
              label: 'On Fire',
              icon: Icons.local_fire_department,
              bg: Color(0xFFFFF3D6),
              fg: Color(0xFFF59E0B),
              hint: 'Keep a 7-day streak',
              earned: true,
            ),
            related: const <BadgeSpec>[],
            currentStreak: 12,
            totalXp: 3240,
          );
    case 'gamification_hub':
      return (_) => const GamificationHubScreen();
    case 'progress':
      return (_) => const ProgressScreen();
    case 'study_plan':
      return (_) => const StudyPlanScreen();
    case 'syllabus':
      return (_) => const SyllabusScreen();
    case 'tutor':
      return (_) => const TutorEntryScreen();
    case 'lessons':
      return (_) => const LessonsScreen();
    case 'lesson_reader':
      return (_) =>
          const LessonReaderScreen(slug: 'demo', title: 'Cell Division');
    case 'flashcards':
      return (_) => const FlashcardsScreen();
    case 'arena_lobby':
      return (_) => const ArenaLobbyScreen();
    case 'arena_match':
      return (_) => const ArenaMatchScreen();
    case 'career_bridge':
      return (_) => const CareerBridgeScreen();
    case 'offline_share':
      return (_) => const OfflineShareScreen();
    case 'ai_generator':
      return (_) => const AiGeneratorScreen();
    case 'patron_portal':
      return (_) => const PatronPortalScreen();
    case 'certificate_wallet':
      return (_) => const CertificateWalletScreen();
    case 'onboarding':
      return (_) => const Scaffold(body: OnboardingSheet());
    case 'exam_player':
      return (_) => const ExamScreen(exam: kDemoExam);
    case 'fatigue_nudge':
      return (_) => FatigueNudgeOverlay(
            visible: true,
            reasons: const <String>['4 papers without a break'],
            onTakeBreak: () {},
            onKeepGoing: () {},
            child: const Scaffold(body: SizedBox.shrink()),
          );
  }
  throw StateError('unknown screen $name');
}

/// Tabs rendered inside the HomeScreen shell expect a Scaffold/Material
/// ancestor plus the shell's card ground; standalone pumps would paint
/// them on bare black with the no-Material yellow underlines.
const Set<String> kTabScreens = <String>{
  'library',
  'review',
  'progress',
  'university_home',
  'profile',
};

Future<void> pumpScreen(
  WidgetTester tester,
  Harness h,
  String name, {
  Future<void> Function()? onFirstFrame,
}) async {
  final List<SingleChildWidget> providers = await h.providers();
  final RenanceThemeMode mode = h.mode;
  WidgetBuilder builder = screenFor(name);
  if (kTabScreens.contains(name)) {
    builder = (BuildContext shellCtx) => Scaffold(
          backgroundColor: shellCtx.card,
          body: Builder(builder: screenFor(name)),
        );
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildRenanceTheme(),
        darkTheme: buildRenanceDarkTheme(),
        themeMode:
            mode == RenanceThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (BuildContext c, Widget? child) =>
            RenanceModeScope(mode: mode, child: child ?? const SizedBox()),
        routes: <String, WidgetBuilder>{
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
        },
        home: Builder(builder: builder),
      ),
    ),
  );
  // RenanceMark loops forever by design, so pump fixed steps.
  if (onFirstFrame != null) {
    await tester.pump();
    await onFirstFrame();
  }
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump(const Duration(milliseconds: 420));
  await tester.pump(const Duration(milliseconds: 420));
}

const List<String> kTiers = <String>['light', 'mixed', 'dark'];

const List<String> kScreens = <String>[
  'splash',
  'login',
  'register',
  'home',
  'university_home',
  'library',
  'review',
  'review_detail',
  'search',
  'settings',
  'downloads',
  'notifications',
  'profile',
  'exam_mode_setup',
  'jamb_subjects',
  'practice_setup',
  'pack_detail',
  'badge_detail',
  'gamification_hub',
  'progress',
  'study_plan',
  'syllabus',
  'tutor',
  'lessons',
  'lesson_reader',
  'flashcards',
  'arena_lobby',
  'arena_match',
  'career_bridge',
  'offline_share',
  'ai_generator',
  'patron_portal',
  'certificate_wallet',
  'onboarding',
  'exam_player',
  'fatigue_nudge',
];

void main() {
  // Golden generation is a local audit tool, not a CI gate.
  if (Platform.environment['RENANCE_GOLDENS'] != '1') {
    return;
  }
  for (final String name in kScreens) {
    testWidgets(
      'tier flip: $name',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(412, 940);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        for (final String tier in kTiers) {
          final Harness h = Harness(RenanceThemeMode.values.byName(tier));
          await tester.binding.setSurfaceSize(const Size(412, 940));
          await pumpScreen(
            tester,
            h,
            name,
            onFirstFrame: name == 'splash'
                ? () => expectLater(
                      find.byType(MaterialApp),
                      matchesGoldenFile('goldens/theme_flip/${name}_$tier.png'),
                    )
                : null,
          );
          if (name != 'splash') {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/theme_flip/${name}_$tier.png'),
            );
          }
          if (name == 'arena_match') {
            // The lobby countdown schedules a 5s timer; let it fire so the
            // test ends with no pending timer.
            await tester.pump(const Duration(seconds: 5));
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.binding.setSurfaceSize(null);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
