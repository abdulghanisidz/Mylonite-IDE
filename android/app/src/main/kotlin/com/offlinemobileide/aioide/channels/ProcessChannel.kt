package com.offlinemobileide.aioide.channels

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
 *
 * TODO (Phase 4): Implement full ProcessBuilder integration with
 *   ForegroundServiceHost for long-running executions.
 */
class ProcessChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "ide/process"
        const val EVENT_CHANNEL = "ide/process/output"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(ProcessOutputStreamHandler())
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "spawnProcess" -> result.notImplemented()
            "terminateProcess" -> result.notImplemented()
            "writeStdin" -> result.notImplemented()
            else -> result.notImplemented()
        }
    }

    fun cleanup() {
        // Phase 4: terminate all active processes on activity destroy
    }

    /** Stub EventChannel stream handler — Phase 4 will wire real stdout/stderr. */
    private class ProcessOutputStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            // Phase 4: attach output reader threads
        }

        override fun onCancel(arguments: Any?) {
            // Phase 4: detach output reader threads
        }
    }
}
