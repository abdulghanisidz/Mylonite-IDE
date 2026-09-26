import 'dart:async';
import '../logging_service.dart';
import '../../models/enums.dart';
import 'llama_cpp_bindings.dart';
import 'model_download_service.dart';
import '../../models/ai_model.dart';

/// InferenceService — High-level API for AI inference.
///
/// Provides:
/// - Model lifecycle management (load, unload, reload)
/// - Prompt template system for code generation
/// - Streaming text generation
/// - Context management
/// - Error recovery
///
/// Architecture: 05-OFFLINE-AI.md §7
class InferenceService {
  InferenceService._();
  static final InferenceService instance = InferenceService._();

  final _bindings = LlamaCppBindings.instance;
  final _downloadService = ModelDownloadService.instance;

  String? _currentModelId;
  AIModel? _currentModel;

  /// Initialize the inference service.
  Future<void> initialize() async {
    log.info(LogSubsystem.ai, 'Initializing inference service...');
    // No initialization needed for mock implementation
    log.info(LogSubsystem.ai, 'Inference service initialized');
  }

  /// Load a specific model by ID.
  ///
  /// Returns true on success, false if model not downloaded or load failed.
  Future<bool> loadModel(String modelId, {int contextSize = 2048}) async {
    log.info(LogSubsystem.ai, 'Loading model: $modelId');

    // Get model metadata
    final model = AvailableModels.getById(modelId);
    if (model == null) {
      log.error(LogSubsystem.ai, 'Unknown model ID: $modelId');
      return false;
    }

    // Check if model is downloaded
    final modelPath = await _downloadService.getModelPath(modelId);
    if (modelPath == null) {
      log.error(LogSubsystem.ai, 'Model not downloaded: $modelId');
      return false;
    }

    // Unload current model if any
    if (_bindings.isModelLoaded) {
      await _bindings.unloadModel();
    }

    // Load new model
    final success = await _bindings.loadModel(modelPath, contextSize: contextSize);

    if (success) {
      _currentModelId = modelId;
      _currentModel = model;
      log.info(LogSubsystem.ai, 'Model loaded: ${model.name}');
    } else {
      log.error(LogSubsystem.ai, 'Failed to load model: $modelId');
    }

    return success;
  }

  /// Unload the current model.
  Future<void> unloadModel() async {
    await _bindings.unloadModel();
    _currentModelId = null;
    _currentModel = null;
  }

  /// Generate code based on a natural language prompt.
  ///
  /// Uses code generation prompt template.
  Stream<String> generateCode({
    required String taskDescription,
    required String language,
    String? existingCode,
    String? errorContext,
  }) async* {
    if (!_bindings.isModelLoaded) {
      throw Exception('No model loaded. Call loadModel() first.');
    }

    // Build prompt using template
    final prompt = _buildCodeGenerationPrompt(
      taskDescription: taskDescription,
      language: language,
      existingCode: existingCode,
      errorContext: errorContext,
    );

    log.info(LogSubsystem.ai, 'Generating code for: $taskDescription');
    log.debug(LogSubsystem.ai, 'Language: $language');

    // Generate with appropriate parameters for code
    yield* _bindings.generate(
      prompt: prompt,
      maxTokens: 1024,
      temperature: 0.2, // Low temperature for more deterministic code
      stopSequences: ['```\n\n', '<|end|>', '<|endoftext|>'],
    );
  }

  /// Generate a chat response.
  ///
  /// Uses conversational prompt template.
  Stream<String> generateChatResponse({
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
  }) async* {
    if (!_bindings.isModelLoaded) {
      throw Exception('No model loaded. Call loadModel() first.');
    }

    final prompt = _buildChatPrompt(
      userMessage: userMessage,
      history: conversationHistory,
    );

    log.info(LogSubsystem.ai, 'Generating chat response');

    yield* _bindings.generate(
      prompt: prompt,
      maxTokens: 512,
      temperature: 0.7,
      stopSequences: ['<|end|>', '<|endoftext|>'],
    );
  }

  /// Build code generation prompt using Gemma 2 instruction format.
  ///
  /// Format:
  /// ```
  /// <start_of_turn>user
  /// [Task description]
  /// <end_of_turn>
  /// <start_of_turn>model
  /// [Generated code]
  /// ```
  String _buildCodeGenerationPrompt({
    required String taskDescription,
    required String language,
    String? existingCode,
    String? errorContext,
  }) {
    final buffer = StringBuffer();

    // System message (implicit in Gemma 2)
    buffer.writeln('<start_of_turn>user');
    buffer.writeln('You are an expert $language programmer.');
    buffer.writeln('Generate clean, working $language code for the following task.');
    buffer.writeln();

    // Task description
    buffer.writeln('Task: $taskDescription');
    buffer.writeln();

    // Include existing code if provided (for fixing errors)
    if (existingCode != null) {
      buffer.writeln('Existing code:');
      buffer.writeln('```$language');
      buffer.writeln(existingCode);
      buffer.writeln('```');
      buffer.writeln();
    }

    // Include error context if provided
    if (errorContext != null) {
      buffer.writeln('Error to fix:');
      buffer.writeln(errorContext);
      buffer.writeln();
    }

    // Instructions
    buffer.writeln('Requirements:');
    buffer.writeln('- Write complete, executable code');
    buffer.writeln('- Include necessary imports');
    buffer.writeln('- Add helpful comments');
    buffer.writeln('- Handle edge cases');
    if (errorContext != null) {
      buffer.writeln('- Fix the error shown above');
    }
    buffer.writeln();

    buffer.writeln('Respond with the code in a markdown code block:');
    buffer.writeln('<end_of_turn>');
    buffer.writeln('<start_of_turn>model');

    return buffer.toString();
  }

  /// Build chat prompt using Gemma 2 instruction format.
  String _buildChatPrompt({
    required String userMessage,
    List<Map<String, String>>? history,
  }) {
    final buffer = StringBuffer();

    // Include conversation history if provided
    if (history != null) {
      for (final turn in history) {
        final role = turn['role'];
        final content = turn['content'];
        if (role == 'user') {
          buffer.writeln('<start_of_turn>user');
          buffer.writeln(content);
          buffer.writeln('<end_of_turn>');
        } else if (role == 'assistant') {
          buffer.writeln('<start_of_turn>model');
          buffer.writeln(content);
          buffer.writeln('<end_of_turn>');
        }
      }
    }

    // Add current message
    buffer.writeln('<start_of_turn>user');
    buffer.writeln(userMessage);
    buffer.writeln('<end_of_turn>');
    buffer.writeln('<start_of_turn>model');

    return buffer.toString();
  }

  /// Extract code from a markdown code block.
  ///
  /// Input: "```python\nprint('hello')\n```"
  /// Output: "print('hello')"
  String extractCodeFromMarkdown(String text) {
    // Match ```language\ncode\n```
    final pattern = RegExp(r'```[\w]*\n(.*?)\n```', dotAll: true);
    final match = pattern.firstMatch(text);

    if (match != null) {
      return match.group(1)?.trim() ?? text;
    }

    // Fallback: return text as-is
    return text.trim();
  }

  /// Get current model info.
  AIModel? get currentModel => _currentModel;
  String? get currentModelId => _currentModelId;
  bool get isModelLoaded => _bindings.isModelLoaded;
}
