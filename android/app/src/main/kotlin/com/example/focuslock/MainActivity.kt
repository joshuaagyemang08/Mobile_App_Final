package com.example.focuslock

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.focuslock.app/permissions"
    private val openLockExtra = "focuslock_open_lock"

    private lateinit var channel: MethodChannel
    private var pendingForceOpenLock = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeHandleLockIntent(intent)
    }

    override fun getInitialRoute(): String? {
        return if (intent?.getBooleanExtra(openLockExtra, false) == true) "/lock" else super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeHandleLockIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        if (pendingForceOpenLock) {
            channel.invokeMethod("forceOpenLock", null)
            pendingForceOpenLock = false
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> result.success(hasUsageStatsPermission())
                "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "checkAccessibilityPermission" -> result.success(isAccessibilityServiceEnabled())
                "openUsageSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun maybeHandleLockIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(openLockExtra, false) != true) {
            return
        }
        if (::channel.isInitialized) {
            channel.invokeMethod("forceOpenLock", null)
        } else {
            pendingForceOpenLock = true
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponent = ComponentName(this, FocusLockAccessibilityService::class.java).flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        for (service in splitter) {
            if (service.equals(expectedComponent, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
