package com.rentnearby.rentnearby

import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val endAlert = Runnable { setRingAlert(false) }
    private var alertTag: String? = null
    private var cover: View? = null
    private var quotePdf: QuotePdfChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) armRingAlert(intent)
    }

    override fun onNewIntent(intent: Intent) {
        if (!armRingAlert(intent) && alertTag != null) setRingAlert(false)
        super.onNewIntent(intent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(endAlert)
        removeCover()
        quotePdf?.dispose()
        quotePdf = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        quotePdf?.dispose()
        quotePdf = QuotePdfChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
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
                "ringAlertHold" -> result.success(
                    holdRingAlert(call.argument<String>("tag"), call.argument<Number>("ms")?.toLong() ?: 0L)
                )
                "ringAlertEnd" -> endRingAlert(call.argument<String>("tag"), call.argument<Boolean>("unlock") == true, result)
                else -> result.notImplemented()
            }
        }
    }

    // Only the body launch of a real taxi request ring or stay enquiry ring may show over the lock screen.
    private fun ringTag(intent: Intent?): String? {
        if (intent == null || intent.action != SELECT_NOTIFICATION) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return try {
            val payload = JSONObject(intent.getStringExtra(PAYLOAD) ?: return null)
            val tag = payload.opt(RING_TAG) as? String
            val ring = (payload.optString("notification_type") == RING_TYPE && payload.optString("action_route") == RING_ROUTE) ||
                (payload.optString("notification_type") == STAY_RING_TYPE && payload.optString("action_route") == STAY_RING_ROUTE)
            if (ring && !tag.isNullOrEmpty()) tag else null
        } catch (e: Exception) {
            null
        }
    }

    private fun armRingAlert(intent: Intent?): Boolean {
        val tag = ringTag(intent) ?: return false
        if (tag == alertTag) return true
        setRingAlert(true)
        alertTag = tag
        handler.removeCallbacks(endAlert)
        handler.postDelayed(endAlert, CLAIM_MS)
        return true
    }

    private fun holdRingAlert(tag: String?, ms: Long): Boolean {
        if (tag == null || tag != alertTag) return false
        handler.removeCallbacks(endAlert)
        handler.postDelayed(endAlert, ms.coerceIn(0L, MAX_RING_MS) + GRACE_MS)
        removeCover()
        return true
    }

    private fun endRingAlert(tag: String?, unlock: Boolean, result: MethodChannel.Result) {
        if (tag == null || tag != alertTag) {
            result.success(false)
            return
        }
        val keyguard = getSystemService(KEYGUARD_SERVICE) as? KeyguardManager
        if (unlock && keyguard != null && keyguard.isKeyguardLocked && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            var answered = false
            fun finish(ok: Boolean) {
                if (alertTag == tag) setRingAlert(false)
                if (answered) return
                answered = true
                result.success(ok)
            }
            keyguard.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() = finish(true)
                override fun onDismissCancelled() = finish(false)
                override fun onDismissError() = finish(false)
            })
            return
        }
        setRingAlert(false)
        result.success(true)
    }

    private fun setRingAlert(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val lockFlags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(lockFlags) else window.clearFlags(lockFlags)
        }
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            showCover()
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            removeCover()
            handler.removeCallbacks(endAlert)
            alertTag = null
        }
    }

    // Hides whatever Flutter page sits under the ring screen until the ring screen claims the alert.
    private fun showCover() {
        if (cover != null) return
        val content = findViewById<ViewGroup>(android.R.id.content) ?: return
        val view = View(this)
        view.setBackgroundResource(R.drawable.launch_background)
        view.isClickable = true
        content.addView(view, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        cover = view
    }

    private fun removeCover() {
        val view = cover ?: return
        (view.parent as? ViewGroup)?.removeView(view)
        cover = null
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
        private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val PAYLOAD = "payload"
        private const val RING_TYPE = "taxi_request_ring"
        private const val RING_ROUTE = "/taxi-request-ring"
        private const val STAY_RING_TYPE = "stay_enquiry_ring"
        private const val STAY_RING_ROUTE = "/stay-enquiry-ring"
        private const val RING_TAG = "ring_tag"
        private const val CLAIM_MS = 30_000L
        private const val MAX_RING_MS = 300_000L
        private const val GRACE_MS = 3_000L
    }
}
