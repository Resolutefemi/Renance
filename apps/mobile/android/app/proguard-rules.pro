# Renance release keep rules.
#
# The Flutter Gradle plugin adds its own rules (flutter_proguard_rules) and
# every plugin in this app ships consumer rules. This file exists because
# the plugin references it explicitly; the rules below only silence R8 for
# reflective access patterns the plugins document.
#
# google_sign_in / play services identity
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
# flutter_tts keeps its platform channel handlers via reflection-free
# registration, but the engine utility classes stay safe regardless.
-keep class io.flutter.plugin.editing.** { *; }
