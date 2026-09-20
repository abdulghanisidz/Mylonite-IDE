# 01 — Requirements

**Project:** Mylonite IDE  
**Version:** 0.1 (Architecture Phase)  
**Status:** Pre-implementation  
**Last Updated:** 2026-08-30

---

## Table of Contents

1. [Requirement Conventions](#1-requirement-conventions)
2. [Device Tiers](#2-device-tiers)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [Security Requirements](#5-security-requirements)
6. [Performance Requirements](#6-performance-requirements)
7. [Platform & Technical Constraints](#7-platform--technical-constraints)
8. [MVP Requirements](#8-mvp-requirements)
9. [Future Requirements (Post-V1)](#9-future-requirements-post-v1)
10. [Out-of-Scope Requirements](#10-out-of-scope-requirements)
11. [Requirement Traceability Index](#11-requirement-traceability-index)

---

## 1. Requirement Conventions

### Identifiers

Each requirement is assigned a unique ID using the following prefixes:

| Prefix | Category |
|---|---|
| `FR-` | Functional Requirement |
| `NFR-` | Non-Functional Requirement |
| `SEC-` | Security Requirement |
| `PERF-` | Performance Requirement |
| `CON-` | Constraint |
| `MVP-` | Minimum Viable Product Requirement |
| `FUT-` | Future Requirement (Post-V1) |
| `OOS-` | Out of Scope |

### Priority Levels

| Label | Meaning |
|---|---|
| **MUST** | Mandatory for V1. No exceptions. |
| **SHOULD** | Strongly desired for V1. May be deferred to a later V1 milestone. |
| **MAY** | Optional enhancement. May appear in V1 if practical. |
| **FUTURE** | Planned for post-V1. Architecture must not prevent it. |

### Feasibility Labels

| Label | Meaning |
|---|---|
| Confirmed | Known to be technically achievable on Android |
| Likely Feasible | Strong reason to believe it works; prototype needed to confirm |
| Requires Investigation | Architecture depends on unresolved technical questions |
| Experimental | Possible but not proven in this context |
| Out of Scope | Will not be attempted |

---

## 2. Device Tiers

All requirements and performance targets reference the following device classification. These tiers reflect realistic Android market segments as of 2026.

### Tier A — Low-End

| Property | Specification |
|---|---|
| RAM | 3–4 GB total device RAM |
| CPU | ARM64 quad-core, ≤2.0 GHz typical |
| Storage | 32–64 GB |
| GPU | Low-end integrated |
| NPU | Absent or minimal |
| Android Version | Android 8–11 |
| Examples | Budget devices, older mid-range |

**Capability in this product:**
- Code editor and file management: supported
- Python runtime (scripting): supported
- JavaScript runtime: supported
- Local AI model: Tiny profile only (~1B quantized); may be impractical
- AI agent: limited; dependent on model availability

### Tier B — Mid-Range

| Property | Specification |
|---|---|
| RAM | 6–8 GB total device RAM |
| CPU | ARM64 octa-core, 2.0–3.0 GHz |
| Storage | 128–256 GB |
| GPU | Mid-range integrated (Adreno 6xx / Mali-G57 class) |
| NPU | Present on many devices (Snapdragon, Dimensity, Exynos) |
| Android Version | Android 11–14 |
| Examples | Snapdragon 7-series, Dimensity 8-series, mid-range flagships |

**Capability in this product:**
- Full V1 feature set supported
- Python and JavaScript runtimes: supported
- Local AI model: Tiny (~1B) and Balanced (~3B quantized) profiles
- AI agent: full V1 agent loop supported
- **This is the minimum device tier for full V1 operation.**

### Tier C — High-End

| Property | Specification |
|---|---|
| RAM | 10–16 GB total device RAM |
| CPU | ARM64 high-performance cores, 3.0+ GHz |
| Storage | 256–512 GB |
| GPU | High-end (Adreno 7xx / 8xx, Mali-G715 class) |
| NPU | Capable NPU (Hexagon DSP, Apple-class on comparable Android) |
| Android Version | Android 13+ |
| Examples | Snapdragon 8-series, Dimensity 9-series, flagship devices |

**Capability in this product:**
- All V1 features with better performance margins
- Local AI model: Balanced (~3B) and Power (~7B quantized) profiles feasible
- AI agent: full agent loop with larger context windows
- More aggressive parallelism (runtime + inference simultaneously)

---

## 3. Functional Requirements

### 3.1 Project Management

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-001 | The application MUST allow users to create new projects with a name and target language | MUST | Confirmed |
| FR-002 | The application MUST allow users to open existing projects stored in app-internal storage | MUST | Confirmed |
| FR-003 | The application MUST allow users to close the current project | MUST | Confirmed |
| FR-004 | The application MUST allow users to delete a project with explicit confirmation | MUST | Confirmed |
| FR-005 | The application MUST persist project metadata (name, language, creation date, last opened) | MUST | Confirmed |
| FR-006 | The application SHOULD allow users to rename a project | SHOULD | Confirmed |
| FR-007 | The application SHOULD support importing a project from a ZIP archive via SAF | SHOULD | Likely Feasible |
| FR-008 | The application SHOULD support exporting a project as a ZIP archive via SAF | SHOULD | Likely Feasible |
| FR-009 | The application MAY list recently opened projects on the home screen | MAY | Confirmed |

### 3.2 File System and Explorer

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-010 | The application MUST provide a file explorer showing the project directory tree | MUST | Confirmed |
| FR-011 | The application MUST allow creating new files within the project workspace | MUST | Confirmed |
| FR-012 | The application MUST allow creating new directories within the project workspace | MUST | Confirmed |
| FR-013 | The application MUST allow renaming files and directories | MUST | Confirmed |
| FR-014 | The application MUST allow deleting files with explicit confirmation | MUST | Confirmed |
| FR-015 | The application MUST allow deleting directories with explicit confirmation | MUST | Confirmed |
| FR-016 | The application MUST restrict all AI and runtime file access to the active project workspace by default | MUST | Confirmed |
| FR-017 | The application SHOULD support moving files within the project workspace | SHOULD | Confirmed |
| FR-018 | The application SHOULD support copying files within the project workspace | SHOULD | Confirmed |
| FR-019 | The application MAY support accessing files outside the app workspace via SAF with explicit user action | MAY | Likely Feasible |

### 3.3 Code Editor

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-020 | The editor MUST display file content with syntax highlighting for supported languages | MUST | Confirmed |
| FR-021 | The editor MUST display line numbers | MUST | Confirmed |
| FR-022 | The editor MUST support touch-based cursor placement and selection | MUST | Confirmed |
| FR-023 | The editor MUST support copy, cut, and paste operations | MUST | Confirmed |
| FR-024 | The editor MUST support undo and redo with a reasonable history depth | MUST | Confirmed |
| FR-025 | The editor MUST support saving files explicitly and auto-save on navigation away | MUST | Confirmed |
| FR-026 | The editor MUST support in-file text search | MUST | Confirmed |
| FR-027 | The editor SHOULD support in-file text search and replace | SHOULD | Confirmed |
| FR-028 | The editor SHOULD support multiple open file tabs | SHOULD | Confirmed |
| FR-029 | The editor SHOULD display inline diagnostic markers (errors, warnings) | SHOULD | Likely Feasible |
| FR-030 | The editor SHOULD display AI-proposed code changes as a diff preview | SHOULD | Likely Feasible |
| FR-031 | The editor SHOULD allow accepting or rejecting AI-proposed changes | SHOULD | Likely Feasible |
| FR-032 | The editor MAY support basic auto-completion (keyword/snippet level, not LSP) | MAY | Likely Feasible |
| FR-033 | The editor architecture MUST be implemented behind an abstraction so the underlying component can be replaced | MUST | Confirmed |

### 3.4 Terminal and Process Interaction

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-034 | The application MUST provide a terminal-like interface for interacting with running processes | MUST | Likely Feasible |
| FR-035 | The terminal MUST display stdout and stderr from executed processes | MUST | Likely Feasible |
| FR-036 | The terminal MUST support sending stdin to running processes | MUST | Likely Feasible |
| FR-037 | The terminal MUST support killing/cancelling a running process | MUST | Likely Feasible |
| FR-038 | The terminal MUST display exit codes | MUST | Confirmed |
| FR-039 | The terminal SHOULD persist output history for the current session | SHOULD | Confirmed |
| FR-040 | The terminal MUST NOT assume a POSIX shell (bash/sh) is available on the system | MUST | Confirmed |
| FR-041 | The terminal SHOULD support a basic set of built-in commands (clear, history, kill) | SHOULD | Confirmed |
| FR-042 | The terminal architecture MUST route execution through the Runtime Manager, not directly to system shell | MUST | Confirmed |

### 3.5 Runtime Execution

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-043 | The application MUST support executing Python scripts locally on the device | MUST | Likely Feasible |
| FR-044 | The application MUST support executing JavaScript locally on the device | MUST | Likely Feasible |
| FR-045 | The application MUST manage runtimes through a RuntimeManager abstraction | MUST | Confirmed |
| FR-046 | Each runtime MUST implement a common RuntimeInterface defining execution, cancellation, and status | MUST | Confirmed |
| FR-047 | The application MUST capture stdout, stderr, and exit code from all runtime executions | MUST | Likely Feasible |
| FR-048 | The application MUST support execution timeouts with automatic process termination | MUST | Likely Feasible |
| FR-049 | The application MUST support manual cancellation of running code | MUST | Likely Feasible |
| FR-050 | Runtimes MUST be isolated to the application's private storage directory | MUST | Confirmed |
| FR-051 | The application SHOULD support installing Python packages via pip into the project's local package directory (`.packages/`) using `pip --target` | SHOULD | Likely Feasible |
| FR-052 | The application SHOULD support installing JavaScript packages via npm within the project's node_modules | SHOULD | Requires Investigation |
| FR-053 | The application MUST support adding new runtimes without modifying the agent or editor layers | MUST | Confirmed |
| FR-054 | The application SHOULD display runtime version information | SHOULD | Confirmed |
| FR-055 | The application SHOULD support multiple installed versions of the same runtime | SHOULD | Requires Investigation |

### 3.6 AI Assistant and Agent

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-056 | The application MUST include an AI coding assistant accessible from the editor | MUST | Confirmed |
| FR-057 | The AI MUST be able to answer questions about code in the current project | MUST | Confirmed |
| FR-058 | The AI MUST be able to generate new code and propose it for insertion | MUST | Confirmed |
| FR-059 | The AI MUST operate without internet access when using the local model | MUST | Likely Feasible |
| FR-060 | The application MUST include an autonomous AI agent mode | MUST | Likely Feasible |
| FR-061 | The agent MUST be able to read project files using a controlled tool | MUST | Confirmed |
| FR-062 | The agent MUST be able to write and modify project files using a controlled tool | MUST | Confirmed |
| FR-063 | The agent MUST be able to create new files using a controlled tool | MUST | Confirmed |
| FR-064 | The agent MUST be able to list directories using a controlled tool | MUST | Confirmed |
| FR-065 | The agent MUST be able to execute code using a controlled tool | MUST | Likely Feasible |
| FR-066 | The agent MUST be able to read process output using a controlled tool | MUST | Likely Feasible |
| FR-067 | The agent MUST be able to search project files using a controlled tool | MUST | Confirmed |
| FR-068 | The agent MUST have a maximum iteration limit to prevent infinite loops | MUST | Confirmed |
| FR-069 | The agent MUST have a token budget limit per session | MUST | Confirmed |
| FR-070 | The agent MUST be stoppable by the user at any point | MUST | Confirmed |
| FR-071 | The agent MUST request user confirmation before deleting files | MUST | Confirmed |
| FR-072 | The agent MUST request user confirmation before executing shell commands outside approved runtimes | MUST | Confirmed |
| FR-073 | The agent MUST be restricted to the active project workspace | MUST | Confirmed |
| FR-074 | The AI provider abstraction MUST allow switching between local and cloud providers | MUST | Confirmed |
| FR-075 | The application MUST function fully if no cloud AI provider is configured | MUST | Confirmed |

### 3.7 AI Model Management

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-076 | The application MUST support listing locally installed AI models | MUST | Confirmed |
| FR-077 | The application MUST support activating and deactivating a local model | MUST | Confirmed |
| FR-078 | The application MUST support deleting a local model | MUST | Confirmed |
| FR-079 | The application SHOULD support downloading a model from a configured source | SHOULD | Likely Feasible |
| FR-080 | The application SHOULD display estimated RAM requirements for each model | SHOULD | Likely Feasible |
| FR-081 | The application SHOULD warn the user if the selected model likely exceeds available RAM | SHOULD | Likely Feasible |
| FR-082 | The application MAY support importing a model from local storage via SAF | MAY | Likely Feasible |

### 3.8 Code Search

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-083 | The application MUST support text search across all project files | MUST | Confirmed |
| FR-084 | The application MUST support filename search | MUST | Confirmed |
| FR-085 | The application SHOULD support regex search | SHOULD | Confirmed |
| FR-086 | The application MAY support symbol search (functions, classes) | MAY | Requires Investigation |
| FR-087 | Search results MUST include file path and line number | MUST | Confirmed |

### 3.9 Settings

| ID | Requirement | Priority | Feasibility |
|---|---|---|---|
| FR-088 | The application MUST provide a settings screen covering editor preferences, AI configuration, and runtime settings | MUST | Confirmed |
| FR-089 | The application MUST persist settings across sessions | MUST | Confirmed |
| FR-090 | The application SHOULD support per-project settings that override global settings where applicable | SHOULD | Confirmed |

---

## 4. Non-Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| NFR-001 | The application MUST be built using Flutter as the primary UI framework | MUST |
| NFR-002 | The application MUST target Android as the primary platform | MUST |
| NFR-003 | The application MUST function without any internet connection for all core features | MUST |
| NFR-004 | The application MUST NOT require root access | MUST |
| NFR-005 | All major subsystems (editor, runtime, AI, filesystem, agent) MUST be implemented behind defined interfaces | MUST |
| NFR-006 | The application MUST handle Android process lifecycle events (pause, resume, kill) without data loss | MUST |
| NFR-007 | The application MUST handle low-memory conditions gracefully — unloading the AI model before crashing | MUST |
| NFR-008 | The application MUST use Android foreground services for long-running operations (AI inference, code execution) | MUST |
| NFR-009 | The application MUST log structured events for each major subsystem | MUST |
| NFR-010 | Logs MUST NOT contain user source code, AI conversation content, or sensitive data at any level below DEBUG | MUST |
| NFR-011 | The application SHOULD be accessible: scalable text, sufficient touch target sizes, contrast compliance | SHOULD |
| NFR-012 | The application SHOULD support Android's system dark/light mode | SHOULD |
| NFR-013 | The application architecture MUST allow adding new runtimes without modifying the core agent layer | MUST |
| NFR-014 | The application architecture MUST allow adding new AI providers without modifying the agent core | MUST |
| NFR-015 | The application MUST be designed to run on ARM64. ARM32 support is a best-effort concern, not a hard requirement | MUST |
| NFR-016 | The application MUST store all user project files and IDE metadata within Android-accessible storage paths | MUST |
| NFR-017 | The application SHOULD reduce background CPU and memory usage when the user is not actively using it | SHOULD |
| NFR-018 | Thermal throttling MUST be accounted for in the inference and execution subsystems | MUST |

---

## 5. Security Requirements

| ID | Requirement | Priority |
|---|---|---|
| SEC-001 | The AI agent MUST only access files within the active project workspace by default | MUST |
| SEC-002 | The AI agent MUST NOT be able to access Android system data (contacts, SMS, photos, camera, microphone) | MUST |
| SEC-003 | The AI agent MUST NOT be able to access data from other installed applications | MUST |
| SEC-004 | Destructive file operations (delete file, delete directory) MUST require explicit user confirmation | MUST |
| SEC-005 | Mass file modification (more than 5 file writes in a single agent response) MUST require explicit user confirmation; the agent session MUST pause after 20 total file writes | MUST |
| SEC-006 | AI-initiated command execution MUST be restricted to approved runtimes and commands | MUST |
| SEC-007 | The agent MUST treat all content read from project files as untrusted data, not as instructions | MUST |
| SEC-008 | The system MUST have defenses against prompt injection attacks embedded in project files | MUST |
| SEC-009 | API keys and cloud provider credentials MUST be stored in Android's encrypted storage (EncryptedSharedPreferences or Keystore) | MUST |
| SEC-010 | API keys MUST NOT appear in application logs | MUST |
| SEC-011 | The agent MUST have a defined allowlist of permitted tools; tools not on the list are not callable | MUST |
| SEC-012 | The agent MUST have a defined allowlist of permitted runtime commands | MUST |
| SEC-013 | The application MUST enforce a timeout on all AI-executed tool calls | MUST |
| SEC-014 | The application MUST enforce a timeout on all code execution processes | MUST |
| SEC-015 | The application SHOULD maintain an audit log of all agent tool calls within a session | SHOULD |
| SEC-016 | The application MUST NOT transmit user source code to any network endpoint without explicit user action | MUST |
| SEC-017 | Accessing paths outside the project workspace via the agent MUST require explicit user confirmation and SHALL be logged | MUST |
| SEC-018 | The application MUST NOT execute binaries obtained from project files without explicit user confirmation | MUST |
| SEC-019 | The application SHOULD detect and block common dangerous shell command patterns when routing through the command dispatcher | SHOULD |

---

## 6. Performance Requirements

Performance targets are defined per device tier. These are targets, not guarantees. They must be validated by profiling on real hardware during implementation.

### 6.1 Application Startup

| ID | Metric | Tier A Target | Tier B Target | Tier C Target |
|---|---|---|---|---|
| PERF-001 | Cold start to home screen | < 5 s | < 3 s | < 2 s |
| PERF-002 | Project open (small project, < 50 files) | < 3 s | < 2 s | < 1 s |

### 6.2 Editor

| ID | Metric | Tier A Target | Tier B Target | Tier C Target |
|---|---|---|---|---|
| PERF-003 | Keystroke-to-display latency | < 32 ms | < 16 ms | < 16 ms |
| PERF-004 | File open (< 500 lines) | < 500 ms | < 200 ms | < 100 ms |
| PERF-005 | File open (< 5000 lines) | < 2 s | < 1 s | < 500 ms |
| PERF-006 | Undo/redo operation | < 100 ms | < 50 ms | < 30 ms |

### 6.3 Search

| ID | Metric | Tier A Target | Tier B Target | Tier C Target |
|---|---|---|---|---|
| PERF-007 | Text search across project (< 100 files) | < 3 s | < 1 s | < 500 ms |
| PERF-008 | Filename search (any project size) | < 500 ms | < 200 ms | < 100 ms |

### 6.4 Code Execution

| ID | Metric | Tier A Target | Tier B Target | Tier C Target |
|---|---|---|---|---|
| PERF-009 | Python runtime cold start (first run after app launch) | < 5 s | < 3 s | < 2 s |
| PERF-010 | Python runtime warm start (subsequent runs) | < 2 s | < 1 s | < 500 ms |
| PERF-011 | JavaScript runtime cold start | < 4 s | < 2 s | < 1 s |
| PERF-012 | Hello World script execution (wall clock) | < 3 s | < 2 s | < 1 s |

### 6.5 AI Inference

| ID | Metric | Tier A Target | Tier B Target | Tier C Target | Notes |
|---|---|---|---|---|---|
| PERF-013 | Local model load time (1B quantized) | < 10 s | < 6 s | < 3 s | Cold load |
| PERF-014 | Local model load time (3B quantized) | N/A | < 15 s | < 8 s | Tier A cannot run 3B |
| PERF-015 | First token latency (1B model, prompt < 512 tokens) | < 5 s | < 3 s | < 2 s | |
| PERF-016 | First token latency (3B model, prompt < 512 tokens) | N/A | < 8 s | < 4 s | |
| PERF-017 | Generation throughput (1B model) | ≥ 5 tok/s | ≥ 10 tok/s | ≥ 20 tok/s | CPU inference |
| PERF-018 | Generation throughput (3B model) | N/A | ≥ 3 tok/s | ≥ 8 tok/s | |

> **Note on PERF-013 through PERF-018:** These are best-effort targets based on current llama.cpp benchmarks on comparable ARM64 hardware. They MUST be validated by profiling. Thermal throttling will degrade sustained throughput significantly; these targets apply to initial non-throttled inference.

### 6.6 Memory Usage

| ID | Metric | Target |
|---|---|---|
| PERF-019 | App idle memory (model not loaded) | < 200 MB |
| PERF-020 | App + Python runtime (no model) | < 400 MB |
| PERF-021 | App + 1B Q4 model loaded | < 1.5 GB total |
| PERF-022 | App + 3B Q4 model loaded | < 3.5 GB total |

> Memory targets assume the application is the primary foreground application. Android background system usage is not included.

---

## 7. Platform & Technical Constraints

| ID | Constraint | Implication |
|---|---|---|
| CON-001 | Android provides no system Python or Node.js interpreter | Runtimes must be bundled as prebuilt ARM64 binaries within app storage |
| CON-002 | Android API 26+ (Android 8.0) is the minimum | Required for foreground service APIs and baseline storage access |
| CON-003 | Android scoped storage (API 29+) restricts file system access | Projects stored in app-internal storage; user-external access via SAF only |
| CON-004 | Android kills background processes aggressively | Long-running inference and execution require foreground services with notification |
| CON-005 | Normal Android apps cannot execute arbitrary downloaded binaries | All executable binaries must be part of the APK or installed to app-internal storage with execute permission (`chmod +x`) on a path not mounted `noexec` |
| CON-006 | No root access assumed | Cannot use system directories, cannot modify PATH system-wide |
| CON-007 | ARM64 is the primary binary target | All native code (runtimes, inference engine) must be compiled for `arm64-v8a`. `armeabi-v7a` support is best-effort. |
| CON-008 | Android WebView and JVM are available but have their own sandboxing | JavaScript execution via embedded JS engine (e.g., QuickJS) or Node.js is preferred over WebView for code execution |
| CON-009 | Android MemoryInfo provides available RAM but not a guarantee | The application must monitor available memory and unload resources proactively |
| CON-010 | Flutter's Dart isolates share the same process | Heavy computation (inference, indexing) should be offloaded to native code or separate Android services to avoid blocking the UI |
| CON-011 | Android thermal API (API 29+) can signal thermal status | The application should reduce inference load when thermal status is THROTTLING or SHUTDOWN |
| CON-012 | JNI or FFI is required to bridge Flutter/Dart to native C/C++ libraries | llama.cpp and native runtime libraries will require this bridge |
| CON-013 | Android's `ProcessBuilder` / `Runtime.exec()` can spawn child processes from the app's own storage | This is the mechanism for running Python, Node, and other runtimes |
| CON-014 | Storage for models and runtimes is significant — users on 32 GB devices may not have room for both | The app must clearly communicate storage requirements before download |

---

## 8. MVP Requirements

The following requirements constitute the minimum set for the MVP demonstration described in `00-PROJECT-VISION.md` Section 7. All MVP requirements are a subset of the full functional requirements above.

| ID | MVP Requirement | References |
|---|---|---|
| MVP-001 | User can launch the application and see a home screen | FR-001 |
| MVP-002 | User can create a new Python project | FR-001 |
| MVP-003 | User can create, open, edit, and save a `.py` file | FR-011, FR-020–FR-025 |
| MVP-004 | User can view the file explorer for the project | FR-010 |
| MVP-005 | User can open the AI agent panel | FR-060 |
| MVP-006 | The AI agent can read a file in the project | FR-061 |
| MVP-007 | The AI agent can write/modify a file in the project | FR-062 |
| MVP-008 | The AI agent can create a new file in the project | FR-063 |
| MVP-009 | The AI agent can execute a Python script and receive stdout/stderr | FR-065, FR-066 |
| MVP-010 | The AI agent can search the project files | FR-067 |
| MVP-011 | The agent enforces a maximum iteration limit | FR-068 |
| MVP-012 | The user can stop the agent at any time | FR-070 |
| MVP-013 | The Python runtime is available and functional on Tier B hardware | FR-043 |
| MVP-014 | The local AI model loads and generates text on Tier B hardware | FR-059 |
| MVP-015 | The complete MVP loop (create → generate → run → introduce error → fix → validate) works without internet | NFR-003 |
| MVP-016 | The agent does not access files outside the project workspace | SEC-001 |

---

## 9. Future Requirements (Post-V1)

These requirements are documented for architectural awareness. They must not block V1 development but the architecture must not make them impossible.

| ID | Future Requirement | Phase Reference |
|---|---|---|
| FUT-001 | JavaScript project type with Node.js runtime (QuickJS is V1; Node.js needed for npm ecosystem) | Post-V1 |
| FUT-002 | TypeScript support (transpile to JS) | Post-V1 |
| FUT-003 | npm package installation and node_modules support (requires FUT-001 Node.js runtime) | Post-V1 |
| FUT-004 | pip package installation with true virtual environments (venv); V1 uses `--target` installs | Post-V1 |
| FUT-005 | Git integration (init, status, diff, add, commit, branch) | Post-V1 |
| FUT-006 | Functional cloud AI provider integration (Gemini, OpenAI); Phase 8 registers stubs only | Post-V1 |
| FUT-007 | Offline documentation browser | Post-V1 |
| FUT-008 | Step-through debugger with breakpoints | Post-V1 |
| FUT-009 | Language Server Protocol (LSP) integration for autocomplete/go-to-def | Post-V1 |
| FUT-010 | C/C++ compilation and execution | Post-V1 |
| FUT-011 | Java/Kotlin support | Post-V1 |
| FUT-012 | Plugin/extension system | Post-V1 |
| FUT-013 | Tablet-optimized split-panel UI | Post-V1 |
| FUT-014 | Remote SSH development | Post-V1 |
| FUT-015 | Multiple model profiles with automatic selection by device tier | Phase 9+ |
| FUT-016 | Project-level AI model selection override | Post-V1 |
| FUT-017 | Collaborative features (cloud sync) | Post-V1 |

---

## 10. Out-of-Scope Requirements

These are explicitly excluded from all versions considered in this documentation.

| ID | Out-of-Scope Item | Reason |
|---|---|---|
| OOS-001 | iOS support | Different platform, different sandboxing model, different binary format |
| OOS-002 | Desktop OS (Windows/macOS/Linux) as a primary target | Out of V1 scope; future consideration only |
| OOS-003 | Cloud backend / server-side execution | Contradicts offline-first principle for core features |
| OOS-004 | Full Linux environment (chroot, proot) | Requires root or kernel-level access on standard devices |
| OOS-005 | Enterprise authentication (SSO, LDAP, OAuth for teams) | Out of V1 scope |
| OOS-006 | Real-time collaborative editing | Out of V1 scope |
| OOS-007 | Arbitrary native binary compilation on-device (C/C++) | Requires a cross-compiler or on-device compiler; very high storage/complexity |
| OOS-008 | System-level package management (apt, pacman) | Not possible without root |
| OOS-009 | Running arbitrary Android APKs from within the IDE | Security and sandboxing limitations |
| OOS-010 | Multi-user or organization accounts | Out of V1 scope |

---

## 11. Requirement Traceability Index

This index maps requirements to the architectural documents that address them.

| Requirement Group | Primary Document | Supporting Documents |
|---|---|---|
| FR-001–FR-009 (Project Management) | `02-ARCHITECTURE.md` §Workspace | `07-DATA-MODELS.md` §Project |
| FR-010–FR-019 (Filesystem) | `02-ARCHITECTURE.md` §Filesystem | `06-SECURITY.md` §Sandbox, `07-DATA-MODELS.md` §File |
| FR-020–FR-033 (Editor) | `02-ARCHITECTURE.md` §Editor | `07-DATA-MODELS.md` §File |
| FR-034–FR-042 (Terminal) | `04-RUNTIME-SYSTEM.md` §ProcessManager | `02-ARCHITECTURE.md` §Terminal |
| FR-043–FR-055 (Runtime Execution) | `04-RUNTIME-SYSTEM.md` | `07-DATA-MODELS.md` §Runtime |
| FR-056–FR-075 (AI Agent) | `03-AI-AGENT.md` | `02-ARCHITECTURE.md` §Agent, `06-SECURITY.md` §AgentSandbox |
| FR-076–FR-082 (Model Management) | `05-OFFLINE-AI.md` §ModelManager | `07-DATA-MODELS.md` §AIModel |
| FR-083–FR-087 (Search) | `02-ARCHITECTURE.md` §Search | `03-AI-AGENT.md` §ToolRegistry |
| FR-088–FR-090 (Settings) | `07-DATA-MODELS.md` §Settings | `02-ARCHITECTURE.md` |
| NFR-001–NFR-018 | `02-ARCHITECTURE.md` | All documents |
| SEC-001–SEC-019 | `06-SECURITY.md` | `03-AI-AGENT.md` §ToolPermissions |
| PERF-001–PERF-022 | `02-ARCHITECTURE.md` §Performance | `05-OFFLINE-AI.md` §Performance |
| CON-001–CON-014 | `02-ARCHITECTURE.md` §PlatformLayer | `04-RUNTIME-SYSTEM.md` |
| MVP-001–MVP-016 | `08-ROADMAP.md` §Phase4–11 | `03-AI-AGENT.md`, `04-RUNTIME-SYSTEM.md` |

---

*Next: `02-ARCHITECTURE.md` — System architecture, component breakdown, data flow, and platform layer design.*
