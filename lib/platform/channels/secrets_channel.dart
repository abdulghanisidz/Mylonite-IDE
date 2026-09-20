import 'package:flutter/services.dart';

/// Dart side of the `ide/secrets` Platform Channel.
///
/// API keys and credentials are NEVER stored in Dart. This channel
/// provides only the ability to name a key, check its existence,
/// and retrieve a masked display version.
///
/// The full key value lives exclusively in Kotlin's EncryptedSharedPreferences
/// backed by Android Keystore.
///
/// Architecture: 06-SECURITY.md §11, 02-ARCHITECTURE.md §10.2
class SecretsChannel {
  SecretsChannel._();
  static final SecretsChannel instance = SecretsChannel._();

  static const _method = MethodChannel('ide/secrets');

  /// Store an API key by name. The [value] is encrypted immediately
  /// and this call returns before the value is accessible in Dart again.
  Future<bool> storeKey(String name, String value) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'storeKey',
      {'name': name, 'value': value},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Returns true if a key with [name] is stored.
  Future<bool> hasKey(String name) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'hasKey',
      {'name': name},
    );
    return result?['exists'] as bool? ?? false;
  }

  /// Deletes the key with [name].
  Future<bool> deleteKey(String name) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'deleteKey',
      {'name': name},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Returns a masked representation of the key (e.g. `"••••••••abcd"`)
  /// for display in the Settings UI. Returns null if the key does not exist.
  ///
  /// This NEVER returns the actual key value.
  Future<String?> getKeyMasked(String name) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'getKeyMasked',
      {'name': name},
    );
    return result?['masked'] as String?;
  }
}

/// Well-known secret key names.
/// Using constants prevents typos across provider implementations.
class SecretKeys {
  SecretKeys._();
  static const String geminiApiKey = 'provider_apikey_gemini';
  static const String openAiApiKey = 'provider_apikey_openai';
}
