# Storage Locations & File Access Guide

## 📱 Where Files Are Stored on Your Phone

### 1. App Private Storage (Main Storage)

**Base Directory:**
```
/data/data/com.offlinemobileide.aioide/
```

**Full Structure:**
```
/data/data/com.offlinemobileide.aioide/
├── files/                              # Main app files
│   ├── projects/                       # User projects
│   │   ├── projects.json               # Project metadata
│   │   └── [project-id]/               # Each project folder
│   │       ├── main.py
│   │       ├── hello.py
│   │       └── ...
│   │
│   ├── models/                         # AI models (GGUF files)
│   │   ├── gemma-2-2b-it-Q4_K_M.gguf  (~1.5GB)
│   │   ├── gemma-2-2b-it-Q8_0.gguf    (~2.4GB)
│   │   └── gemma-2-2b-it-Q2_K.gguf    (~860MB)
│   │
│   └── python/                         # Python runtime (future)
│       ├── bin/
│       │   └── python3
│       └── lib/
│
├── cache/                              # Temporary files
│   └── [temp downloads]
│
└── shared_prefs/                       # App settings
    └── settings.xml
```

---

## 🐍 Python Detection Issue

### Why Termux Python Isn't Detected

The app is currently checking:
```dart
// 1. App's private storage
/data/data/com.offlinemobileide.aioide/files/python/bin/python3

// 2. Termux installation
/data/data/com.termux/files/usr/bin/python3  ← Should work!

// 3. System PATH
python3 or python
```

### Problem: Permission Issues

**Issue:** Android apps run in sandboxed environments. Your app (package `com.offlinemobileide.aioide`) **cannot directly access** Termux's files (package `com.termux`) due to Android's security model.

**Termux files are at:**
```
/data/data/com.termux/files/usr/bin/python3
```

**Your app sees:**
```
Permission denied ❌
```

---

## ✅ Solutions to Fix Python Detection

### Solution 1: Use Termux-API (Recommended for Hackathon)

**Install Termux-API:**
```bash
# In Termux
pkg install termux-api python

# Grant permissions in Android Settings:
# Settings → Apps → Termux → Permissions → Enable all
```

**Run Python via Termux-API:**
```bash
# From your app, execute:
termux-api python3 /path/to/script.py
```

### Solution 2: Create Python Wrapper in Accessible Location

**Steps:**

1. **In Termux, create a wrapper script:**
```bash
# In Termux
mkdir -p /sdcard/mylonite/bin
cat > /sdcard/mylonite/bin/python3 << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
/data/data/com.termux/files/usr/bin/python3 "$@"
EOF
chmod +x /sdcard/mylonite/bin/python3
```

2. **Update Python Installer to check this location:**

Add to `python_installer.dart`:
```dart
// Check /sdcard/mylonite/bin/python3 (accessible location)
const sdcardPython = '/sdcard/mylonite/bin/python3';
if (await _testPythonExecutable(sdcardPython)) {
  return PythonInstallationInfo(
    available: true,
    executable: sdcardPython,
    version: await _getPythonVersion(sdcardPython),
    source: PythonSource.system,
  );
}
```

### Solution 3: Execute via `sh` Command (Quick Fix)

Instead of calling Python directly, wrap it in a shell command:

**Update `python_runtime.dart`:**
```dart
// Instead of:
argv: [_pythonExecutable, filePath, ...arguments],

// Use:
argv: ['sh', '-c', '$_pythonExecutable $filePath'],
```

This works because `sh` is in the system PATH and can find Termux's Python.

---

## 🛠️ Quick Fix Implementation

Let me update the Python detection code to work with Termux:

### File to Modify: `lib/core/services/runtime/python_installer.dart`

**Add this check FIRST (before checking `/data/data/com.termux/`):**

```dart
// Check if python3 is in PATH (works with Termux)
final result = await Process.run('which', ['python3']);
if (result.exitCode == 0) {
  final pythonPath = result.stdout.toString().trim();
  if (pythonPath.isNotEmpty) {
    return PythonInstallationInfo(
      available: true,
      executable: 'python3', // Use name, not path
      version: await _getPythonVersion('python3'),
      source: PythonSource.system,
    );
  }
}
```

---

## 📦 Where to Store GGUF Models

### Option 1: Download via App (Automatic)

The app will automatically download to:
```
/data/data/com.offlinemobileide.aioide/files/models/gemma-2-2b-it-Q4_K_M.gguf
```

**How:**
1. Open **Model Manager** tab
2. Click **Download** on Gemma 2 2B Q4_K_M
3. Wait for download (~1.5GB)
4. Done!

### Option 2: Manual Transfer via ADB

**Steps:**

1. **Download GGUF to your PC:**
```bash
wget https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
```

2. **Push to phone (temporary location):**
```bash
adb push gemma-2-2b-it-Q4_K_M.gguf /sdcard/Download/
```

3. **Move to app storage (requires root or app code):**

Since `/data/data/` is protected, you need to either:
- Use the app's import feature (not yet implemented)
- Use `adb run-as` if device is debuggable:

```bash
adb shell run-as com.offlinemobileide.aioide sh -c '
  mkdir -p /data/data/com.offlinemobileide.aioide/files/models
  cp /sdcard/Download/gemma-2-2b-it-Q4_K_M.gguf /data/data/com.offlinemobileide.aioide/files/models/
'
```

### Option 3: Import from Downloads (Best UX)

**Implementation needed:** Add "Import Model" button that uses SAF to let users select GGUF file from Downloads folder.

---

## 🔧 Immediate Fix for Python Detection

Let me create an updated version of the Python installer that will work with Termux:

### Updated Code:

```dart
// In python_installer.dart, replace detect() method:

Future<PythonInstallationInfo> detect() async {
  log.info(LogSubsystem.runtime, 'Detecting Python installation...');

  // Method 1: Check if python3 is in PATH (works with Termux)
  try {
    final result = await Process.run('sh', ['-c', 'which python3']);
    if (result.exitCode == 0) {
      final pythonPath = result.stdout.toString().trim();
      if (pythonPath.isNotEmpty) {
        log.info(LogSubsystem.runtime, 'Found Python in PATH: $pythonPath');
        return PythonInstallationInfo(
          available: true,
          executable: 'python3', // Use command name
          version: await _getPythonVersion('python3'),
          source: PythonSource.system,
        );
      }
    }
  } catch (e) {
    log.debug(LogSubsystem.runtime, 'PATH check failed: $e');
  }

  // Method 2: Try executing python3 directly
  try {
    final result = await Process.run('python3', ['--version']);
    if (result.exitCode == 0) {
      log.info(LogSubsystem.runtime, 'Python3 command works directly');
      return PythonInstallationInfo(
        available: true,
        executable: 'python3',
        version: result.stdout.toString().trim(),
        source: PythonSource.system,
      );
    }
  } catch (e) {
    log.debug(LogSubsystem.runtime, 'Direct python3 failed: $e');
  }

  // Method 3: Check common Termux locations (may fail due to permissions)
  final termuxLocations = [
    '/data/data/com.termux/files/usr/bin/python3',
    '/data/data/com.termux/files/usr/bin/python',
  ];

  for (final location in termuxLocations) {
    try {
      final result = await Process.run(location, ['--version']);
      if (result.exitCode == 0) {
        log.info(LogSubsystem.runtime, 'Found Termux Python: $location');
        return PythonInstallationInfo(
          available: true,
          executable: location,
          version: result.stdout.toString().trim(),
          source: PythonSource.termux,
        );
      }
    } catch (e) {
      // Expected - permission denied
    }
  }

  log.warn(LogSubsystem.runtime, 'No Python installation detected');
  return PythonInstallationInfo(
    available: false,
    executable: null,
    version: null,
    source: null,
  );
}
```

---

## 🧪 How to Test Python Detection

### Test 1: Check if Termux Python is in PATH

**Run in Termux:**
```bash
which python3
# Should output: /data/data/com.termux/files/usr/bin/python3

python3 --version
# Should output: Python 3.12.x
```

### Test 2: Test from Android shell

**Run via ADB:**
```bash
adb shell python3 --version
```

**Expected:**
- ✅ If works: Python is in PATH
- ❌ If fails: Permission issue

### Test 3: Test Process.run in Dart

**Add to Python health check:**
```dart
log.info(LogSubsystem.runtime, 'Testing: which python3');
final whichResult = await Process.run('which', ['python3']);
log.info(LogSubsystem.runtime, 'which result: ${whichResult.stdout}');

log.info(LogSubsystem.runtime, 'Testing: python3 --version');
final versionResult = await Process.run('python3', ['--version']);
log.info(LogSubsystem.runtime, 'version result: ${versionResult.stdout}');
```

---

## 📍 How to Access Files from Device

### Method 1: ADB Shell

```bash
# List app files
adb shell "ls -la /data/data/com.offlinemobileide.aioide/files/"

# View project files
adb shell "ls -la /data/data/com.offlinemobileide.aioide/files/projects/"

# Check if models directory exists
adb shell "ls -la /data/data/com.offlinemobileide.aioide/files/models/"

# Read a Python file
adb shell "cat /data/data/com.offlinemobileide.aioide/files/projects/[project-id]/main.py"
```

### Method 2: ADB Pull (Copy to PC)

```bash
# Pull entire projects folder
adb pull /data/data/com.offlinemobileide.aioide/files/projects/ ./mylonite_projects/

# Pull a specific model
adb pull /data/data/com.offlinemobileide.aioide/files/models/gemma-2-2b-it-Q4_K_M.gguf ./
```

### Method 3: Root (If Available)

```bash
adb shell su -c "ls -la /data/data/com.offlinemobileide.aioide/"
```

---

## 🔍 Debugging Python Issues

### Check App Logs

**View real-time logs:**
```bash
adb logcat | grep -i python
```

**Look for:**
- `Python detection...`
- `Found Python in PATH`
- `Python runtime OK`
- `Python health check failed`

### Common Errors and Fixes

#### Error: "python3: not found"
**Cause:** Termux Python not in PATH  
**Fix:** Restart app after installing Python in Termux

#### Error: "Permission denied"
**Cause:** Trying to access `/data/data/com.termux/` directly  
**Fix:** Use `python3` command name instead of full path

#### Error: "No Python installation detected"
**Cause:** Termux not installed or Python not installed in Termux  
**Fix:** 
```bash
pkg update
pkg install python
```

---

## 💡 Recommended Setup (Step by Step)

### For Python:

1. **Install Termux from F-Droid** (NOT Google Play)
2. **In Termux:**
   ```bash
   pkg update
   pkg upgrade
   pkg install python
   python3 --version  # Verify
   ```
3. **Restart Mylonite IDE**
4. **Check Terminal tab** - Should show Python version

### For GGUF Models:

1. **Option A (In-App Download):**
   - Open Model Manager
   - Download Gemma 2 2B Q4_K_M
   - Wait for completion
   - Click "Load Model"

2. **Option B (Manual Transfer):**
   - Download GGUF to PC
   - Push to `/sdcard/Download/`
   - Use future "Import Model" feature

---

## 📋 Summary

### Storage Locations:
- **Projects:** `/data/data/com.offlinemobileide.aioide/files/projects/`
- **Models:** `/data/data/com.offlinemobileide.aioide/files/models/`
- **Python:** Use `python3` from PATH (Termux)

### Python Fix:
- Use `python3` command (not full path)
- Termux must be installed from F-Droid
- Restart app after installing Python

### Model Storage:
- Download via app → Auto-stored in correct location
- Manual transfer → Push to `/sdcard/`, then import

### Access Files:
- `adb shell ls` - List files
- `adb pull` - Copy to PC
- `adb logcat` - View logs

---

**Need more help?** Check the logs with:
```bash
adb logcat | grep -E "(Python|Mylonite|AIOIDE)"
```

This will show exactly what the app is trying and where it fails!
