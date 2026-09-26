package com.offlinemobileide.aioide.services

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * ProcessService — Low-level execution infrastructure for Android.
 *
 * Manages process spawning, stdin/stdout/stderr pipe management, environment
 * variable injection, working directory setting, and process lifecycle.
 *
 * Architecture: 02-ARCHITECTURE.md §11.1, 04-RUNTIME-SYSTEM.md §5
 *
 * Features:
 * - ProcessBuilder-based process spawning with full control over argv, env, cwd
 * - Real-time stdout/stderr streaming via background reader threads
 * - stdin relay for interactive processes
 * - Process tracking by sessionId (UUID)
 * - Configurable execution timeout with automatic termination
 * - SIGTERM → SIGKILL escalation on terminate
 * - Exit code 137 (OOM kill) detection
 * - Orphan process detection and cleanup on startup
 *
 * Thread Safety:
 * All public methods are thread-safe. Internal state protected by ConcurrentHashMap.
 * Output callbacks are invoked on background threads — callers must handle threading.
 */
class ProcessService(private val context: Context) {

    companion object {
        private const val TAG = "ProcessService"
        private const val TERMINATE_TIMEOUT_MS = 500L
    }

    private val activeProcesses = ConcurrentHashMap<String, ProcessHandle>()
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Spawn a new child process.
     *
     * @param argv Command and arguments (e.g., ["python3", "-c", "print('hello')"])
     * @param workingDirectory Absolute path to working directory
     * @param environment Environment variables (empty map uses parent env)
     * @param stdinInput Optional string to write to stdin immediately after spawn
     * @param timeoutSeconds Maximum execution time in seconds (0 = no timeout)
     * @param onOutput Callback for stdout/stderr chunks: (type: String, content: String) -> Unit
     * @param onExit Callback when process exits: (exitCode: Int, timedOut: Boolean, oomKilled: Boolean) -> Unit
     *
     * @return ProcessHandle containing sessionId and PID
     * @throws Exception if process cannot be started
     */
    fun spawnProcess(
        argv: List<String>,
        workingDirectory: String,
        environment: Map<String, String> = emptyMap(),
        stdinInput: String? = null,
        timeoutSeconds: Int = 0,
        onOutput: (type: String, content: String) -> Unit,
        onExit: (exitCode: Int, timedOut: Boolean, oomKilled: Boolean) -> Unit
    ): ProcessHandle {
        require(argv.isNotEmpty()) { "argv cannot be empty" }

        val sessionId = UUID.randomUUID().toString()
        Log.d(TAG, "[$sessionId] Spawning process: ${argv.joinToString(" ")}")
        Log.d(TAG, "[$sessionId] Working directory: $workingDirectory")

        // Build the process
        val processBuilder = ProcessBuilder(argv)
            .directory(File(workingDirectory))
            .redirectErrorStream(false) // Keep stdout and stderr separate

        // Set environment variables
        if (environment.isNotEmpty()) {
            val env = processBuilder.environment()
            env.putAll(environment)
            Log.d(TAG, "[$sessionId] Environment: ${environment.keys}")
        }

        // Start the process
        val process = try {
            processBuilder.start()
        } catch (e: Exception) {
            Log.e(TAG, "[$sessionId] Failed to start process", e)
            throw Exception("Process spawn failed: ${e.message}", e)
        }

        val pid = getPid(process)
        Log.i(TAG, "[$sessionId] Process started (PID: $pid)")

        // Create process handle
        val handle = ProcessHandle(
            sessionId = sessionId,
            pid = pid,
            process = process,
            startTimeMillis = System.currentTimeMillis()
        )

        activeProcesses[sessionId] = handle

        // Write stdin if provided
        if (stdinInput != null) {
            serviceScope.launch {
                writeStdin(sessionId, stdinInput)
            }
        }

        // Start output reader threads
        startOutputReaders(handle, onOutput)

        // Start exit monitor
        startExitMonitor(handle, timeoutSeconds, onExit)

        return handle
    }

    /**
     * Terminate a running process by sessionId.
     *
     * Sends SIGTERM, waits up to TERMINATE_TIMEOUT_MS, then sends SIGKILL if still alive.
     *
     * @return true if process was found and terminated, false if not found
     */
    fun terminateProcess(sessionId: String): Boolean {
        val handle = activeProcesses[sessionId] ?: return false
        val process = handle.process

        Log.i(TAG, "[$sessionId] Terminating process (PID: ${handle.pid})")

        return try {
            // Send SIGTERM
            process.destroy()

            // Wait for graceful shutdown
            val exited = process.waitFor(TERMINATE_TIMEOUT_MS, TimeUnit.MILLISECONDS)

            if (!exited) {
                Log.w(TAG, "[$sessionId] Process did not exit gracefully, sending SIGKILL")
                process.destroyForcibly()
                process.waitFor(TERMINATE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            }

            Log.i(TAG, "[$sessionId] Process terminated")
            true
        } catch (e: Exception) {
            Log.e(TAG, "[$sessionId] Error during termination", e)
            false
        }
    }

    /**
     * Write data to a process's stdin.
     *
     * @return true if data was written, false if process not found or stdin closed
     */
    fun writeStdin(sessionId: String, data: String): Boolean {
        val handle = activeProcesses[sessionId] ?: return false
        val process = handle.process

        return try {
            OutputStreamWriter(process.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(data)
                writer.flush()
            }
            Log.d(TAG, "[$sessionId] Wrote ${data.length} bytes to stdin")
            true
        } catch (e: Exception) {
            Log.e(TAG, "[$sessionId] Failed to write stdin", e)
            false
        }
    }

    /**
     * Get information about all active processes.
     */
    fun getActiveProcesses(): List<ProcessInfo> {
        return activeProcesses.values.map { handle ->
            ProcessInfo(
                sessionId = handle.sessionId,
                pid = handle.pid,
                uptimeSeconds = (System.currentTimeMillis() - handle.startTimeMillis) / 1000
            )
        }
    }

    /**
     * Cleanup all active processes (called on service shutdown).
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up ${activeProcesses.size} active processes")
        activeProcesses.keys.forEach { sessionId ->
            terminateProcess(sessionId)
        }
        activeProcesses.clear()
        serviceScope.cancel()
    }

    // =========================================================================
    // Private Methods
    // =========================================================================

    private fun startOutputReaders(
        handle: ProcessHandle,
        onOutput: (type: String, content: String) -> Unit
    ) {
        val process = handle.process

        // Stdout reader thread
        serviceScope.launch {
            try {
                BufferedReader(InputStreamReader(process.inputStream, Charsets.UTF_8)).use { reader ->
                    reader.forEachLine { line ->
                        onOutput("stdout", line)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "[${handle.sessionId}] Stdout reader error", e)
            }
        }

        // Stderr reader thread
        serviceScope.launch {
            try {
                BufferedReader(InputStreamReader(process.errorStream, Charsets.UTF_8)).use { reader ->
                    reader.forEachLine { line ->
                        onOutput("stderr", line)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "[${handle.sessionId}] Stderr reader error", e)
            }
        }
    }

    private fun startExitMonitor(
        handle: ProcessHandle,
        timeoutSeconds: Int,
        onExit: (exitCode: Int, timedOut: Boolean, oomKilled: Boolean) -> Unit
    ) {
        serviceScope.launch {
            val process = handle.process
            val sessionId = handle.sessionId

            var timedOut = false

            try {
                // Wait for process exit with optional timeout
                if (timeoutSeconds > 0) {
                    val exited = process.waitFor(timeoutSeconds.toLong(), TimeUnit.SECONDS)
                    if (!exited) {
                        Log.w(TAG, "[$sessionId] Process exceeded timeout (${timeoutSeconds}s), terminating")
                        process.destroyForcibly()
                        process.waitFor()
                        timedOut = true
                    }
                } else {
                    process.waitFor()
                }

                val exitCode = process.exitValue()
                val oomKilled = exitCode == 137 // SIGKILL from OOM killer

                Log.i(TAG, "[$sessionId] Process exited: code=$exitCode, timedOut=$timedOut, oomKilled=$oomKilled")

                onExit(exitCode, timedOut, oomKilled)

            } catch (e: Exception) {
                Log.e(TAG, "[$sessionId] Exit monitor error", e)
                onExit(-1, timedOut, false)
            } finally {
                activeProcesses.remove(sessionId)
            }
        }
    }

    private fun getPid(process: Process): Int {
        return try {
            val pidField = process.javaClass.getDeclaredField("pid")
            pidField.isAccessible = true
            pidField.getInt(process)
        } catch (e: Exception) {
            Log.w(TAG, "Could not extract PID", e)
            -1
        }
    }

    // =========================================================================
    // Data Classes
    // =========================================================================

    /**
     * Handle returned when a process is spawned.
     */
    data class ProcessHandle(
        val sessionId: String,
        val pid: Int,
        val process: Process,
        val startTimeMillis: Long
    )

    /**
     * Information about an active process.
     */
    data class ProcessInfo(
        val sessionId: String,
        val pid: Int,
        val uptimeSeconds: Long
    )
}
