package com.offlinemobileide.aioide.channels

import android.app.ActivityManager
import android.content.Context
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * SystemChannel — Kotlin side of the `ide/system` Platform Channel.
 *
 * Provides Android system information to the Dart layer:
 *   - Available RAM (ActivityManager.MemoryInfo)
 *   - Thermal status (PowerManager.ThermalStatus, API 29+)
 *   - Battery saver mode (PowerManager.isPowerSaveMode)
 *
 * Architecture: 02-ARCHITECTURE.md §4.5, §4.6, 05-OFFLINE-AI.md §18, §21
 *
 * Methods (MethodChannel `ide/system`):
 *   getMemoryInfo()    → { availBytes: Long, totalBytes: Long, lowMemory: Boolean }
 *   getThermalStatus() → { status: Int }
 *     status values: 0=NONE, 1=LIGHT, 2=MODERATE, 3=SEVERE, 4=CRITICAL, 5=EMERGENCY, 6=SHUTDOWN
 *   isPowerSaveMode()  → { enabled: Boolean }
 */
class SystemChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "ide/system"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMemoryInfo" -> handleGetMemoryInfo(result)
            "getThermalStatus" -> handleGetThermalStatus(result)
            "isPowerSaveMode" -> handleIsPowerSaveMode(result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetMemoryInfo(result: MethodChannel.Result) {
        val memInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memInfo)
        result.success(
            mapOf(
                "availBytes" to memInfo.availMem,
                "totalBytes" to memInfo.totalMem,
                "lowMemory" to memInfo.lowMemory,
                "thresholdBytes" to memInfo.threshold,
            )
        )
    }

    private fun handleGetThermalStatus(result: MethodChannel.Result) {
        // PowerManager.ThermalStatus is API 29+.
        // Devices below API 29 get status 0 (NONE — no throttling info available).
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            result.success(mapOf("status" to powerManager.currentThermalStatus))
        } else {
            result.success(mapOf("status" to 0))
        }
    }

    private fun handleIsPowerSaveMode(result: MethodChannel.Result) {
        result.success(mapOf("enabled" to powerManager.isPowerSaveMode))
    }
}
