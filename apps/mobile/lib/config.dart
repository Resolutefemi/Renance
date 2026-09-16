/// Deployment configuration for the Renance mobile shell.
///
/// Override at build/run time:
///   flutter run --dart-define=RENANCE_API_BASE=http://10.0.2.2:3990
///   flutter build apk --dart-define=RENANCE_API_BASE=https://api.renance.dev
///
/// The DEFAULT is the production study API so a release APK built
/// without a --dart-define still syncs, logs in and downloads. The old
/// default (http://10.0.2.2:3990, the Android-emulator alias for
/// localhost) shipped silent, dead downloads in every release build —
/// exactly the "app download function not working" report. Local
/// development passes its own base explicitly.
const String apiBaseUrl = String.fromEnvironment(
  'RENANCE_API_BASE',
  defaultValue: 'https://renance-api.onrender.com',
);

/// Web OAuth client ID passed as Google sign-in's `serverClientId`, so the
/// returned ID token carries the audience the study API verifies
/// (GOOGLE_CLIENT_ID on the server). Empty => the Google button hides.
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);
