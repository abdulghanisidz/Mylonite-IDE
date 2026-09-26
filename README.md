# ⬡ Mylonite IDE

> **An offline-first mobile development environment for Android.**  
> Write code, run it locally, and get help from an on-device AI agent — no internet required.

[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.1-blue?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2026%2B-green?logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Phase](https://img.shields.io/badge/Phase-5%20%E2%80%94%20Python%20Runtime-purple)]()

---

## What is Mylonite IDE?

Mylonite IDE turns your Android smartphone into a self-contained development machine. It provides a full code editor, local project management, Python runtime execution, and an AI coding agent framework — all running completely offline on your device.

**Key Achievements (Phase 5):**
- ✅ Full-featured code editor with 100+ language syntax highlighting
- ✅ Native process execution with real-time stdout/stderr streaming
- ✅ Python runtime integration with auto-detection and installation
- ✅ Foreground services for long-running processes
- ✅ Secure platform channel architecture (Dart ↔ Kotlin)
- ✅ Complete project workspace management with SAF integration

```
Open IDE → Create Project → Write Code → Execute Python → Stream Output → 
All offline, on your phone.
```

---

## ✨ Features (Phases 0–5)

| Feature | Status |
|---|---|
| **Phase 0–1: Foundation** | |
| 9-document architecture blueprint | ✅ Complete |
| Flutter app shell + dark/light theme | ✅ Complete |
| **Phase 2: Project & Workspace Management** | |
| Project creation, management, persistence | ✅ Complete |
| WorkspaceManager with path confinement + symlink protection | ✅ Complete |
| File explorer — create, rename, delete, expand/collapse | ✅ Complete |
| ZIP import/export with zip-slip protection | ✅ Complete |
| File watcher (polling-based auto-refresh) | ✅ Complete |
| SAF (Storage Access Framework) integration | ✅ Complete |
| **Phase 3: Code Editor** | |
| Code editor — syntax highlighting (100+ languages) | ✅ Complete |
| Multi-tab editor with dirty indicators | ✅ Complete |
| Undo/Redo (200-step history) | ✅ Complete |
| In-file search — text + regex + case toggle | ✅ Complete |
| AI diff preview — Accept / Reject | ✅ Complete |
| Diagnostic status bar (error/warning count) | ✅ Complete |
| **Phase 4: Execution Engine** | |
| ProcessService — process spawning, streaming, lifecycle | ✅ Complete |
| ProcessChannel — Dart ↔ Kotlin bridge with EventChannel | ✅ Complete |
| ProcessForegroundService for long-running processes | ✅ Complete |
| InferenceForegroundService for AI model inference | ✅ Complete |
| Process timeout, OOM detection, SIGTERM/SIGKILL | ✅ Complete |
| SystemChannel — system info, permissions, device details | ✅ Complete |
| StorageChannel — SAF integration for file operations | ✅ Complete |
| SecretsChannel — Android Keystore encrypted API keys | ✅ Complete |
| **Phase 5: Python Runtime** | |
| PythonRuntime service with environment configuration | ✅ Complete |
| PythonInstaller — auto-detection and installation | ✅ Complete |
| Python diagnostics parser (traceback, syntax errors) | ✅ Complete |
| Python execution with stdout/stderr streaming | ✅ Complete |
| Runtime Manager screen | ✅ Complete |
| Process Test screen for debugging | ✅ Complete |

---

## 🏗️ Architecture

5 clean layers, each independently replaceable:

```
┌─────────────────────────────────────────┐
│   UI Layer      Flutter / Dart          │
├─────────────────────────────────────────┤
│   App Core      Dart — Managers,        │
│                 Controllers, Providers  │
├─────────────────────────────────────────┤
│   Platform      Flutter Platform        │
│   Bridge        Channels + Dart FFI     │
├─────────────────────────────────────────┤
│   Native        Kotlin / Android SDK    │
│   Services      (Process, SAF, Keystore)│
├─────────────────────────────────────────┤
│   Engines       C/C++ — llama.cpp,      │
│                 CPython, QuickJS        │
└─────────────────────────────────────────┘
```

Full architecture documentation is in [`docs/`](docs/).

---

## 📁 Project Structure

```
Mylonite-IDE/
├── docs/                          # Architecture documentation (Phase 0)
│   ├── 00-PROJECT-VISION.md
│   ├── 01-REQUIREMENTS.md
│   ├── 02-ARCHITECTURE.md
│   ├── 03-AI-AGENT.md
│   ├── 04-RUNTIME-SYSTEM.md
│   ├── 05-OFFLINE-AI.md
│   ├── 06-SECURITY.md
│   ├── 07-DATA-MODELS.md
│   ├── 08-ROADMAP.md
│   ├── mylonite-ui.html           # Interactive UI demo
│   └── mylonite-hackathon.html    # Hackathon submission page
├── lib/
│   ├── core/
│   │   ├── constants/             # App-wide constants and route names
│   │   ├── models/                # ProjectModel, Settings, Enums, AppError
│   │   ├── providers/             # Riverpod providers
│   │   └── services/              # Business logic layer
│   │       ├── app_router.dart    # GoRouter configuration
│   │       ├── project_manager.dart
│   │       ├── workspace_manager.dart
│   │       ├── settings_service.dart
│   │       ├── logging_service.dart
│   │       ├── zip_service.dart
│   │       ├── editor/            # EditorController, EditorTab
│   │       └── runtime/           # Runtime execution services
│   │           ├── python_runtime.dart
│   │           ├── python_installer.dart
│   │           └── python_diagnostics_parser.dart
│   ├── features/
│   │   ├── home/                  # Home screen
│   │   ├── projects/              # Projects screen (create/import/export)
│   │   ├── editor/                # Code editor screen
│   │   ├── explorer/              # File explorer screen
│   │   ├── terminal/              # Terminal screen
│   │   ├── agent/                 # AI Agent screen
│   │   ├── settings/              # Settings screen
│   │   ├── runtime_manager/       # Runtime Manager screen
│   │   ├── model_manager/         # Model Manager screen
│   │   └── process_test/          # Process Test screen (debug)
│   ├── platform/
│   │   └── channels/              # Dart-side Platform Channel interfaces
│   │       ├── process_channel.dart
│   │       ├── storage_channel.dart
│   │       ├── system_channel.dart
│   │       └── secrets_channel.dart
│   └── ui/
│       └── theme/                 # AppTheme, AppColors
├── android/
│   └── app/src/main/kotlin/com/offlinemobileide/aioide/
│       ├── MainActivity.kt
│       ├── channels/              # Platform Channels (Kotlin ↔ Dart)
│       │   ├── ProcessChannel.kt
│       │   ├── StorageChannel.kt
│       │   ├── SystemChannel.kt
│       │   └── SecretsChannel.kt
│       └── services/              # Native Android services
│           ├── ProcessService.kt
│           ├── ProcessForegroundService.kt
│           └── InferenceForegroundService.kt
├── pubspec.yaml
└── PROJECT-SUMMARY.txt            # Complete project summary
```

---

## 🗺️ Roadmap

| Phase | Description | Status |
|---|---|---|
| 0 | Architecture & Documentation | ✅ Done |
| 1 | Flutter App Shell | ✅ Done |
| 2A | Project & Workspace Management | ✅ Done |
| 2B | File Ops, SAF, ZIP Import/Export | ✅ Done |
| 3 | Code Editor | ✅ Done |
| 4 | Execution Engine (Android process management) | ✅ Done |
| 5 | Python Runtime (CPython ARM64) | ✅ Done |
| 6 | JavaScript Runtime (QuickJS ARM64) | 🔜 Next |
| 7 | Terminal & Process Manager | 🔜 |
| 8 | AI Provider Abstraction | 🔜 |
| 9 | Local AI Inference (llama.cpp + Dart FFI) | 🔜 |
| 10 | AI Tool System (13 tools) | 🔜 |
| 11 | Agent Loop (autonomous multi-step) | 🔜 |
| 12 | AI Debugging | 🔜 |
| 13 | Security Hardening | 🔜 |
| 14 | Performance Optimization | 🔜 |
| 15 | Beta Testing | 🔜 |

---

## � Platform Channels

Mylonite IDE uses Flutter Platform Channels to bridge Dart and native Android functionality:

| Channel | Purpose | Implementation |
|---|---|---|
| **ProcessChannel** | Execute native processes, stream output, manage lifecycle | ProcessService.kt + EventChannel |
| **StorageChannel** | SAF integration for file/folder access | ActivityResultLauncher |
| **SystemChannel** | Device info, permissions, system diagnostics | Android SDK APIs |
| **SecretsChannel** | Encrypted key storage using Android Keystore | EncryptedSharedPreferences |

All channels follow a consistent pattern:
- **Dart side**: Type-safe API with async/await (in `lib/platform/channels/`)
- **Kotlin side**: MethodChannel handlers + EventChannel streams (in `android/.../channels/`)
- **Error handling**: Structured error codes with PlatformException

---

## �🔒 Security Highlights

- **Workspace sandboxing** — AI agent cannot access files outside the active project
- **Symlink-escape protection** — resolved symlinks validated before any file operation
- **ZIP-slip protection** — import archives validated against path traversal attacks
- **Encrypted key storage** — API keys stored in Android Keystore, never in Dart memory
- **Confirmation gate** — destructive operations always require explicit user approval
- **Audit trail** — all agent tool calls logged per session

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI & Logic | Flutter 3.47 / Dart 3.13 |
| State | Riverpod 2.6 |
| Routing | go_router 15 |
| Code Editor | flutter_code_editor 0.3 (100+ languages) |
| ZIP | archive 3.6 (pure Dart) |
| Secrets | Android Keystore via SecretsChannel |
| SAF | ActivityResultLauncher (Kotlin) via StorageChannel |
| Process Management | ProcessService + ProcessForegroundService (Kotlin) |
| Platform Channels | EventChannel + MethodChannel (Dart ↔ Kotlin) |
| Python Runtime | CPython ARM64 (via ProcessChannel) |
| AI Inference *(planned)* | llama.cpp via Dart FFI |
| JS Runtime *(planned)* | QuickJS ARM64 |

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.47+ (`flutter --version`)
- Android Studio / SDK with API 26+ target
- An Android device (ARM64 recommended) or emulator

### Build & Run

```bash
git clone https://github.com/abdulghanisidz/Mylonite-IDE.git
cd Mylonite-IDE
flutter pub get
flutter run
```

### Build APK

```bash
flutter build apk --debug
```

The APK will be at `build/app/outputs/flutter-apk/app-debug.apk`.

### Test Python Execution

Once installed, you can test Python execution:

1. Open the app and create a new project
2. Create a Python file (e.g., `hello.py`)
3. Write a simple script:
   ```python
   print("Hello from Mylonite IDE!")
   for i in range(5):
       print(f"Count: {i}")
   ```
4. Use the Runtime Manager to check Python installation
5. Execute the script and see real-time output streaming

---

## 🎯 Current Capabilities

### ✅ What Works Now (Phase 5)
- **Project Management**: Create, open, import/export projects as ZIP
- **Code Editor**: Multi-tab editing with syntax highlighting for 100+ languages
- **File Explorer**: Full file tree with create/rename/delete operations
- **Python Execution**: Run Python scripts with real-time stdout/stderr streaming
- **Runtime Manager**: Detect, install, and configure Python runtime
- **Process Management**: Background execution with foreground service
- **Security**: Workspace sandboxing, symlink protection, encrypted secrets

### 🔜 Coming Next (Phase 6+)
- JavaScript runtime (QuickJS)
- Interactive terminal with PTY
- AI provider integration (OpenAI, Anthropic, local models)
- Local inference with llama.cpp
- Autonomous AI agent with 13 development tools
- Virtual environment support
- Package manager integration (pip, npm)

---

## 🌟 Project Highlights

### Advanced Features Implemented
- **Real-time Process Streaming**: EventChannel-based architecture for live stdout/stderr
- **Foreground Service Architecture**: Keep processes running even when app is backgrounded
- **Diagnostic Parsing**: Smart Python traceback parsing with error location extraction
- **Secure Secrets Management**: Android Keystore integration for API key encryption
- **SAF Integration**: Full access to device storage with proper Android permissions
- **Path Traversal Protection**: Comprehensive security against symlink escapes and ZIP-slip attacks

### Technical Achievements
- Clean 5-layer architecture with clear separation of concerns
- Type-safe platform channel interfaces (Dart ↔ Kotlin)
- Comprehensive error handling with structured error codes
- Streaming architecture for large output handling
- Process lifecycle management (timeout, OOM detection, graceful shutdown)

---

## 📄 Documentation

All 9 architecture documents are in [`docs/`](docs/):

- [`00-PROJECT-VISION.md`](docs/00-PROJECT-VISION.md) — Product vision and MVP definition
- [`01-REQUIREMENTS.md`](docs/01-REQUIREMENTS.md) — 90+ functional and security requirements
- [`02-ARCHITECTURE.md`](docs/02-ARCHITECTURE.md) — System architecture, ADRs, component map
- [`03-AI-AGENT.md`](docs/03-AI-AGENT.md) — Agent loop, tool system, 14 tool definitions
- [`04-RUNTIME-SYSTEM.md`](docs/04-RUNTIME-SYSTEM.md) — Python/JS runtime architecture
- [`05-OFFLINE-AI.md`](docs/05-OFFLINE-AI.md) — llama.cpp, GGUF, device tiers, quantization
- [`06-SECURITY.md`](docs/06-SECURITY.md) — Threat model, sandbox, prompt injection defence
- [`07-DATA-MODELS.md`](docs/07-DATA-MODELS.md) — All entity models and storage layout
- [`08-ROADMAP.md`](docs/08-ROADMAP.md) — 16-phase development roadmap

---

## 🤝 Contributing

This project is in active development (Phase 5 complete, Phase 6 in progress). Contributions are welcome!

### Current Focus Areas
- JavaScript runtime integration (QuickJS ARM64)
- Terminal emulation improvements
- AI provider abstraction layer
- Local inference with llama.cpp

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Guidelines
- Follow the existing code structure (see `docs/02-ARCHITECTURE.md`)
- Add documentation for new features
- Test on Android ARM64 devices
- Update relevant docs in `docs/` if architecture changes

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with Flutter · Targeting Android ARM64 · Offline First · Python Runtime Enabled*

---

### 📊 Project Stats

- **Lines of Code**: ~15,000+ (Dart + Kotlin)
- **Architecture Documents**: 9 comprehensive guides
- **Platform Channels**: 4 (Process, Storage, System, Secrets)
- **Supported Languages**: 100+ syntax highlighting
- **Minimum Android**: API 26 (Android 8.0)
- **Phase**: 5 of 15 complete (33% milestone)

---

<div align="center">

**[Report Bug](https://github.com/abdulghanisidz/Mylonite-IDE/issues)** · 
**[Request Feature](https://github.com/abdulghanisidz/Mylonite-IDE/issues)** · 
**[View Docs](docs/)**

</div>
