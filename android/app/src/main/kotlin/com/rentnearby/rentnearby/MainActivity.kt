package com.rentnearby.rentnearby

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatterySettings" -> result.success(
                    open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
                        open(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS))
                )
                "openNotificationSettings" -> result.success(
                    open(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                )
                "openRingChannelSettings" -> {
                    val id = call.argument<String>("channelId")
                    result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && id != null && open(
                            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                .putExtra(Settings.EXTRA_CHANNEL_ID, id)
                        )
                    )
                }
                "deviceInfo" -> result.success(mapOf("manufacturer" to Build.MANUFACTURER, "sdk" to Build.VERSION.SDK_INT))
                else -> result.notImplemented()
            }
        }
    }

    private fun open(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val SETTINGS_CHANNEL = "bakhli/system_settings"
    }
}
