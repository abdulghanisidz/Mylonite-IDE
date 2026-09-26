package com.offlinemobileide.aioide.channels

import android.content.Context
import android.content.Intent
import android.util.Log
import com.offlinemobileide.aioide.services.ProcessForegroundService
import com.offlinemobileide.aioide.services.ProcessService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * ProcessChannel — Kotlin side of the `ide/process` Platform Channel.
 *
 * Handles process spawning, stdin relay, and process termination for
 * the Python and JavaScript runtimes. Streams stdout/stderr back to
 * Dart via the `ide/process/output` EventChannel.
 *
 * Architecture: 02-ARCHITECTURE.md §11.1, 04-RUNTIME-SYSTEM.md §5
 *
 * Methods (MethodChannel `ide/process`):
 *   spawnProcess(argv, workingDirectory, environment, stdinInput?, timeoutSeconds)
 *     → { pid: Int, sessionId: String }
 *   terminateProcess(sessionId)
 *     → { success: Boolean }
 *   writeStdin(sessionId, data)
 *     → { success: Boolean }
 *   cleanup()
 *     → void
 *
 * Events (EventChannel `ide/process/output`):
 *   { sessionId, type: "stdout"|"stderr"|"exit", content, exitCode? }
 */
class ProcessChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ProcessChannel"
        const val METHOD_CHANNEL = "ide/process"
        const val EVENT_CHANNEL = "ide/process/output"
        private const val LONG_RUNNING_THRESHOLD_SECONDS = 10
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val processService = ProcessService(context)
    private val outputStreamHandler = ProcessOutputStreamHandler()
    private val channelScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(outputStreamHandler)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "spawnProcess" -> handleSpawnProcess(call, result)
            "terminateProcess" -> handleTerminateProcess(call, result)
            "writeStdin" -> handleWriteStdin(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleSpawnProcess(call: MethodCall, result: MethodChannel.Result) {
        channelScope.launch {
            try {
                val argv = call.argument<List<String>>("argv")
                    ?: throw IllegalArgumentException("argv is required")
                val workingDirectory = call.argument<String>("workingDirectory")
                    ?: throw IllegalArgumentException("workingDirectory is required")
                val environment = call.argument<Map<String, String>>("environment") ?: emptyMap()
                val stdinInput = call.argument<String>("stdinInput")
                val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 30

                Log.d(TAG, "Spawning process: ${argv.joinToString(" ")}")

                // Start foreground service if this might be long-running
                if (timeoutSeconds > LONG_RUNNING_THRESHOLD_SECONDS) {
                    startForegroundService()
                }

                val handle = processService.spawnProcess(
                    argv = argv,
                    workingDirectory = workingDirectory,
                    environment = environment,
                    stdinInput = stdinInput,
                    timeoutSeconds = timeoutSeconds,
                    onOutput = { type, content ->
                        outputStreamHandler.sendOutput(
                            sessionId = handle.sessionId,
                            type = type,
                            content = content
                        )
                    },
                    onExit = { exitCode, timedOut, oomKilled ->
                        outputStreamHandler.sendExit(
                            sessionId = handle.sessionId,
                            exitCode = exitCode,
                            timedOut = timedOut,
                            oomKilled = oomKilled
                        )
                        // Stop foreground service if no more processes
                        if (processService.getActiveProcesses().isEmpty()) {
                            stopForegroundService()
                        }
                    }
                )

                result.success(
                    mapOf(
                        "sessionId" to handle.sessionId,
                        "pid" to handle.pid
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to spawn process", e)
                result.error("SPAWN_FAILED", e.message, null)
            }
        }
    }

    private fun handleTerminateProcess(call: MethodCall, result: MethodChannel.Result) {
        channelScope.launch {
            try {
                val sessionId = call.argument<String>("sessionId")
                    ?: throw IllegalArgumentException("sessionId is required")

                Log.d(TAG, "Terminating process: $sessionId")

                val success = processService.terminateProcess(sessionId)

                // Stop foreground service if no more processes
                if (processService.getActiveProcesses().isEmpty()) {
                    stopForegroundService()
                }

                result.success(mapOf("success" to success))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to terminate process", e)
                result.error("TERMINATE_FAILED", e.message, null)
            }
        }
    }

    private fun handleWriteStdin(call: MethodCall, result: MethodChannel.Result) {
        channelScope.launch {
            try {
                val sessionId = call.argument<String>("sessionId")
                    ?: throw IllegalArgumentException("sessionId is required")
                val data = call.argument<String>("data")
                    ?: throw IllegalArgumentException("data is required")

                val success = processService.writeStdin(sessionId, data)
                result.success(mapOf("success" to success))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write stdin", e)
                result.error("WRITE_FAILED", e.message, null)
            }
        }
    }

    fun cleanup() {
        Log.d(TAG, "Cleaning up ProcessChannel")
        processService.cleanup()
        stopForegroundService()
    }

    private fun startForegroundService() {
        try {
            val intent = Intent(context, ProcessForegroundService::class.java)
            context.startForegroundService(intent)
            Log.d(TAG, "Started foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
        }
    }

    private fun stopForegroundService() {
        try {
            val intent = Intent(context, ProcessForegroundService::class.java)
            context.stopService(intent)
            Log.d(TAG, "Stopped foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop foreground service", e)
        }
    }

    /**
     * EventChannel stream handler for process output.
     */
    private class ProcessOutputStreamHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            Log.d(TAG, "Output stream listener attached")
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            Log.d(TAG, "Output stream listener detached")
        }

        fun sendOutput(sessionId: String, type: String, content: String) {
            eventSink?.success(
                mapOf(
                    "sessionId" to sessionId,
                    "type" to type,
                    "content" to content
                )
            )
        }

        fun sendExit(sessionId: String, exitCode: Int, timedOut: Boolean, oomKilled: Boolean) {
            eventSink?.success(
                mapOf(
                    "sessionId" to sessionId,
                    "type" to "exit",
                    "exitCode" to exitCode,
                    "timedOut" to timedOut,
                    "oomKilled" to oomKilled
                )
            )
        }
    }
}
