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

# BOOT-CRASH FIX, round 2 (2026-10-23): WorkManager 2.7.1 (pulled in by
# home_widget -> glance-appwidget 1.0.0) initializes through Room's
# reflective getGeneratedImplementation: Class.forName on
# androidx.work.impl.WorkDatabase_Impl followed by
# getDeclaredConstructor().newInstance(). Room 2.2.5's consumer rule kept
# the class NAME under full-mode shrinking, but R8 stripped the constructor
# (nothing calls it statically), so every release build died at
# provider-install time with "Failed to create an instance of
# androidx.work.impl.WorkDatabase" before Application.onCreate could run.
# The boot initializer is removed from the merged manifest (see
# AndroidManifest.xml); these rules additionally keep the reflective
# surface intact in case WorkManager is ever initialized on demand later.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.room.RoomDatabase { *; }
