/// AIModel — Metadata for available AI models.
///
/// Defines model specifications, download URLs, and system requirements.
/// Architecture: 07-DATA-MODELS.md §AIModel
class AIModel {
  final String id;
  final String name;
  final String description;
  final String family; // "gemma", "llama", "mistral", etc.
  final String size; // "2B", "7B", "13B", etc.
  final String quantization; // "Q4_K_M", "Q8_0", etc.
  final int fileSizeBytes;
  final int minRamMB;
  final String downloadUrl;
  final String? checksum; // SHA256
  final ModelCapabilities capabilities;

  const AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.family,
    required this.size,
    required this.quantization,
    required this.fileSizeBytes,
    required this.minRamMB,
    required this.downloadUrl,
    this.checksum,
    required this.capabilities,
  });

  /// Get human-readable file size.
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(0)} MB';
    }
    return '${(fileSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// Check if device meets minimum RAM requirement.
  bool canRunOnDevice(int availableRamMB) {
    return availableRamMB >= minRamMB;
  }
}

/// Model capabilities and features.
class ModelCapabilities {
  final int maxContextLength; // tokens
  final bool supportsCodeGeneration;
  final bool supportsInstructionFollowing;
  final bool supportsFunctionCalling;
  final List<String> languages; // Programming languages

  const ModelCapabilities({
    required this.maxContextLength,
    required this.supportsCodeGeneration,
    required this.supportsInstructionFollowing,
    required this.supportsFunctionCalling,
    required this.languages,
  });
}

/// Predefined models available for download.
class AvailableModels {
  /// Gemma 2 2B - Instruction Tuned (Q4_K_M quantization)
  ///
  /// Best balance of quality and performance for mobile devices.
  /// Recommended for hackathon.
  static const gemma2_2b_q4km = AIModel(
    id: 'gemma-2-2b-it-Q4_K_M',
    name: 'Gemma 2 2B (Q4_K_M)',
    description: 'Compact instruction-tuned model optimized for mobile devices',
    family: 'gemma',
    size: '2B',
    quantization: 'Q4_K_M',
    fileSizeBytes: 1600000000, // ~1.5GB
    minRamMB: 2500,
    downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
    capabilities: ModelCapabilities(
      maxContextLength: 8192,
      supportsCodeGeneration: true,
      supportsInstructionFollowing: true,
      supportsFunctionCalling: false,
      languages: ['Python', 'JavaScript', 'Java', 'C++', 'Go', 'Rust'],
    ),
  );

  /// Gemma 2 2B - Instruction Tuned (Q8_0 quantization)
  ///
  /// Higher quality but larger size and more RAM required.
  static const gemma2_2b_q8 = AIModel(
    id: 'gemma-2-2b-it-Q8_0',
    name: 'Gemma 2 2B (Q8_0)',
    description: 'High-quality instruction-tuned model (requires more RAM)',
    family: 'gemma',
    size: '2B',
    quantization: 'Q8_0',
    fileSizeBytes: 2600000000, // ~2.4GB
    minRamMB: 3500,
    downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q8_0.gguf',
    capabilities: ModelCapabilities(
      maxContextLength: 8192,
      supportsCodeGeneration: true,
      supportsInstructionFollowing: true,
      supportsFunctionCalling: false,
      languages: ['Python', 'JavaScript', 'Java', 'C++', 'Go', 'Rust'],
    ),
  );

  /// Gemma 2 2B - Instruction Tuned (Q2_K quantization)
  ///
  /// Smallest size but lower quality. Use only on low-RAM devices.
  static const gemma2_2b_q2k = AIModel(
    id: 'gemma-2-2b-it-Q2_K',
    name: 'Gemma 2 2B (Q2_K)',
    description: 'Ultra-compact model for low-RAM devices (lower quality)',
    family: 'gemma',
    size: '2B',
    quantization: 'Q2_K',
    fileSizeBytes: 900000000, // ~860MB
    minRamMB: 1500,
    downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q2_K.gguf',
    capabilities: ModelCapabilities(
      maxContextLength: 8192,
      supportsCodeGeneration: true,
      supportsInstructionFollowing: true,
      supportsFunctionCalling: false,
      languages: ['Python', 'JavaScript'],
    ),
  );

  /// List of all available models.
  static const List<AIModel> all = [
    gemma2_2b_q4km, // Recommended
    gemma2_2b_q8,
    gemma2_2b_q2k,
  ];

  /// Get model by ID.
  static AIModel? getById(String id) {
    return all.cast<AIModel?>().firstWhere(
          (model) => model?.id == id,
          orElse: () => null,
        );
  }

  /// Get recommended model for device.
  static AIModel getRecommendedForDevice(int availableRamMB) {
    if (availableRamMB >= 3500) {
      return gemma2_2b_q8; // Best quality if RAM available
    } else if (availableRamMB >= 2500) {
      return gemma2_2b_q4km; // Good balance
    } else {
      return gemma2_2b_q2k; // Low-end devices
    }
  }
}
