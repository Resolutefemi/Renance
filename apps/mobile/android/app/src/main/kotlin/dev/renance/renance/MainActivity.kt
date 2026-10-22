package dev.renance.renance

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-icon appearance switch (founder pass IX): the launcher icon
        // adapts to the in-app appearance setting exactly like the web
        // favicon. Two launcher activity-aliases ship in the manifest -
        // .LauncherLight (brand green) and .LauncherDark (dark-page
        // navy); setVariant enables the matching one and disables the
        // other. Enable-FIRST ordering keeps at least one launcher alias
        // enabled at every instant, so the app can never vanish from the
        // home screen mid-switch. Best-effort: a failure never throws
        // into Dart.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "renance/appIcon"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setVariant" -> {
                    try {
                        val variant = call.argument<String>("variant") ?: "light"
                        val pm = packageManager
                        val light = ComponentName(this, "$packageName.LauncherLight")
                        val dark = ComponentName(this, "$packageName.LauncherDark")
                        val (enableFirst, disableSecond) =
                            if (variant == "dark") dark to light else light to dark
                        pm.setComponentEnabledSetting(
                            enableFirst,
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        pm.setComponentEnabledSetting(
                            disableSecond,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // UpdateGate (founder directive): the anti-share + force-update
        // channel. getInstallSource reports the store package that
        // installed this build ("" when the APK/AAB was shared/sideloaded)
        // so the Dart gate can send the student to the Play Store listing.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "renance/update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallSource" -> {
                    try {
                        val pm = packageManager
                        // Play Store's package name - the only installer
                        // that passes the anti-share gate.
                        val play = "com.android.vending"
                        @Suppress("DEPRECATION")
                        val installer: String? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            // API 30+: the modern install-source API. A
                            // shared/sideloaded APK has no installer (or a
                            // file manager); a Play install says so here.
                            val src = pm.getInstallSourceInfo(packageName)
                            // API 33+ bonus: updateOwnerPackageName is set
                            // when Play owns the app's updates, which
                            // covers phones where a Google-backup restore
                            // reinstalled the app and left the installer
                            // metadata empty - those students DID come from
                            // Play and must not be locked out.
                            val owners = listOf(
                                src.installingPackageName,
                                src.initiatingPackageName,
                                if (Build.VERSION.SDK_INT >= 33) {
                                    src.updateOwnerPackageName
                                } else {
                                    null
                                }
                            )
                            if (owners.contains(play)) play else null
                        } else {
                            @Suppress("DEPRECATION")
                            pm.getInstallerPackageName(packageName)
                        }
                        result.success(installer ?: "")
                    } catch (e: Exception) {
                        // Unknown installer metadata: fail CLOSED for the
                        // shared-APK gate only when we can prove a non-store
                        // source is impossible; we cannot, so fail open.
                        result.success("")
                    }
                }
                "getVersionCode" -> {
                    try {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode
                        }
                        result.success(code)
                    } catch (e: Exception) {
                        result.error("version_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
