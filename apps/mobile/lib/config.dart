/// Deployment configuration for the Renance mobile shell.
///
/// Override at build/run time:
///   flutter run --dart-define=RENANCE_API_BASE=http://10.0.2.2:3990
///   flutter build apk --dart-define=RENANCE_API_BASE=https://api.renance.dev
///
/// 10.0.2.2 is the Android-emulator alias for your machine's localhost,
/// where `pnpm api:dev` serves the Go study API.
const String apiBaseUrl = String.fromEnvironment(
  'RENANCE_API_BASE',
  defaultValue: 'http://10.0.2.2:3990',
);

/// Web OAuth client ID passed as Google sign-in's `serverClientId`, so the
/// returned ID token carries the audience the study API verifies
/// (GOOGLE_CLIENT_ID on the server). Empty => the Google button hides.
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);
