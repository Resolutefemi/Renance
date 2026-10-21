plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.renance.renance"
    // file_picker pulls flutter_plugin_android_lifecycle 2.0.28+, which
    // requires compiling against Android API 36; Flutter 3.47's default
    // is 34. compileSdk is compile-time only, runtime targets stay put.
    compileSdk = 36
    // NDK not needed: every plugin in this app is pure Kotlin/Java. The
    // version is pinned (not left to AGP's default) so the Flutter gradle
    // plugin's forceNdkDownload back-off sees a CONFIGURED version that
    // matches the sdkmanager-installed list; unpinned, it configures a
    // synthetic CMake project that drags the whole 2.2GB NDK in. With the
    // pin + the installed marker, no CXX task is ever created.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (java.time on old Android) needs
        // core library desugaring; the desugaring library rides the
        // dependencies block at the bottom (CI catch 2026-10-03).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        // Fixed release key committed with the repo (public OSS MVP): keeps
        // the SHA-1 fingerprint stable across CI runners, which is what the
        // Google OAuth "Android client" is registered against. Rotate to a
        // secret-managed keystore before Play Store distribution.
        create("release") {
            storeFile = file("renance.keystore")
            storePassword = "renance-keystore"
            keyAlias = "renance"
            keyPassword = "renance-keystore"
        }
        // Shared DEBUG key, also committed with the repo. AGP's default debug
        // signingConfig points at ~/.android/debug.keystore, whose fingerprint
        // differs per machine, so `flutter run` Google sign-in broke on every
        // fresh machine. Overriding it pins ONE debug SHA-1 (see docs/deploy.md):
        // register it once as the second Android OAuth client and debug builds
        // authenticate from any machine that pulled this repo.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.renance.renance"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Deliberately NO ndkVersion here: nothing in this app compiles
        // native code, and letting AGP resolve a default NDK made it
        // auto-download a 2.2GB NDK that the build never uses.
    }

    buildTypes {
        debug {
            // Explicit: never fall back to ~/.android/debug.keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            // Founder rule: "make sure the app is not heavy". R8 shrinks
            // and optimizes the dex, resource shrinking drops unused
            // resources; Flutter's Gradle plugin contributes the keep
            // rules the engine and plugins need. Paired with
            // --obfuscate --split-debug-info at build time this cut the
            // release footprint meaningfully with zero runtime impact.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                // Kotlin DSL app dir: keep any hand-written rules beside
                // this file (none needed today - all plugins ship their
                // own consumer rules).
            )
        }
        // The Flutter Gradle plugin creates the "profile" build type with
        // initWith(debug), so profile builds inherit the shared debug key too.
    }
}

// NOTE: the old `kotlin { compilerOptions { jvmTarget } }` block broke with
// the Flutter 3.35 gradle plugin, which applies an older Kotlin Gradle
// plugin to this module (the `compilerOptions` extension does not resolve).
// The Flutter plugin aligns the Kotlin JVM target with the Java
// compileOptions above on its own, so the explicit block is unnecessary.
// 2026-10-19: with Flutter 3.47 + KGP 2.4 + AGP 9.1 the auto-alignment no
// longer happens (Kotlin resolves the JDK 21 toolchain while Java stays on
// 17), so the explicit target is back - pinned to 17 to match the Java
// compileOptions and every previous release build.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications' core library desugaring
    // (compileOptions.isCoreLibraryDesugaringEnabled above).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
