package com.offlinemobileide.aioide.channels

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * SecretsChannel — Kotlin side of the `ide/secrets` Platform Channel.
 *
 * Manages secure storage of API keys and credentials using Android's
 * EncryptedSharedPreferences (backed by Android Keystore via AES256-GCM).
 *
 * Architecture: 06-SECURITY.md §11 — API keys NEVER pass through Dart.
 * Keys are stored and retrieved entirely within this Kotlin layer.
 * Dart only sends/receives the key NAME (identifier), never the key VALUE.
 *
 * Methods (MethodChannel `ide/secrets`):
 *   storeKey(name, value)     → { success: Boolean }
 *   hasKey(name)              → { exists: Boolean }
 *   deleteKey(name)           → { success: Boolean }
 *   getKeyMasked(name)        → { masked: String }
 *     Returns last-4-chars masked key (e.g., "••••••••abcd") for Settings UI display.
 *     NEVER returns the full key value to Dart.
 *
 * TODO (Phase 8): Add a `useKey(name, action)` call that allows performing
 *   an HTTP request with the key injected server-side without exposing it to Dart.
 */
class SecretsChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "ide/secrets"
        private const val PREFS_FILE = "aioide_secure_prefs"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)

    private val encryptedPrefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS_FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "storeKey" -> {
                val name = call.argument<String>("name") ?: return result.error("INVALID_ARG", "name required", null)
                val value = call.argument<String>("value") ?: return result.error("INVALID_ARG", "value required", null)
                encryptedPrefs.edit().putString(name, value).apply()
                result.success(mapOf("success" to true))
            }
            "hasKey" -> {
                val name = call.argument<String>("name") ?: return result.error("INVALID_ARG", "name required", null)
                result.success(mapOf("exists" to encryptedPrefs.contains(name)))
            }
            "deleteKey" -> {
                val name = call.argument<String>("name") ?: return result.error("INVALID_ARG", "name required", null)
                encryptedPrefs.edit().remove(name).apply()
                result.success(mapOf("success" to true))
            }
            "getKeyMasked" -> {
                val name = call.argument<String>("name") ?: return result.error("INVALID_ARG", "name required", null)
                val value = encryptedPrefs.getString(name, null)
                if (value == null) {
                    result.success(mapOf("masked" to null))
                } else {
                    // Show only last 4 characters — never the full key
                    val last4 = value.takeLast(4)
                    val masked = "•".repeat(maxOf(8, value.length - 4)) + last4
                    result.success(mapOf("masked" to masked))
                }
            }
            else -> result.notImplemented()
        }
    }
}
