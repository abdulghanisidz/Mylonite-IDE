# ⬡ Mylonite IDE

> **An offline-first mobile development environment for Android.**  
> Write code, run it locally, and get help from an on-device AI agent — no internet required.

[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.1-blue?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2026%2B-green?logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Phase](https://img.shields.io/badge/Phase-3%20%E2%80%94%20Editor-purple)]()

---

## What is Mylonite IDE?

Mylonite IDE turns your Android smartphone into a self-contained development machine. It provides a full code editor, local project management, and an autonomous AI coding agent — all running completely offline on your device.

```
Open IDE → Create Project → Write Code → Run Locally → AI Agent Debugs → 
All without internet.
```

---

## ✨ Features (Phases 0–3)

| Feature | Status |
|---|---|
| 9-document architecture blueprint | ✅ Complete |
| Flutter app shell + dark/light theme | ✅ Complete |
| Project creation, management, persistence | ✅ Complete |
| WorkspaceManager with path confinement + symlink protection | ✅ Complete |
| File explorer — create, rename, delete, expand/collapse | ✅ Complete |
| ZIP import/export with zip-slip protection | ✅ Complete |
| File watcher (polling-based auto-refresh) | ✅ Complete |
| SAF (Storage Access Framework) integration | ✅ Complete |
| Code editor — syntax highlighting (Python + JS) | ✅ Complete |
| Multi-tab editor with dirty indicators | ✅ Complete |
| Undo/Redo (200-step history) | ✅ Complete |
| In-file search — text + regex + case toggle | ✅ Complete |
| AI diff preview — Accept / Reject | ✅ Complete |
| Diagnostic status bar (error/warning count) | ✅ Complete |
| Encrypted API key storage (Android Keystore) | ✅ Complete |
| Agent session audit trail | ✅ Complete |

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
│   │   └── services/              # ProjectManager, WorkspaceManager,
│   │       │                      # SettingsService, LoggingService, ZipService
│   │       └── editor/            # EditorController, EditorTab
│   ├── features/
│   │   ├── home/                  # Home screen
│   │   ├── projects/              # Projects screen (create/import/export)
│   │   ├── editor/                # Code editor screen
│   │   ├── explorer/              # File explorer screen
│   │   ├── terminal/              # Terminal screen
│   │   ├── agent/                 # AI Agent screen
│   │   ├── settings/              # Settings screen
│   │   ├── runtime_manager/       # Runtime Manager screen
│   │   └── model_manager/         # Model Manager screen
│   ├── platform/
│   │   └── channels/              # Dart-side Platform Channel stubs
│   └── ui/
│       └── theme/                 # AppTheme, AppColors
├── android/
│   └── app/src/main/kotlin/       # MainActivity, Platform Channels (Kotlin)
│       ├── channels/              # ProcessChannel, StorageChannel,
│       │                          # SystemChannel, SecretsChannel
│       └── services/              # ProcessForegroundService,
│                                  # InferenceForegroundService
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
| 4 | Execution Engine (Android process management) | 🔜 Next |
| 5 | Python Runtime (CPython ARM64) | 🔜 |
| 6 | JavaScript Runtime (QuickJS ARM64) | 🔜 |
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

## 🔒 Security Highlights

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
| Code Editor | flutter_code_editor 0.3 |
| ZIP | archive 3.6 (pure Dart) |
| Secrets | EncryptedSharedPreferences + Android Keystore |
| SAF | ActivityResultLauncher (Kotlin) |
| AI Inference *(planned)* | llama.cpp via Dart FFI |
| Python Runtime *(planned)* | CPython ARM64 prebuilt |
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

This project is in active development. Phases 4–15 are planned. Contributions welcome once Phase 3 stabilizes.

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with Flutter · Targeting Android ARM64 · Offline First · AI Powered*
