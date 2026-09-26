# Gemma 4 Integration Guide - GGUF Model Setup

## Overview

This guide explains how to integrate Gemma 4 (or Gemma 2) locally in Mylonite IDE using llama.cpp and GGUF format models.

---

## 1. Understanding the Model Architecture

### Model Options

| Model | Size | Quantization | File Size | RAM Required | Recommended |
|---|---|---|---|---|---|
| **Gemma 2 2B** | 2 billion params | Q4_K_M | ~1.5GB | 2-3GB | ✅ **Best for phone** |
| **Gemma 2 2B** | 2 billion params | Q8_0 | ~2.5GB | 3-4GB | ⚠️ High quality, more RAM |
| Gemma 2 9B | 9 billion params | Q4_K_M | ~5.5GB | 6-8GB | ❌ Too large for most phones |
| Gemma 2 27B | 27 billion params | Q4_K_M | ~15GB | 16GB+ | ❌ Not suitable for mobile |

**Recommendation:** Use **Gemma 2 2B Q4_K_M** for the hackathon.

### Why GGUF Format?

- ✅ Optimized for llama.cpp inference
- ✅ Quantized for smaller size
- ✅ Fast loading on mobile
- ✅ CPU-friendly (ARM NEON optimizations)
- ✅ No GPU required

---

## 2. Where to Get the GGUF Model

### Option 1: Download from Hugging Face (Recommended)

**Model:** `google/gemma-2-2b-it` (Instruction-tuned version)

**Quantized GGUF versions available at:**
- https://huggingface.co/bartowski/gemma-2-2b-it-GGUF

**Direct download link for Q4_K_M:**
```
https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
```

**Size:** ~1.5GB

### Option 2: Convert from Original Model

If you want to convert yourself:

1. Download original Gemma 2 2B from Google:
   ```bash
   git lfs install
   git clone https://huggingface.co/google/gemma-2-2b-it
   ```

2. Convert to GGUF using llama.cpp:
   ```bash
   git clone https://github.com/ggerganov/llama.cpp
   cd llama.cpp
   python convert.py ../gemma-2-2b-it --outtype q4_k_m
   ```

But **downloading pre-quantized is much faster**.

---

## 3. Where to Place the GGUF File

### For Development (PC Testing)

Place the `.gguf` file in the project:

```
AIOIDE/
├── assets/
│   └── models/
│       └── gemma-2-2b-it-Q4_K_M.gguf  ← Put it here
```

Then update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/gemma-2-2b-it-Q4_K_M.gguf
```

⚠️ **Problem:** This makes the APK ~1.5GB larger!

### For Production (Recommended Approach)

**Don't bundle the model in the APK.** Instead:

1. **Download on first launch:**
   - App detects no model on first run
   - Shows download dialog with progress
   - Downloads from Hugging Face
   - Saves to app's private storage

2. **Storage location on device:**
   ```
   /data/data/com.offlinemobileide.aioide/files/models/gemma-2-2b-it-Q4_K_M.gguf
   ```

3. **Benefits:**
   - ✅ Small APK (~50MB vs ~1.6GB)
   - ✅ User can choose not to download
   - ✅ Can update model without app update
   - ✅ Can offer multiple model options

### For Hackathon (Quick Demo)

**Two approaches:**

**A. Side-load the model manually:**

1. Copy GGUF file to device:
   ```bash
   adb push gemma-2-2b-it-Q4_K_M.gguf /sdcard/Download/
   ```

2. In the app, implement "Import Model" button:
   - User selects file from Downloads
   - App copies to private storage
   - Model becomes available

**B. Download via app:**

1. Implement download UI in Model Manager screen
2. Download from Hugging Face on demand
3. Show progress bar
4. Cache for future use

I'll implement **Option B** as it's more professional.

---

## 4. Technical Architecture

### How llama.cpp Works on Android

```
┌─────────────────────────────────────────────┐
│ Dart (InferenceService)                     │
│  - Prompt construction                      │
│  - Response streaming                       │
│  - Context management                       │
├─────────────────────────────────────────────┤
│ Dart FFI Bindings                           │
│  - Native function calls                    │
│  - Pointer management                       │
│  - Memory safety                            │
├─────────────────────────────────────────────┤
│ libllama.so (C++ native library)            │
│  - Model loading (mmap)                     │
│  - Token generation                         │
│  - KV cache management                      │
│  - ARM NEON optimizations                   │
├─────────────────────────────────────────────┤
│ GGUF Model File                             │
│  - Weights + architecture                   │
│  - Quantized tensors                        │
│  - Metadata                                 │
└─────────────────────────────────────────────┘
```

### Files to Create

```
lib/core/services/ai/
  ├── inference_service.dart       # Main inference API
  ├── llama_cpp_bindings.dart      # FFI bindings
  ├── model_manager.dart            # Model download/management
  └── prompt_templates.dart         # Agent prompts

android/app/src/main/jniLibs/
  └── arm64-v8a/
      └── libllama.so               # llama.cpp compiled for Android ARM64
```

---

## 5. Integration Steps

### Step 1: Get llama.cpp Prebuilt Binary

**Option A: Download prebuilt (fastest):**

1. Go to: https://github.com/ggerganov/llama.cpp/releases
2. Download: `llama-*-android.zip`
3. Extract `libllama.so` for arm64-v8a
4. Place in: `android/app/src/main/jniLibs/arm64-v8a/libllama.so`

**Option B: Build from source (if needed):**

```bash
# On Linux/Mac with Android NDK
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build-android && cd build-android

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DLLAMA_BUILD_SERVER=OFF

make -j4
cp libllama.so ../../AIOIDE/android/app/src/main/jniLibs/arm64-v8a/
```

### Step 2: Create Dart FFI Bindings

I'll create this in the next steps.

### Step 3: Implement Model Download

Will use `http` package to download from Hugging Face with progress tracking.

### Step 4: Create Inference Service

High-level API for:
- Loading model
- Generating responses
- Streaming tokens
- Managing context

### Step 5: Wire to Agent Screen

Connect the inference service to the Agent UI.

---

## 6. Expected Performance

### Gemma 2 2B Q4_K_M on Android (ARM Cortex-A76 @ 2.0GHz)

| Metric | Expected Value |
|---|---|
| **Model load time** | 3-8 seconds |
| **First token** | 1-2 seconds |
| **Tokens per second** | 3-8 tokens/sec |
| **Memory usage** | 2-3GB RAM |
| **Context length** | 8192 tokens (full) |

### Real-World Example

**Prompt:** "Write a Python function to calculate Fibonacci"

**Timeline:**
- 0s: User sends prompt
- 0-2s: Model processes prompt (128 tokens)
- 2-10s: Generates response (50 tokens @ 6 tok/s)
- 10s: Complete response displayed

**Total:** ~10 seconds for a complete code generation

This is **acceptable for a hackathon demo**.

---

## 7. Memory Management

### RAM Requirements

| Component | Memory |
|---|---|
| Flutter app | ~100MB |
| Python runtime | ~40MB |
| Gemma 2 2B model | ~1.5GB |
| Inference context | ~500MB |
| **Total** | **~2.1GB** |

**Minimum device requirement:** 4GB RAM (2GB free)

### Optimization Tips

1. **Unload model when not in use:**
   ```dart
   await inferenceService.unloadModel();
   ```

2. **Reduce context length:**
   ```dart
   contextLength: 2048, // Instead of 8192
   ```

3. **Use smaller quantization:**
   - Q4_K_M: 1.5GB (recommended)
   - Q3_K_M: 1.1GB (lower quality)
   - Q2_K: 900MB (much lower quality)

---

## 8. Testing Strategy

### Without Model (UI Testing)

Test the UI without downloading the full model:

```dart
// In inference_service.dart
Future<String> generate(String prompt) async {
  // Simulate inference
  await Future.delayed(Duration(seconds: 2));
  return "def fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)";
}
```

### With Model (Real Testing)

1. Download Gemma 2 2B Q4_K_M (~1.5GB)
2. Place in device storage
3. Load model (wait 3-8 seconds)
4. Send test prompt
5. Verify response quality

---

## 9. Troubleshooting

### "Model not found"

**Cause:** GGUF file not in expected location  
**Fix:** Check path is correct: `/data/data/com.offlinemobileide.aioide/files/models/`

### "Out of memory" error

**Cause:** Device has <2GB free RAM  
**Fix:** Use smaller quantization (Q3_K_M or Q2_K)

### Inference is very slow (<1 tok/s)

**Cause:** CPU throttling or low-end device  
**Fix:** 
- Reduce context length
- Use Q2_K quantization
- Disable background apps

### Model won't load

**Cause:** Corrupted GGUF file  
**Fix:** Re-download model, verify checksum

### Crash on model load

**Cause:** Incompatible GGUF version  
**Fix:** Use latest llama.cpp build + latest GGUF format

---

## 10. Quick Start (For Hackathon)

### Fastest Path to Working Demo

1. **Download model:**
   ```bash
   # Download Q4_K_M from Hugging Face
   wget https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
   ```

2. **Push to device:**
   ```bash
   adb push gemma-2-2b-it-Q4_K_M.gguf /sdcard/Download/
   ```

3. **In app:**
   - Open Model Manager
   - Click "Import Model"
   - Select downloaded file
   - Wait for copy to complete

4. **Test inference:**
   - Open Agent screen
   - Type: "Write hello world in Python"
   - Wait 10-15 seconds
   - See generated code!

### Implementation Time Estimate

| Task | Time |
|---|---|
| FFI bindings | 2-3 hours |
| Inference service | 2-3 hours |
| Model download UI | 1-2 hours |
| Agent integration | 2-3 hours |
| Testing + fixes | 2-3 hours |
| **Total** | **9-14 hours** |

---

## 11. Alternative: Use Gemini API (Not Recommended)

If local inference is too complex for the hackathon:

**Pros:**
- ✅ No model download
- ✅ Fast inference
- ✅ High quality responses

**Cons:**
- ❌ **Requires internet** (violates "local-first" requirement)
- ❌ API costs money
- ❌ Not truly autonomous
- ❌ **Won't win hackathon** (doesn't meet challenge requirements)

**Verdict:** Don't use cloud APIs. The hackathon explicitly requires local Gemma 4.

---

## 12. Summary

### What You'll Implement

✅ **Model Management:**
- Download GGUF from Hugging Face
- Store in app private storage
- Model selection UI

✅ **Inference Service:**
- Load GGUF model via llama.cpp
- Generate responses (streaming)
- Context management

✅ **Agent Integration:**
- Wire inference to Agent screen
- Prompt templates for code generation
- Response parsing

### What Users Will Experience

1. **First launch:**
   - "Download Gemma 2 2B model? (1.5GB)"
   - Progress bar shows download
   - Model loads automatically

2. **Using the agent:**
   - Type: "Create a Python calculator"
   - Wait 10-15 seconds
   - See generated code
   - Code executes automatically
   - Agent checks result

3. **Autonomous loop:**
   - Agent detects error
   - Modifies code
   - Re-runs
   - Repeats until success

**This is the vision for the Gemma 4 Local-First Agents hackathon!**

---

## Next Steps

I'll now implement:

1. ✅ Create FFI bindings for llama.cpp
2. ✅ Build inference service
3. ✅ Create model manager UI
4. ✅ Wire to Agent screen
5. ✅ Test with real model

**Ready to proceed with implementation!** 🚀

---

**Created:** 2026-08-30  
**Phase:** 9 - Gemma 4 AI Integration  
**Status:** Implementation in progress
