# 00 — Project Vision

**Project:** Mylonite IDE  
**Version:** 0.1 (Architecture Phase)  
**Status:** Pre-implementation  
**Last Updated:** 2026-08-30

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Vision](#2-vision)
3. [Target Users](#3-target-users)
4. [Product Philosophy](#4-product-philosophy)
5. [Core Capabilities](#5-core-capabilities)
6. [Constraints](#6-constraints)
7. [MVP Definition](#7-mvp-definition)
8. [Long-Term Direction](#8-long-term-direction)
9. [What This Product Is Not](#9-what-this-product-is-not)
10. [Success Criteria](#10-success-criteria)

---

## 1. Problem Statement

Modern software development is almost entirely desktop-bound. The tools developers rely on — editors, terminals, compilers, debuggers, and increasingly AI coding assistants — assume a laptop or workstation with reliable internet access, gigabytes of RAM, persistent background processes, and a desktop operating system.

Smartphones, however, have become extraordinarily capable. Flagship and mid-range Android devices now carry ARM64 CPUs with eight or more cores, 6–12 GB of RAM, 128–512 GB of fast storage, dedicated neural processing units, and GPU compute. Despite this, they remain nearly useless as development tools because the software ecosystem has not caught up with the hardware.

The specific gaps are:

- **No practical local code execution.** Android has no first-class support for running user code in arbitrary languages. There is no `python3` or `node` in the system shell.
- **No quality mobile-native editor.** Existing "code editor" apps are either barely functional text editors or remote-access wrappers that require a server.
- **No offline AI coding assistant.** Every AI coding tool on mobile requires a cloud API. When connectivity is unavailable — or undesirable — there is nothing.
- **No agent-level automation.** Even online tools offer only chat-style assistance. None can autonomously inspect a project, write code, run it, detect errors, and iterate.

The result: a developer with only a smartphone cannot meaningfully write, run, or debug software without cloud connectivity and a separate machine.

---

## 2. Vision

> A reasonably capable Android smartphone should be able to function as a small, self-contained development machine.

The Offline Mobile IDE is a fully self-sufficient development environment that runs entirely on an Android device. It provides:

- A capable mobile-native code editor
- Local project and file management
- Local execution of supported programming languages
- A terminal-like interface for interacting with running code
- An AI coding assistant and autonomous agent powered by a local language model
- All of the above without any mandatory internet connection

The product is not a desktop IDE ported to a smaller screen. It is a development environment designed from the ground up for the constraints, interaction patterns, and capabilities of modern Android smartphones.

The central design principle is **offline first**: every core function must work without any network access. Internet connectivity, when available, may be used optionally to extend the system — downloading models, fetching documentation, using cloud AI — but the core never depends on it.

---

## 3. Target Users

### Primary User

A developer (student, hobbyist, professional, or learner) who:

- Owns an Android smartphone
- Wants to write, run, and test code on that device
- May not always have reliable internet access
- Wants AI assistance that does not depend on cloud APIs
- Is comfortable with programming concepts but does not need enterprise tooling

### Secondary Users

- **Students in low-connectivity environments** who need a self-contained learning and development tool
- **Developers who travel** and want to work without depending on hotel Wi-Fi or tethering
- **Privacy-conscious developers** who do not want their code sent to cloud services
- **Experimenters and tinkerers** who want to explore what a smartphone can actually do as a compute device

### Non-Target Users (for V1)

- Enterprise teams requiring collaborative development
- Users requiring compilation of native binaries (C, C++, Rust) in V1
- Users requiring a full Linux distribution on their phone
- Users with extremely low-end devices (below Tier B — see `01-REQUIREMENTS.md`)

---

## 4. Product Philosophy

### 4.1 Offline First

Internet access is an enhancement, not a requirement. The application must be fully usable with no network connection. Every design decision must be evaluated against this principle first.

### 4.2 Mobile Native

The product is designed for smartphones. This means:

- Touch-first interaction design
- UI adapted for small screens and portrait orientation
- Architecture that respects Android process lifecycle, memory limits, and battery constraints
- No assumption that desktop conventions (persistent background daemons, unlimited file system access, continuous CPU usage) are available

This is not "VS Code squeezed onto a phone." Attempting that would produce an unusable product. The UX, architecture, and feature set must be rethought for the mobile context.

### 4.3 The AI Is an Agent, Not a Chatbot

The AI system is designed to take autonomous, multi-step action — not merely answer questions. Given a user request, the AI should be capable of:

1. Understanding what was asked
2. Inspecting the project to understand its structure and state
3. Planning a sequence of actions
4. Executing those actions using a controlled tool set (read files, write files, run code, observe output)
5. Detecting errors in the output
6. Reasoning about the cause
7. Applying a fix
8. Rerunning the code to validate
9. Reporting the result to the user

This loop must work entirely offline, using a locally loaded language model. Cloud APIs may be used as an optional upgrade, never as a baseline.

### 4.4 Modular and Replaceable

No subsystem should be permanently entangled with another. The editor, the runtime system, the AI provider, the storage layer, and the agent tool system should each have clear interfaces so that any individual component can be replaced, upgraded, or extended without rewriting the system.

### 4.5 Resource-Aware

The application runs on constrained hardware. RAM, CPU, battery, and storage are finite and shared with the Android operating system and other applications. The architecture must account for this at every layer, not treat it as an afterthought.

### 4.6 Security by Default

The AI agent operates with access to the user's project files and the ability to execute code. This is significant power. The default security posture must be restrictive: the AI can only access the active project workspace, cannot access device data outside that workspace, and must request confirmation before performing destructive or irreversible actions.

### 4.7 Honest Simplicity

V1 must do a small number of things correctly rather than many things poorly. The MVP must demonstrate a real, complete development loop — not a collection of loosely connected features that individually work but do not combine into a coherent experience.

---

## 5. Core Capabilities

The following capabilities define the product. Not all are required for V1 — see `01-REQUIREMENTS.md` and `08-ROADMAP.md` for phased delivery.

| Capability | Description |
|---|---|
| Code Editor | Syntax-highlighted, touch-friendly editor with essential editing operations |
| Project/File Explorer | Navigate and manage project files and directories |
| Local Code Execution | Run Python and JavaScript code on-device |
| Terminal Interface | Interact with running processes: stdin, stdout, stderr |
| Runtime Management | Install, configure, and manage supported language runtimes |
| Project Management | Create, open, close, import, export projects |
| AI Coding Assistant | Context-aware code suggestions, explanation, and generation |
| Autonomous AI Agent | Multi-step agent loop: inspect, plan, act, run, debug, validate |
| Error Detection | Identify syntax and runtime errors, surface them in the editor |
| AI-Assisted Debugging | Agent reads errors and proposes or applies fixes |
| Code Search | Local filename, text, symbol, and regex search |
| Offline Documentation | On-device reference material for supported languages |
| Offline AI Operation | All AI features available without internet |
| Optional Cloud AI | Plug-in support for Gemini, OpenAI, and future providers |

---

## 6. Constraints

### Platform Constraints

- **Android only** for V1. iOS is architecturally different and out of scope.
- **ARM64 primary target.** ARM32 compatibility considered where practical but not guaranteed for all features.
- **Android API level 26+ (Android 8.0)** as the minimum supported version. Higher minimums may be required for specific features (e.g., large memory allocation for AI inference).
- **Android sandboxing is real.** The application cannot arbitrarily execute system binaries, install packages system-wide, or access other applications' data. All runtimes must be bundled or installed within the application's own storage.
- **Scoped Storage.** Android 10+ imposes scoped storage restrictions. The application must use the Android Storage Access Framework (SAF) for user-initiated file access outside its own storage, and the Android MediaStore or app-specific directories for internally managed files.

### Hardware Constraints

- **RAM:** Minimum 4 GB available device RAM to run V1 features. AI inference requires additional RAM beyond the base application. See `05-OFFLINE-AI.md` for model memory requirements.
- **Storage:** Local runtimes and AI models require significant on-device storage. Python interpreter and standard library: ~50–100 MB. A quantized 1B model: ~700 MB–1 GB. A quantized 3B model: ~2–3 GB.
- **CPU:** ARM64 multi-core. AI inference will be CPU-bound on most devices. Thermal throttling is a real concern for sustained inference.
- **Battery:** Sustained AI inference and code execution are power-intensive operations. The application must be designed to work within Android's battery management constraints.

### Software Constraints

- **No system shell.** Android does not expose a usable `/bin/sh` equivalent to normal applications. All "terminal" interaction is mediated by the application itself through the runtime manager and process execution APIs.
- **Background execution limits.** Android aggressively kills background processes. Long-running inference or execution must be managed through foreground services where appropriate.
- **No root assumption.** The application must function entirely without root access.

### AI Constraints

- **Local models are small.** The largest practically usable model on mid-range hardware is likely in the 3B–7B parameter range, quantized to 4-bit. Capabilities are significantly below cloud models. The agent design must account for this.
- **Context windows are limited.** Small models have small context windows — typically 2K–8K tokens. The AI context management system must be aggressive about what it loads.

---

## 7. MVP Definition

The MVP must demonstrate the following complete, unbroken development loop:

```
1.  Launch the IDE
2.  Create a new Python project
3.  Create main.py
4.  Open the AI agent and request:
        "Create a simple command-line calculator."
5.  The AI agent:
        a. Inspects the project
        b. Plans the implementation
        c. Creates the code in main.py
        d. Runs main.py
        e. Observes the output
        f. Validates the result
6.  The user introduces a deliberate error into main.py
7.  The user asks the agent:
        "There is an error. Fix it."
8.  The AI agent:
        a. Reads the file
        b. Detects the error (possibly by running the code)
        c. Reasons about the cause
        d. Applies a fix
        e. Reruns the code
        f. Observes successful output
        g. Reports success to the user
9.  All of the above completed with no internet connection.
```

This loop, working reliably, end-to-end, offline, on a real Android device, is the MVP. It proves every major subsystem: editor, filesystem, runtime, AI inference, agent loop, tool system.

---

## 8. Long-Term Direction

The long-term vision, beyond V1 and the MVP:

| Area | Long-Term Goal |
|---|---|
| Language Support | Python, JavaScript, TypeScript, HTML/CSS, C, C++, Java, Kotlin, Dart |
| AI Models | Support multiple local model profiles (Tiny/Balanced/Power); pluggable model system |
| Cloud AI | Gemini, OpenAI, Anthropic, and other providers as optional backends |
| Git | Full local Git workflow (init, commit, branch, diff, merge); optional remote push/pull |
| Package Management | pip, npm with dependency resolution |
| Documentation | Offline language documentation browser |
| Plugin/Extension System | Community-extensible runtimes, tools, and AI providers |
| Debugger | Step-through debugging with breakpoints |
| Language Servers | LSP-based autocomplete, go-to-definition, diagnostics |
| Tablet UI | Larger screen layout with split editor/terminal/agent panels |
| Desktop | Potential desktop (Windows/macOS/Linux) version using the same core |
| Remote Development | Optional SSH-based remote execution |
| Collaboration | Optional cloud-synced project sharing |

These are aspirational. None are V1 requirements. The architecture must not block them, but must not be bloated in anticipation of them either.

---

## 9. What This Product Is Not

To prevent scope creep and maintain V1 focus, the following are explicitly out of scope:

| Not This | Why |
|---|---|
| VS Code on a phone | Different paradigm, different constraints, different UX |
| Android Studio | Not for Android app development in V1 |
| A Linux distribution | No full system shell, no apt, no arbitrary binary execution |
| A cloud IDE | The core must not depend on cloud infrastructure |
| An enterprise development platform | No team features, authentication, or compliance tooling in V1 |
| A universal package manager | Package management is scoped to supported runtimes |
| A compiler toolchain | No native binary compilation (C/C++) in V1 |
| A remote execution server | All execution is local in V1 |

---

## 10. Success Criteria

The project is successful at the V1 stage when:

1. A developer can open the application on an Android device with no internet connection.
2. They can create a Python project, write code, and run it locally.
3. The offline AI agent can complete the MVP loop described in Section 7.
4. The application does not crash or produce data loss under normal use.
5. The AI agent cannot access files outside the active project workspace without explicit user permission.
6. The application performs acceptably on a mid-range Android device (Tier B — defined in `01-REQUIREMENTS.md`).
7. The codebase is modular enough that a new runtime can be added without modifying the core agent or editor.

---

*This document is the starting point for all subsequent technical documentation. Detailed requirements are in `01-REQUIREMENTS.md`. System architecture is in `02-ARCHITECTURE.md`.*
