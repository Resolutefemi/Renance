/// Deployment configuration for the Renance mobile shell.
///
/// Override at build/run time:
///   flutter run --dart-define=RENANCE_API_BASE=http://10.0.2.2:3990
///   flutter build apk --dart-define=RENANCE_API_BASE=https://api.renance.dev
///
/// The DEFAULT is the production study API so a release APK built
/// without a --dart-define still syncs, logs in and downloads. The old
/// default (http://10.0.2.2:3990, the Android-emulator alias for
/// localhost) shipped silent, dead downloads in every release build -
/// exactly the "app download function not working" report. Local
/// development passes its own base explicitly.
const String apiBaseUrl = String.fromEnvironment(
  'RENANCE_API_BASE',
  defaultValue: 'https://renance-api.onrender.com',
);

/// Web OAuth client ID passed as Google sign-in's `serverClientId`, so the
/// returned ID token carries the audience the study API verifies
/// (GOOGLE_CLIENT_ID on the server). The DEFAULT is the Renance web
/// client registered in Google Cloud Console (the same audience the web
/// app bakes) - the old empty default hid the "Continue with Google"
/// button from every release build (founder: "I can't find the Google
/// signup/login on the login/sign up page", 2026-09-28). A debug build
/// can still override it with --dart-define.
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '850087098854-pni8gohld0isi8v8nhhnlcl5fuvi77q4.apps.googleusercontent.com',
);

/// The human-facing version stencil (splash "2.6.8 v"). Kept beside the
/// pubspec version so the two are bumped together - the old hardcoded
/// splash string drifted three releases behind (2.5.0 v while the app
/// shipped 2.6.7).
const String appVersion = '2.6.18';
