# 05 — Offline AI

**Project:** Mylonite IDE  
**Version:** 0.1 (Architecture Phase)  
**Status:** Pre-implementation  
**Last Updated:** 2026-08-30

---

## Table of Contents

1. [Overview](#1-overview)
2. [Why Local Inference is Hard on Mobile](#2-why-local-inference-is-hard-on-mobile)
3. [Inference Engine Evaluation](#3-inference-engine-evaluation)
4. [Decision: llama.cpp](#4-decision-llamacpp)
5. [Model Formats](#5-model-formats)
6. [Quantization](#6-quantization)
7. [Model Categories and Size Tiers](#7-model-categories-and-size-tiers)
8. [Memory Requirements](#8-memory-requirements)
9. [CPU Inference on ARM64](#9-cpu-inference-on-arm64)
10. [GPU Acceleration](#10-gpu-acceleration)
11. [NPU Acceleration](#11-npu-acceleration)
12. [Context Windows and KV Cache](#12-context-windows-and-kv-cache)
13. [Model Lifecycle](#13-model-lifecycle)
14. [Model Manager](#14-model-manager)
15. [Streaming Generation](#15-streaming-generation)
16. [Cancellation](#16-cancellation)
17. [Performance Benchmarks and Targets](#17-performance-benchmarks-and-targets)
18. [Battery and Thermal Impact](#18-battery-and-thermal-impact)
19. [Device Tier Compatibility](#19-device-tier-compatibility)
20. [Model Profiles: Tiny, Balanced, Power](#20-model-profiles-tiny-balanced-power)
21. [Model Selection and Compatibility Check](#21-model-selection-and-compatibility-check)
22. [Dart FFI Binding Design](#22-dart-ffi-binding-design)
23. [Model Storage and Management](#23-model-storage-and-management)
24. [Architectural Decision Records](#24-architectural-decision-records)
25. [Open Questions](#25-open-questions)

---

## 1. Overview

The Offline AI subsystem provides local language model inference on Android devices. It is the engine that powers the AI assistant and the AI agent when no cloud provider is configured or available.

The central design goal is: **a language model must be usable on a mid-range Android smartphone with 6 GB RAM, without internet access, with acceptable speed and quality for software development assistance.**

This document covers how to achieve that goal, what the tradeoffs are, what is confirmed versus experimental, and how the system is architected to support it.

---

## 2. Why Local Inference is Hard on Mobile

Before choosing an approach, it is important to understand the actual constraints.

### 2.1 RAM

A language model's working memory requirement is approximately:

```
RAM ≈ (parameter_count × bits_per_weight / 8) + KV_cache_size
```

For a 7B model at 4-bit quantization:
```
Weights: 7,000,000,000 × 4 / 8 = 3,500,000,000 bytes ≈ 3.5 GB
KV cache (2K context): ~500 MB–1 GB depending on layers and heads
Total: ~4–4.5 GB
```

A 6 GB device running Android has approximately 3.5–4 GB free after the OS. Running a 7B Q4 model simultaneously with the Flutter app, Python runtime, and system processes is at the edge of feasibility on Tier B hardware and is realistic only on Tier C.

A 3B model at 4-bit quantization:
```
Weights: ~1.5–1.9 GB
KV cache (2K context): ~300–500 MB
Total: ~2–2.5 GB
```
This is comfortably within reach on Tier B devices.

A 1B model at 4-bit quantization:
```
Weights: ~600–900 MB
KV cache: ~100–200 MB
Total: ~700 MB–1.1 GB
```
Feasible on Tier A devices with careful memory management.

### 2.2 CPU Speed

Mobile ARM64 CPUs are fast for many tasks but are not optimised for the matrix multiply operations that dominate LLM inference. Token generation throughput on CPU is slow:

- 1B Q4 model on Snapdragon 7-series: approximately 8–20 tokens/second (varies widely)
- 3B Q4 model on Snapdragon 7-series: approximately 3–8 tokens/second
- 7B Q4 model on Snapdragon 8-series: approximately 4–10 tokens/second

At 5 tokens/second, generating a 100-token response takes 20 seconds. At 3 tokens/second, it takes 33 seconds. These numbers are workable for an agent that generates plans and tool calls (typically 50–150 tokens per step), but they produce a noticeably slow experience compared to cloud APIs.

Streaming token output (displaying tokens as they are generated) is essential for usability — the user sees progress immediately rather than waiting for the full response.

### 2.3 Thermal Throttling

Sustained CPU inference generates significant heat. After 2–5 minutes of continuous inference, ARM64 CPUs reduce their clock frequency to manage temperature. This reduces throughput by 20–50%.

The application must monitor thermal status and reduce inference load (fewer threads, longer pauses between batches) when throttling is detected.

### 2.4 Battery Drain

Continuous LLM inference is battery-intensive. A sustained inference session may drain 10–20% battery per hour on a mid-range device. This is acceptable for development tasks (which are active, engaged sessions) but must be communicated to the user.

---

## 3. Inference Engine Evaluation

Multiple local inference engines were evaluated. The goal was to find the best option for ARM64 Android, offline, with GGUF model support, active maintenance, and an accessible integration path from Flutter/Dart.

### 3.1 Candidates

#### llama.cpp

| Property | Detail |
|---|---|
| Language | C/C++ |
| Model formats | GGUF (primary), GGML (legacy) |
| ARM64 support | Yes — NEON intrinsics, optional SVE |
| Android support | Yes — confirmed in production apps |
| GPU | Vulkan (Android), OpenCL, CUDA (not mobile) |
| NPU | NNAPI (experimental) |
| Integration | C API; Dart FFI; JNI |
| License | MIT |
| Maintenance | Very active (weekly releases as of 2026) |
| Ecosystem | Largest GGUF model ecosystem; most tested models |
| Maturity | Production-ready for mobile |

#### MNN (Mobile Neural Network, Alibaba)

| Property | Detail |
|---|---|
| Language | C++ |
| Model formats | MNN proprietary (requires conversion) |
| ARM64 support | Yes — well optimised |
| Android support | Yes — designed for mobile |
| GPU | OpenCL, Vulkan, Metal |
| NPU | NNAPI, Hexagon |
| LLM support | Added relatively recently; less tested for large LLMs |
| Integration | C/C++ API; JNI |
| License | Apache 2.0 |
| Maturity | Good for vision/audio; LLM support less proven |

#### NCNN (Tencent)

| Property | Detail |
|---|---|
| Language | C++ |
| Model formats | NCNN proprietary |
| ARM64 support | Excellent — historically mobile-first |
| Android support | Yes |
| LLM support | Limited — primarily a vision inference framework |
| Maturity | Not suitable for LLM inference |

#### ExecuTorch (Meta)

| Property | Detail |
|---|---|
| Language | C++ |
| Model formats | ExecuTorch format (requires PyTorch export) |
| ARM64 support | Yes |
| Android support | Experimental as of 2025 |
| LLM support | Growing; Llama-based models primary focus |
| Integration | C++ API; JNI |
| License | BSD |
| Maturity | Pre-production for mobile LLMs as of 2026 |

#### MediaPipe LLM Inference (Google)

| Property | Detail |
|---|---|
| Language | C++ (Google MediaPipe) |
| Model formats | TFLite, MediaPipe specific |
| Android support | Yes — designed by Google for Android |
| GPU | Delegate-based (OpenGL ES, Metal) |
| NPU | Limited |
| LLM model selection | Limited to models MediaPipe supports |
| Integration | Java/Kotlin API; relatively easy for Android |
| License | Apache 2.0 |
| Maturity | Growing; limited model choice |

### 3.2 Comparison Summary

| Criterion | llama.cpp | MNN | ExecuTorch | MediaPipe |
|---|---|---|---|---|
| ARM64 maturity | ★★★★★ | ★★★★ | ★★★ | ★★★ |
| LLM-specific | ★★★★★ | ★★★ | ★★★★ | ★★★ |
| GGUF model support | ★★★★★ | ✗ | ✗ | ✗ |
| Model ecosystem | ★★★★★ | ★★ | ★★ | ★★ |
| Android integration | ★★★★ | ★★★★ | ★★★ | ★★★★★ |
| Dart FFI feasibility | ★★★★★ | ★★★ | ★★★ | ★★ |
| Community/maintenance | ★★★★★ | ★★★ | ★★★ | ★★★ |
| GPU support (Android) | ★★★★ | ★★★★ | ★★★ | ★★★★ |

---

## 4. Decision: llama.cpp

**llama.cpp is selected as the inference engine for V1.**

**Rationale:**

1. It is the most mature, most actively developed, and most widely deployed C/C++ LLM inference engine for constrained hardware.
2. GGUF is the dominant model format for open-weights models. Virtually every open-weights model has GGUF variants available (Llama 3, Phi-3, Gemma 2, Qwen 2, Mistral, SmolLM, etc.).
3. It has confirmed ARM64 NEON optimisation, meaning matrix multiply operations use SIMD instructions that are 4–8x faster than scalar code.
4. It has a stable C API (`llama.h`) that can be bound via Dart FFI without a JNI intermediary.
5. It has existing Android deployment in production (Ollama Android, LM Studio mobile prototype, several open-source chat apps).
6. Vulkan GPU acceleration on Android is available (though experimental).
7. The MIT license imposes no restrictions on commercial or app distribution use.

**Risks:**

- The llama.cpp API evolves rapidly. The FFI binding layer must be version-pinned and updated deliberately.
- NNAPI/NPU support is experimental and may not provide reliable performance improvements across device vendors.
- Dart FFI requires compiling llama.cpp as a shared library for `arm64-v8a` and potentially `armeabi-v7a`.

---

## 5. Model Formats

### 5.1 GGUF

GGUF (GPT-Generated Unified Format) is the primary model format for llama.cpp. It is a binary format that stores:
- Model weights (quantized or full precision)
- Model architecture metadata (layer count, head count, context length, etc.)
- Tokenizer data (vocabulary, special tokens, BPE merge rules)
- Chat template (the instruction format expected by the model)
- Quantization metadata

A GGUF file is a single self-contained file, which simplifies distribution, integrity checking, and management. This is a significant advantage over formats that split weights across multiple files.

**File naming convention:** `<model-name>-<parameter-count>-<quantization>.gguf`
Example: `llama-3-3b-q4_k_m.gguf`

### 5.2 Supported Quantization Formats in GGUF

| Format | Bits/Weight | Notes |
|---|---|---|
| F32 | 32 | Full precision; not practical on mobile |
| F16 | 16 | Half precision; 2x smaller than F32; still large |
| Q8_0 | 8 | Good quality; 8-bit quantization |
| Q4_K_M | ~4.5 | Recommended balance of quality and size |
| Q4_K_S | ~4.3 | Slightly smaller; slightly lower quality |
| Q3_K_M | ~3.5 | Smaller; noticeable quality degradation |
| Q2_K | ~2.6 | Very small; significant quality loss |
| IQ4_XS | ~4.3 | Improved quantization; better quality/size than Q4_K |

**Recommended for this application:**

- **Primary:** `Q4_K_M` — best balance of model quality and RAM efficiency
- **Space-constrained:** `Q3_K_M` — acceptable for simple coding tasks on very tight storage
- **Performance testing:** `Q8_0` — use when validating that quality issues are not quantization artifacts

---

## 6. Quantization

Quantization reduces the precision of model weights from 32-bit or 16-bit floats to lower-bit integers. This reduces:
- Model file size (4x smaller for Q4 vs F32)
- RAM required to load the model
- Memory bandwidth during inference (faster computation)

The cost is a small reduction in model quality. For coding tasks at 4-bit quantization, quality degradation is generally minimal compared to the full-precision model.

### 6.1 Quality vs Size Tradeoff

| Quantization | Relative RAM | Quality Impact (coding tasks) | Recommendation |
|---|---|---|---|
| F16 | 1.0x baseline | None | Desktop only |
| Q8_0 | 0.5x | Negligible | Tier C |
| Q4_K_M | 0.27x | Minimal | Tier B–C primary |
| Q3_K_M | 0.21x | Moderate | Tier A–B fallback |
| Q2_K | 0.16x | Significant | Last resort |

### 6.2 Context Window Impact on Quality

Beyond weight quantization, the KV cache (key-value cache for attention layers) can also be quantized. llama.cpp supports KV cache quantization which reduces the memory used by the context window. This is particularly useful for maintaining a longer context on memory-constrained devices.

The application should expose KV cache quantization as an advanced setting. Default: off (better quality). Option: Q8 or Q4 KV cache (lower RAM for large contexts).

---

## 7. Model Categories and Size Tiers

Models are grouped into three profiles based on parameter count and expected hardware requirements.

### 7.1 Tiny (~1B parameters)

| Property | Detail |
|---|---|
| Parameter count | 0.5B – 1.5B |
| GGUF size (Q4_K_M) | ~400 MB – 1 GB |
| RAM required | ~600 MB – 1.2 GB |
| Inference speed | Fast (15–30+ tok/s on Tier B) |
| Coding capability | Basic — simple single-file scripts, syntax help, explanations |
| Context length | Typically 2K–4K tokens |
| Suitable for | Tier A (primary), Tier B (fast option) |
| Example models | SmolLM2-1.7B, Qwen2.5-Coder-0.5B, Phi-3.5-mini (larger end) |

### 7.2 Balanced (~3B parameters)

| Property | Detail |
|---|---|
| Parameter count | 2B – 4B |
| GGUF size (Q4_K_M) | ~1.3 GB – 2.5 GB |
| RAM required | ~1.7 GB – 3 GB |
| Inference speed | Moderate (5–12 tok/s on Tier B) |
| Coding capability | Good — multi-file projects, debugging, refactoring |
| Context length | Typically 4K–8K tokens |
| Suitable for | Tier B (primary), Tier C |
| Example models | Qwen2.5-Coder-3B, Phi-3-mini-4k-instruct, Gemma-2-2B |

### 7.3 Power (~7B parameters)

| Property | Detail |
|---|---|
| Parameter count | 6B – 8B |
| GGUF size (Q4_K_M) | ~3.8 GB – 5 GB |
| RAM required | ~4.5 GB – 6 GB |
| Inference speed | Slow (2–5 tok/s on Tier C) |
| Coding capability | Excellent — complex reasoning, multi-step plans |
| Context length | Typically 8K–128K tokens |
| Suitable for | Tier C only |
| Example models | Llama-3.2-8B, Qwen2.5-Coder-7B, DeepSeek-Coder-6.7B |

> **Note:** Specific model recommendations should not be hard-coded into the application. Models evolve rapidly. The model metadata system must support any GGUF-format model, and the profiles above define capability expectations, not specific model requirements.

---

## 8. Memory Requirements

### 8.1 Detailed RAM Calculation

Total inference RAM = model weights + KV cache + runtime overhead

**KV cache formula:**
```
KV_cache_bytes = 2 × n_layers × n_heads × head_dim × context_length × bytes_per_element

For a typical 3B model (28 layers, 32 heads, 128 head_dim):
At F16 (2 bytes), 4K context:
KV = 2 × 28 × 32 × 128 × 4096 × 2 = 1,476,395,008 bytes ≈ 1.4 GB

At Q8 KV quantization:
KV = ~740 MB

At Q4 KV quantization:
KV = ~370 MB
```

This demonstrates that context length has a very significant impact on RAM requirements — **context length must be kept conservative on mobile**. Using a 2K context instead of 4K halves the KV cache requirement.

### 8.2 Recommended Context Lengths by Device Tier

| Model Size | Tier A | Tier B | Tier C |
|---|---|---|---|
| 1B | 2K | 4K | 8K |
| 3B | Not recommended | 2K | 4K |
| 7B | Not feasible | Not recommended | 2K–4K |

The `ContextManager` (see `03-AI-AGENT.md`) must stay within these bounds when assembling prompts.

### 8.3 Memory Reservation Policy

Before loading a model, the application checks available RAM:

```
availableRAM = ActivityManager.MemoryInfo.availMem
requiredRAM = model.estimatedWeightBytes + kvCacheBytes(model, contextLength) + app_overhead(300MB)

if availableRAM < requiredRAM + safety_margin(500MB):
    return ModelLoadResult.INSUFFICIENT_MEMORY
```

The safety margin accounts for Android allocating memory during inference for other system processes. This margin is conservative; it may need tuning based on profiling.

---

## 9. CPU Inference on ARM64

### 9.1 NEON Intrinsics

llama.cpp's ARM64 CPU inference path uses NEON (Advanced SIMD) instructions, which are available on all ARM64 processors since ARMv8. NEON provides 128-bit SIMD operations that can process 4 × 32-bit or 8 × 16-bit values simultaneously.

For 4-bit quantized matrix multiplication (the dominant operation in LLM inference), NEON provides a significant speedup over scalar code. The key llama.cpp kernel functions (`ggml_vec_dot_q4_K_q8_K` etc.) are hand-optimised for NEON.

The llama.cpp build must be compiled with:
```
-march=armv8-a+fp16+dotprod
```
The `dotprod` extension (int8 dot product) is available on most modern ARM64 SoCs (Snapdragon 700+, Dimensity 800+) and provides additional speedup for quantized operations.

### 9.2 Thread Configuration

llama.cpp uses a thread pool for parallel matrix operations. The number of threads is a critical tuning parameter:

| Device Tier | Recommended Threads | Reasoning |
|---|---|---|
| Tier A | 2–3 | 4 cores; leave headroom for OS and UI |
| Tier B | 4–5 | 8 cores; use half the cores |
| Tier C | 6–8 | 10–12 cores; use performance cores |

On big.LITTLE architectures (which all modern ARM SoCs use), inference threads should run on performance cores (big cores), not efficiency cores. llama.cpp supports setting CPU affinity masks, but this requires testing on specific SoC families. In V1, the default thread count is used; CPU affinity is a Phase 9+ tuning item.

### 9.3 Batch Size

llama.cpp's batch size controls how many tokens are processed in a single forward pass during the prompt processing phase (prefill). Larger batches are faster but use more RAM.

| Device Tier | Recommended Batch Size |
|---|---|
| Tier A | 128–256 |
| Tier B | 256–512 |
| Tier C | 512–1024 |

The batch size only affects the prompt processing phase, not the autoregressive token generation phase. For long agent prompts, a larger batch size means faster first-token latency.

---

## 10. GPU Acceleration

### 10.1 Vulkan Backend

llama.cpp includes a Vulkan compute backend. Vulkan is available on Android 7.0+ (API 24+) and is the preferred GPU API for compute on Android.

The Vulkan backend offloads matrix operations to the GPU. For mobile GPUs (Adreno, Mali, Imagination), this can provide a 2–5x speedup for smaller matrix operations, but:

- Mobile GPU VRAM is shared with main RAM (UMA — Unified Memory Architecture)
- There is no separate "load model to VRAM" step; model weights are already in system RAM
- Mobile GPU memory bandwidth may not exceed the CPU NEON path for heavily quantized models
- Vulkan compute on mobile is less tested than desktop

**Feasibility:** Likely Feasible with performance benefit. Requires prototype to confirm on target SoCs (Snapdragon Adreno vs. Dimensity Mali differ significantly in Vulkan compute capability).

**V1 decision:** CPU inference with NEON is the guaranteed path. Vulkan is an opt-in advanced option that users can enable if their device supports it. The application will not default to Vulkan without testing confirming its benefit.

### 10.2 OpenCL Backend

llama.cpp does not have an OpenCL backend (as of 2026). OpenCL on Android is available but varies by device — many devices do not ship OpenCL drivers. Not a viable path.

### 10.3 GPU Layers

llama.cpp supports "GPU offloading" — loading some model layers onto the GPU while keeping others on CPU. This can improve throughput even when the full model does not fit in GPU memory (in the traditional sense; on Android with UMA, this is about which processor handles which layers).

The number of layers to offload is configurable (`n_gpu_layers`). In V1, this defaults to 0 (full CPU). When Vulkan is enabled and tested, this will be tunable.

---

## 11. NPU Acceleration

### 11.1 Android NNAPI

Android Neural Networks API (NNAPI) is a hardware abstraction layer that routes operations to the device's NPU, DSP, or GPU. Available since Android 8.1 (API 27).

llama.cpp had experimental NNAPI support in earlier versions. As of 2025–2026, NNAPI's suitability for LLM inference remains limited:
- NNAPI supports fixed quantized operations but not all the operations LLMs require
- Not all devices expose useful LLM-relevant operations through NNAPI
- Latency on NNAPI for iterative autoregressive generation is not well-characterized

**Status: Experimental.** The application will not depend on NNAPI in V1. If the inference engine supports it as an optional delegate and it improves performance on specific devices, it can be exposed as an advanced option.

### 11.2 Vendor-Specific NPU APIs

Qualcomm's Hexagon NPU, MediaTek's APU, and Samsung's Exynos NPU each have vendor-specific SDKs. These are not available to third-party apps without vendor partnerships or are only accessible through NNAPI.

**Status: Out of scope for V1.** Vendor NPU APIs would require per-vendor development effort and are not feasible for an open general-purpose application.

### 11.3 Realistic Assessment

For V1, **CPU inference with NEON is the only reliable acceleration path**. GPU (Vulkan) is a Phase 9+ optional enhancement. NPU is not a practical option for V1.

This is a known limitation. The honest communication to users is: "AI inference on this application uses the CPU. It is slower than cloud AI. For best performance, use a high-end device."

---

## 12. Context Windows and KV Cache

### 12.1 Context Window

The context window (`n_ctx` in llama.cpp) defines the maximum number of tokens the model can process in one forward pass — its working memory.

The context window must be set at model load time. It cannot be changed without reloading the model.

The application sets `n_ctx` based on:
1. The model's maximum supported context length (from GGUF metadata)
2. The device tier (Table in Section 8.2)
3. The available RAM after accounting for model weights

### 12.2 KV Cache

The KV (key-value) cache stores the intermediate attention computations for all tokens already processed. It grows linearly with context length. Once the context is full, llama.cpp truncates or rolls over older content.

The KV cache is allocated at model load time, not dynamically during inference. This means RAM is committed as soon as the model is loaded, regardless of whether the current prompt uses the full context.

**Implication for the application:** Loading a 3B model with 4K context on a 6 GB device allocates approximately 2.5–3 GB of RAM immediately. This is the dominant reason for the conservative context windows in the device tier table.

### 12.3 Context Management and the ContextManager

The `ContextManager` in the agent system (see `03-AI-AGENT.md`) must stay well within the model's `n_ctx`. The recommended budget:

```
Used context budget = n_ctx × 0.75

Example: n_ctx = 2048 → ContextManager budget = 1536 tokens
(Remaining 512 reserved for model output + safety margin)
```

When the agent conversation accumulates more tokens than this budget, the `ContextManager` compresses by summarizing older turns. The KV cache is not re-used across agent turns in V1 — each LLM call processes the full assembled prompt from scratch (stateless inference). This is less efficient than stateful KV cache reuse but is simpler to implement reliably.

**KV cache reuse (stateful inference) is a post-V1 performance optimization.** When implemented, it will significantly reduce first-token latency for long conversations by avoiding redundant prefix reprocessing.

---

## 13. Model Lifecycle

### 13.1 States

```
NOT_LOADED
    ↓ (user activates model or agent request)
LOADING
    ↓ (llama_init completes)
LOADED_IDLE
    ↓ (inference request received)
GENERATING
    ↓ (generation complete or cancelled)
LOADED_IDLE
    ↓ (unload trigger: user request, low memory, timeout)
UNLOADING
    ↓
NOT_LOADED
```

Error states:
- `LOAD_FAILED` — file not found, corrupt, insufficient RAM, incompatible format
- `GENERATION_FAILED` — inference error mid-generation

### 13.2 Load Triggers

The model is loaded when:
1. The user explicitly activates a model in the Model Manager screen
2. The user opens the AI chat panel and no model is loaded
3. The agent starts a session and no model is loaded

### 13.3 Unload Triggers

The model is unloaded when:
1. The user explicitly unloads it via the Model Manager
2. The application receives `onTrimMemory(TRIM_MEMORY_RUNNING_CRITICAL)` from Android
3. The model has been idle for a configurable timeout (default: 10 minutes)
4. The user switches to a different model
5. A runtime execution requires more RAM than available with the model loaded (user is prompted)

### 13.4 Load/Unload Implementation

Loading and unloading are blocking operations from llama.cpp's perspective. They must run on a background thread, not the main thread or any Dart isolate that drives the UI.

The Dart FFI binding exposes these as `Future` operations backed by a Dart isolate calling into native code asynchronously.

```
// Conceptual Dart FFI binding
Future<void> loadModel(String modelPath, ModelConfig config) async {
    // Runs in native thread pool; does not block Dart event loop
    await _ffi.llamaLoad(modelPath, config.toNative());
}

Future<void> unloadModel() async {
    await _ffi.llamaFree();
}
```

---

## 14. Model Manager

The `ModelManager` is the application-layer component that manages the lifecycle, metadata, and storage of AI models.

### 14.1 Responsibilities

- Maintain a registry of installed models (from `models/` in app storage)
- Track model metadata: name, parameter count, quantization, estimated RAM, context length, source
- Expose model list to UI (Model Manager screen)
- Handle model download, import, and deletion
- Check device compatibility before loading a model
- Communicate with `LocalAIProvider` for load/unload operations
- Emit low-storage warnings before download

### 14.2 Model Registry

Each installed model has a metadata file alongside the `.gguf` file:

```
models/
    llama-3-3b-q4_k_m/
        model.gguf               ← model weights
        metadata.json            ← IDE metadata record
```

`metadata.json`:
```json
{
  "id": "llama-3-3b-q4_k_m",
  "displayName": "Llama 3.2 3B (Q4_K_M)",
  "family": "llama",
  "parameterCount": 3000000000,
  "quantization": "Q4_K_M",
  "contextLength": 8192,
  "estimatedRamBytes": 2200000000,
  "fileSizeBytes": 1900000000,
  "architecture": "llama",
  "chatTemplate": "llama-3",
  "capabilities": ["code", "instruction"],
  "source": "huggingface",
  "sourceUrl": "https://huggingface.co/...",
  "downloadedAt": "2026-08-30T10:00:00Z",
  "checksum": "sha256:abc123...",
  "checksumVerified": true,
  "profile": "balanced"
}
```

Metadata is partially populated at download time (from the source) and partially auto-extracted from the GGUF file header (context length, architecture, chat template).

### 14.3 Model Download Flow

```
User selects model from catalog or enters URL
    ↓
ModelManager.checkStorageAvailability(model.fileSizeBytes)
    ├── if insufficient: show storage warning; stop
    └── if sufficient: proceed
    ↓
ModelManager.checkRamCompatibility(model.estimatedRamBytes)
    ├── if likely insufficient: show warning (user can proceed anyway)
    └── show estimated RAM usage
    ↓
Download to models/<model-id>/model.gguf.partial
    ↓ (progress streamed to UI)
Download complete → verify checksum
    ├── fail: delete partial; show error
    └── pass: rename .gguf.partial → .gguf
    ↓
Extract metadata from GGUF header
    ↓
Write metadata.json
    ↓
Notify registry: model available
```

### 14.4 Model Import from Local Storage

The user can import a model file from device storage via the SAF file picker. The file is copied to `models/<model-id>/model.gguf`. Metadata is auto-extracted from the GGUF header. The `source` field is set to `"local_import"`.

### 14.5 Model Deletion

```
User taps Delete Model
    ↓
If model is currently loaded:
    unload model first (waits for any active generation to complete or cancel)
    ↓
Delete models/<model-id>/ directory
    ↓
Update registry
    ↓
If deleted model was the active model:
    active model = none; user must select a new model
```

---

## 15. Streaming Generation

Streaming is essential for usability. The user must see tokens appearing in real time rather than waiting for the full generation to complete.

### 15.1 Architecture

llama.cpp generates tokens one at a time in a loop. The Dart FFI binding exposes this as a `Stream<String>`:

```
// Conceptual binding
Stream<String> generate(String prompt, GenerationParams params) {
    // Native code runs inference in a native thread
    // Each generated token is pushed to the Dart stream via a callback
    return _ffi.llamaGenerate(prompt, params.toNative());
}
```

On the native side:
```c
// C callback invoked for each token
typedef void (*token_callback)(const char* token, void* user_data);

void llama_generate_with_callback(
    llama_context* ctx,
    const char* prompt,
    GenerationParams params,
    token_callback callback,
    void* user_data
);
```

The token callback posts each token to a Dart `SendPort`, which routes it to the Dart `Stream`. This is the standard pattern for Dart FFI + native callbacks.

### 15.2 UI Token Delivery

The `AgentScreen` subscribes to the generation stream and appends tokens to the displayed message as they arrive. This provides a typewriter-like experience.

For tool calls, streaming continues until the model emits the closing `</tool_call>` tag. The `OutputParser` processes the complete tool call block after the stream ends or after a `</tool_call>` is detected mid-stream.

---

## 16. Cancellation

### 16.1 Mechanism

llama.cpp supports generation cancellation via an abort callback. The C API accepts a callback:

```c
typedef bool (*abort_callback)(void* data);
```

If the callback returns `true`, generation stops at the next token boundary. The Dart FFI binding exposes cancellation as:

```dart
void cancelGeneration() {
    _cancellationFlag.value = true; // atomic flag checked by abort callback
}
```

### 16.2 Cancellation Latency

Cancellation is not instantaneous. The native code checks the abort flag at token boundaries. For a 3B model generating at 5 tok/s, worst-case cancellation latency is approximately 200ms. This is acceptable.

If the model is in the prefill phase (processing a long prompt), the abort check frequency is lower. For long prompts (>500 tokens), cancellation may take up to 2 seconds. This is a known limitation and must be communicated to the user with a "Stopping..." indicator.

---

## 17. Performance Benchmarks and Targets

These targets are based on publicly reported llama.cpp benchmarks for ARM64 Android devices, adjusted for the specific model sizes and quantization levels used in this application. They must be validated by profiling on real devices during Phase 9.

### 17.1 Token Generation Throughput (tok/s)

Measured as autoregressive token generation speed (post-prefill).

| Model | Quantization | Tier A (est.) | Tier B (est.) | Tier C (est.) |
|---|---|---|---|---|
| 1B | Q4_K_M | 15–25 tok/s | 20–35 tok/s | 35–60 tok/s |
| 3B | Q4_K_M | Not recommended | 4–10 tok/s | 10–20 tok/s |
| 7B | Q4_K_M | Not feasible | Not recommended | 3–8 tok/s |

> These are estimates based on comparable hardware benchmarks. Actual performance will vary by SoC, memory bandwidth, and thermal state. These numbers should be measured and updated during Phase 9 with real device data.

### 17.2 First Token Latency (Prefill Time)

Prefill processes the entire prompt in one forward pass. A shorter prompt = shorter prefill.

| Model | Prompt Length | Tier B (est.) | Tier C (est.) |
|---|---|---|---|
| 1B Q4_K_M | 256 tokens | ~1–2 s | ~0.5–1 s |
| 1B Q4_K_M | 1024 tokens | ~3–5 s | ~1.5–3 s |
| 3B Q4_K_M | 256 tokens | ~2–4 s | ~1–2 s |
| 3B Q4_K_M | 1024 tokens | ~8–15 s | ~4–8 s |

This reinforces the importance of keeping prompts short (see ContextManager in `03-AI-AGENT.md`).

### 17.3 Model Load Time

| Model | Tier B (est.) | Tier C (est.) |
|---|---|---|
| 1B Q4_K_M | 3–8 s | 2–4 s |
| 3B Q4_K_M | 8–15 s | 4–8 s |
| 7B Q4_K_M | 20–35 s | 10–18 s |

Load time is dominated by file I/O — reading the model file from storage into RAM. Modern Android devices with UFS 3.1+ storage are significantly faster than older eMMC storage.

---

## 18. Battery and Thermal Impact

### 18.1 Power Consumption

LLM inference is CPU-intensive. Estimated power draw during inference on a Snapdragon 7-series:
- CPU power: ~2–4 W during heavy inference
- Total system: ~4–6 W during active inference
- Battery impact: approximately 8–15% per hour of continuous inference

This is within acceptable bounds for an active development session.

### 18.2 Thermal Management

The application integrates with Android's thermal API (API 29+):

```
PowerManager.ThermalStatus
    NONE (0)     → Normal; full inference speed
    LIGHT (1)    → Minor thermal stress; no change
    MODERATE (2) → Noticeable throttling; reduce threads by 1
    SEVERE (3)   → Heavy throttling; reduce threads to 2; show warning
    CRITICAL (4) → Critical; reduce threads to 1; show strong warning
    EMERGENCY (5)→ Emergency; pause inference; notify user
    SHUTDOWN (6) → Device shutting down; stop all inference immediately
```

For devices on Android < 29 (which don't have `PowerManager.ThermalStatus`), the application cannot directly monitor thermal state. A fallback strategy is to monitor inference speed (tokens/second) — a sudden drop of >30% suggests thermal throttling — and reduce thread count reactively.

### 18.3 Battery Saver Mode

When `PowerManager.isPowerSaveMode()` returns true:
- Reduce inference threads to minimum (2)
- Show a notification: "Battery Saver is active. AI performance may be reduced."
- Do not automatically disable AI — the user decides.

---

## 19. Device Tier Compatibility

### 19.1 Compatibility Matrix

| Feature | Tier A (3–4 GB RAM) | Tier B (6–8 GB RAM) | Tier C (10–16 GB RAM) |
|---|---|---|---|
| AI assistant (chat) | Tiny model only | Balanced model | Balanced or Power |
| AI agent (automated) | Limited (Tiny model) | Full (Balanced) | Full (Balanced or Power) |
| Concurrent: run code + AI | Risky; manual management | Feasible with Balanced | Comfortable |
| Max context length | 1K–2K tokens | 2K–4K tokens | 4K–8K tokens |
| Streaming fluency | Usable (>5 tok/s) | Good (>8 tok/s) | Excellent |

### 19.2 Compatibility Check at Load Time

Before loading a model, the application:
1. Reads `model.estimatedRamBytes` from model metadata
2. Queries `ActivityManager.MemoryInfo.availMem`
3. Computes whether loading is safe with the current `contextLength` setting
4. If unsafe: warns the user with specific numbers ("This model needs ~2.2 GB. ~1.8 GB is available. Close other apps or select a smaller model.")

### 19.3 Model Recommendation

When the user has no model installed and opens the AI panel, the application recommends a model based on device tier:
- Tier A: "Your device has limited RAM. We recommend the Tiny model profile (~700 MB)."
- Tier B: "Your device supports the Balanced model profile (~2 GB)."
- Tier C: "Your device can run the Power model profile (~4 GB)."

The actual model names within each profile are not hard-coded — they come from a remotely-updated catalog or user browsing.

---

## 20. Model Profiles: Tiny, Balanced, Power

These profiles are metadata classifications, not separate systems. A model is assigned a profile in its `metadata.json` based on its parameter count:

| Profile | Parameter Count | Primary Use Case |
|---|---|---|
| `tiny` | < 2B | Tier A; fast responses; simple coding tasks |
| `balanced` | 2B – 5B | Tier B primary; good quality for most development tasks |
| `power` | > 5B | Tier C only; complex reasoning and multi-step plans |

The application's settings allow the user to set their preferred profile. When selecting a model to download, models matching the preferred profile are highlighted.

The `ContextManager` uses the active model's profile to adjust its default context budget:
- Tiny: 1K token budget
- Balanced: 2K–3K token budget
- Power: 4K–6K token budget

---

## 21. Model Selection and Compatibility Check

### 21.1 At Model Download

Before downloading, the application displays:
- Model name and description
- File size
- Estimated RAM requirement
- Estimated generation speed (from profile category)
- Whether the current device is compatible (green/yellow/red indicator)

### 21.2 At Model Activation

When the user activates a model (sets it as active for AI interactions):
```
ModelManager.activateModel(modelId):
    metadata = loadMetadata(modelId)
    ram = checkAvailableRAM()
    
    if metadata.estimatedRamBytes > ram - 500MB:
        → show warning: insufficient RAM
        → user may proceed anyway (advanced mode)
    
    if metadata.architecture not in supported_architectures:
        → show error: incompatible model architecture
        → do not proceed
    
    if metadata.chatTemplate not in known_templates:
        → show warning: unknown chat template; may produce poor results
        → user may proceed
    
    → set as active model; load on next AI request
```

### 21.3 Dynamic Compatibility

Available RAM changes as the user opens and closes apps. The compatibility check is performed at activation time, not at load time. At load time, a fresh check is performed. If conditions have changed (less RAM now available), the user is warned again.

---

## 22. Dart FFI Binding Design

### 22.1 Binding Strategy

The `LocalAIProvider` in Flutter/Dart communicates with llama.cpp via Dart FFI. The binding is a thin wrapper — it does not add business logic.

### 22.2 Native Library

The llama.cpp codebase is compiled to a shared library `libllama.so` targeting `arm64-v8a`. It is included in the APK's `jniLibs/arm64-v8a/` directory (or as a native library asset). Android installs it to `nativeLibraryDir` at install time.

### 22.3 Exposed Functions (Simplified)

```c
// llama.cpp C API surface used by the application
// (subset of full llama.h, version-pinned)

// Initialization
llama_model* llama_load_model_from_file(const char* path, llama_model_params params);
llama_context* llama_new_context_with_model(llama_model* model, llama_context_params params);

// Tokenization
int32_t llama_tokenize(const llama_model* model, const char* text, int32_t* tokens, int32_t max_tokens, bool add_bos);

// Inference
int llama_decode(llama_context* ctx, llama_batch batch);
llama_token llama_sampler_sample(llama_sampler* sampler, llama_context* ctx, int32_t idx);

// Sampling
llama_sampler* llama_sampler_chain_init(llama_sampler_chain_params params);
// (add top-k, top-p, temperature samplers to chain)

// Cleanup
void llama_free(llama_context* ctx);
void llama_free_model(llama_model* model);
```

### 22.4 Thread Safety

llama.cpp contexts are not thread-safe. The application must ensure that only one inference call is active at a time on a given context. The `LocalAIProvider` uses a Dart mutex (via `synchronized` or equivalent) to enforce this.

### 22.5 Version Pinning

The llama.cpp version is pinned in the project's build system (specific git commit SHA or release tag). Updates are applied deliberately with testing, not automatically. Breaking changes in llama.cpp's C API require updating the FFI bindings.

---

## 23. Model Storage and Management

### 23.1 Storage Location

```
app-internal storage:
    models/
        <model-id>/
            model.gguf
            metadata.json
```

Model files are stored in app-internal storage by default. This ensures:
- Android scoped storage compliance
- No permission required to access the files
- Files are deleted when the app is uninstalled

For devices with limited internal storage, a future option is to support model storage on external storage (if available and user grants access). This requires SAF integration and the external storage must not be `noexec` (models are read-only data files, so `noexec` does not apply to them directly).

### 23.2 Storage Space Management

The application should:
- Show total storage used by models in the Model Manager screen
- Warn when storage is below 20% before a download
- Provide a "free up space" option that lists installed models and their sizes

---

## 24. Architectural Decision Records

### ADR-006: Stateless Inference (No KV Cache Reuse) for V1

**Decision:** Each LLM call reprocesses the full assembled prompt from scratch (stateless). KV cache is not reused across turns.

**Context:** llama.cpp supports stateful inference where the KV cache is preserved between calls, allowing subsequent calls with shared prefix to skip redundant computation. This significantly reduces first-token latency for long conversations.

**Why deferred:** Stateful inference requires the application to track exactly which tokens are already in the context and to manage cache invalidation carefully. This adds significant complexity to the `ContextManager` and `LocalAIProvider` binding. For V1, the correctness benefit of stateless inference outweighs the performance cost.

**Consequences:** Longer first-token latency, especially for later turns in a conversation with many tool results in context. Acceptable for V1 given typical agent turn length. Stateful inference is a high-priority Phase 9+ optimization.

---

### ADR-007: No Fine-Tuned Coding Model Required

**Decision:** The application does not require a specifically fine-tuned coding model. Any instruction-following GGUF model may be loaded.

**Context:** Fine-tuned coding models (e.g., Qwen2.5-Coder, DeepSeek-Coder) perform better at code generation than general-purpose models of the same size. However, requiring a specific model would restrict user choice and the model ecosystem evolves rapidly.

**Decision:** The agent system is designed to work with any instruction-following model. The system prompt and tool format are tuned to work with general instruction-following models. A coding-specific model is recommended but not required.

**Consequences:** Quality varies by model. Users are advised to select coding-optimised models for best results. The application does not enforce this.

---

## 25. Open Questions

| # | Question | Impact | Phase |
|---|---|---|---|
| AI-OQ-001 | What is the actual inference throughput (tok/s) of Qwen2.5-Coder-3B Q4_K_M on a Snapdragon 778G? | High — affects UX expectations | Phase 9 |
| AI-OQ-002 | Does llama.cpp Vulkan backend provide measurable benefit on Adreno 650-class GPUs? | Medium — affects GPU toggle decision | Phase 9 |
| AI-OQ-003 | Does NNAPI provide any benefit for any part of the inference pipeline on modern Snapdragon? | Low for V1 — experimental | Post-V1 |
| AI-OQ-004 | What is the practical minimum model that produces acceptable agent behavior (correct tool call JSON)? | High — affects Tier A viability | Phase 9 |
| AI-OQ-005 | Can llama.cpp KV cache be preserved and reused reliably across Dart FFI calls? | High for performance — post-V1 | Phase 9+ |
| AI-OQ-006 | What is the model load time for 3B Q4_K_M on UFS 3.1 vs eMMC 5.1 storage? | Medium — affects UX | Phase 9 |
| AI-OQ-007 | How should the chat template be detected for user-imported models without metadata? | Medium — affects import flow | Phase 9 |
| AI-OQ-008 | Which specific 1B–3B models produce the most reliable tool call JSON with a simple system prompt? | High — affects MVP success | Phase 9 (prototype) |

---

*Next: `06-SECURITY.md` — Threat model, workspace sandbox, AI permissions, prompt injection defence, secrets management, and audit logging.*
