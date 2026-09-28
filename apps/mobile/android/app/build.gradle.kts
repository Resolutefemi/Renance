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
    // NDK not needed: every plugin in this app is pure Kotlin/Java, and
    // pinning ndkVersion made AGP eagerly fetch a 2.2GB NDK the build
    // never uses. Re-add only if a plugin gains real native (C/C++) code.
    // ndkVersion = flutter.ndkVersion

    compileOptions {
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
        // differs per machine — so `flutter run` Google sign-in broke on every
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
    }

    buildTypes {
        debug {
            // Explicit: never fall back to ~/.android/debug.keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        // The Flutter Gradle plugin creates the "profile" build type with
        // initWith(debug), so profile builds inherit the shared debug key too.
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
