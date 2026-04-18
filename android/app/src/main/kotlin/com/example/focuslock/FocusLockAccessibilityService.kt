package com.example.focuslock

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class FocusLockAccessibilityService : AccessibilityService() {

    private val prefsName = "FlutterSharedPreferences"
    private val keyIsLocked = "flutter.is_locked"
    private val keyMonitoredApps = "flutter.monitored_apps"
    private val launchDebounceMs = 1200L
    private var lastLaunchAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val type = event.eventType
        if (type != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && type != AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            return
        }

        val foregroundPackage = event.packageName?.toString() ?: return
        if (foregroundPackage == packageName) return

        if (!isCurrentlyLocked()) return

        val monitoredApps = monitoredPackages()
        if (foregroundPackage !in monitoredApps) return

        val now = SystemClock.elapsedRealtime()
        if (now - lastLaunchAt < launchDebounceMs) return

        lastLaunchAt = now
        launchLockScreen()
    }

    override fun onInterrupt() {
        // No-op.
    }

    private fun isCurrentlyLocked(): Boolean {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return prefs.getBoolean(keyIsLocked, false)
    }

    private fun monitoredPackages(): Set<String> {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val raw = prefs.getString(keyMonitoredApps, "[]") ?: "[]"

        return try {
            val array = JSONArray(raw)
            buildSet {
                for (i in 0 until array.length()) {
                    val pkg = array.optString(i)
                    if (!pkg.isNullOrBlank()) {
                        add(pkg)
                    }
                }
            }
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun launchLockScreen() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("focuslock_open_lock", true)
        }
        startActivity(intent)
    }
}
