package com.offlinemobileide.aioide.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * StorageChannel — Kotlin side of the `ide/storage` Platform Channel.
 *
 * Implements SAF (Storage Access Framework) operations using the modern
 * ActivityResultLauncher API (no deprecated startActivityForResult).
 *
 * Each SAF operation (file picker, directory picker) suspends the Dart
 * call via a pending [MethodChannel.Result] until the user dismisses the
 * system picker.  Only one picker can be open at a time — attempting a
 * second returns an error.
 *
 * Methods (MethodChannel `ide/storage`):
 *   openFilePicker(mimeType: String)  → { uri: String? }
 *   openDirectoryPicker()             → { uri: String? }
 *   readFromUri(uri: String)          → { bytes: ByteArray }
 *   writeToUri(uri, bytes)            → { success: Boolean }
 *   takePersistablePermission(uri)    → { success: Boolean }
 *
 * Architecture: 02-ARCHITECTURE.md §9.2, 06-SECURITY.md §20.2
 */
class StorageChannel(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    // Cast to ComponentActivity internally to avoid weird Kotlin class resolution issues
    private val activity: ComponentActivity = context as ComponentActivity

    companion object {
        const val METHOD_CHANNEL = "ide/storage"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)

    // Pending result waiting for the file/directory picker to return.
    // Only one can be active at a time.
    private var pendingResult: MethodChannel.Result? = null

    // ── ActivityResultLaunchers ───────────────────────────────────────────────

    /** Launcher for GET_CONTENT (single file pick). */
    private val filePickerLauncher: ActivityResultLauncher<String> =
        activity.registerForActivityResult(
            ActivityResultContracts.GetContent()
        ) { uri: Uri? ->
            val pending = pendingResult ?: return@registerForActivityResult
            pendingResult = null
            if (uri != null) {
                pending.success(mapOf("uri" to uri.toString()))
            } else {
                // User cancelled — return null uri (not an error)
                pending.success(mapOf("uri" to null))
            }
        }

    /** Launcher for OPEN_DOCUMENT_TREE (directory pick for export). */
    private val dirPickerLauncher: ActivityResultLauncher<Uri?> =
        activity.registerForActivityResult(
            ActivityResultContracts.OpenDocumentTree()
        ) { uri: Uri? ->
            val pending = pendingResult ?: return@registerForActivityResult
            pendingResult = null
            if (uri != null) {
                // Take persistable permission so the URI survives app restarts
                try {
                    activity.contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                } catch (_: Exception) {
                    // Non-fatal — proceed without persisting
                }
                pending.success(mapOf("uri" to uri.toString()))
            } else {
                pending.success(mapOf("uri" to null))
            }
        }

    init {
        methodChannel.setMethodCallHandler(this)
    }

    // ── Method dispatch ───────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openFilePicker"           -> handleOpenFilePicker(call, result)
            "openDirectoryPicker"      -> handleOpenDirectoryPicker(result)
            "readFromUri"              -> handleReadFromUri(call, result)
            "writeToUri"               -> handleWriteToUri(call, result)
            "takePersistablePermission"-> handleTakePersistablePermission(call, result)
            else                       -> result.notImplemented()
        }
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    private fun handleOpenFilePicker(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("PICKER_BUSY", "A file picker is already open.", null)
            return
        }
        val mimeType = call.argument<String>("mimeType") ?: "*/*"
        pendingResult = result
        filePickerLauncher.launch(mimeType)
    }

    private fun handleOpenDirectoryPicker(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("PICKER_BUSY", "A directory picker is already open.", null)
            return
        }
        pendingResult = result
        dirPickerLauncher.launch(null)
    }

    private fun handleReadFromUri(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARG", "uri is required", null)
            return
        }
        try {
            val uri = Uri.parse(uriString)
            val bytes = activity.contentResolver.openInputStream(uri)?.use {
                it.readBytes()
            }
            if (bytes == null) {
                result.error("READ_FAILED", "Could not open URI for reading.", null)
            } else {
                result.success(mapOf("bytes" to bytes.toList()))
            }
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message, null)
        }
    }

    private fun handleWriteToUri(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        val bytes = call.argument<List<Int>>("bytes")
        if (uriString == null || bytes == null) {
            result.error("INVALID_ARG", "uri and bytes are required", null)
            return
        }
        try {
            val uri = Uri.parse(uriString)
            activity.contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes.map { it.toByte() }.toByteArray())
                stream.flush()
            }
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            result.error("WRITE_ERROR", e.message, null)
        }
    }

    private fun handleTakePersistablePermission(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARG", "uri is required", null)
            return
        }
        return try {
            val uri = Uri.parse(uriString)
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
}
