# Python Installation Guide for Mylonite IDE

## Problem

Stock Android devices don't include Python by default. Mylonite IDE needs Python to execute code locally on the device.

## Solution: Install Termux

**Termux** is a terminal emulator that provides a Linux environment with Python and development tools.

### Step-by-Step Installation

#### 1. Download Termux from F-Droid

⚠️ **IMPORTANT:** You MUST use the F-Droid version, NOT the Google Play version (which is outdated and broken).

**Download Link:** https://f-droid.org/en/packages/com.termux/

Or visit: https://f-droid.org/ and search for "Termux"

#### 2. Install Termux

- Open the downloaded APK
- Grant installation permissions if needed
- Wait for installation to complete

#### 3. Open Termux and Install Python

Once Termux is open, run these commands:

```bash
# Update package lists
pkg update

# Install Python
pkg install python

# Verify installation
python3 --version
```

You should see something like: `Python 3.12.4`

#### 4. Restart Mylonite IDE

- Close Mylonite IDE completely
- Reopen the app
- Python should now be detected automatically

### Verification

To verify Python is detected:

1. Open Mylonite IDE
2. Go to **Terminal** tab
3. You should see "Python 3.12.x" chip in the AppBar
4. No "Python runtime not available" message

Or check logs:

1. Go to **Settings** → **Runtime Manager**
2. Python should show as "Installed"

### What Gets Installed

Termux installation includes:

- **Python 3.12+** (latest stable)
- **pip** (Python package manager)
- **Full stdlib** (all standard library modules)
- **Development tools** (gcc, clang, make, etc.)
- **~180MB** total storage (Python ~75MB + Termux ~105MB)

### Optional: Install Additional Packages

Once Python is working, you can install packages via pip:

```bash
# In Termux
pip install requests numpy pandas matplotlib
```

Note: Some packages with C extensions may not work on Android ARM.

## Alternative: Wait for Bundled Python (Coming Soon)

We're working on bundling Python directly with Mylonite IDE so you won't need Termux.

This will:
- ✅ Work out of the box (no manual setup)
- ✅ Be optimized for Android
- ✅ Include commonly-used packages
- ⏸️ Take ~2-3 weeks to implement

For the hackathon, **Termux is the recommended approach**.

## Troubleshooting

### "Python not found" after installing Termux

**Solution:** Restart Mylonite IDE. The app only checks for Python on startup.

### "Permission denied" errors in Termux

**Solution:** Termux stores files in `/data/data/com.termux/files/`. Make sure you're running commands inside Termux first.

### Termux won't install from Google Play

**Solution:** Google Play version is outdated. You MUST use F-Droid version.

### F-Droid won't install

**Solution:**
1. Enable "Install from Unknown Sources" in Android settings
2. Allow F-Droid app installation permission
3. Try downloading Termux directly: https://f-droid.org/repo/com.termux_118.apk

### Python detected but code won't run

**Solution:** Check Terminal screen for error messages. The ProcessChannel infrastructure is working (tested in Phase 4), so any execution issues are likely Python environment problems.

### Want to uninstall Termux

**Solution:** Uninstall Termux app like any other app. Mylonite IDE will continue to work, just without Python execution.

## Technical Details

### How Mylonite Detects Python

The app checks these locations in order:

1. **App's private storage** (`/data/data/com.offlinemobileide.aioide/files/python/`) - For future bundled Python
2. **Termux installation** (`/data/data/com.termux/files/usr/bin/python3`)
3. **System PATH** (`python3`, `python`) - For devices with system Python

Once detected, the executable path is cached for the session.

### Why Termux?

Alternatives considered:

| Option | Pros | Cons | Decision |
|---|---|---|---|
| **Termux** | ✅ Already compiled<br>✅ Full Python<br>✅ pip support<br>✅ ~180MB | ⚠️ Requires manual install | ✅ **Best for hackathon** |
| **Bundled Python** | ✅ No setup<br>✅ Optimized | ⚠️ ~75MB APK increase<br>⚠️ 2-3 weeks work | ⏸️ Future update |
| **Chaquopy** | ✅ Android-native | ❌ Commercial license<br>❌ Paid for commercial use | ❌ Rejected |
| **Python-for-Android** | ✅ Open source | ❌ Complex build<br>❌ Large binaries | ❌ Too complex |

### Security Considerations

- Termux runs in its own sandbox (`/data/data/com.termux/`)
- Mylonite IDE spawns Python processes with `ProcessBuilder`
- Processes run with app's UID (isolated from other apps)
- File access restricted to workspace directory
- No network access from Python code (unless explicitly granted)

### Performance

With Termux Python:
- **Startup time:** ~100-200ms (Python interpreter load)
- **Hello World:** ~150-300ms total (including process spawn)
- **Memory:** ~20-40MB per Python process
- **Battery:** Proportional to CPU usage (minimal for most scripts)

## For Developers

### Testing Without Device

If you don't have an Android device:

1. Use Android Emulator (Android Studio)
2. Install Termux in emulator
3. Follow same steps as physical device

### Simulating Python for UI Testing

To test the UI without Python:

```dart
// In python_installer.dart
Future<PythonInstallationInfo> detect() async {
  // Simulate Python detected for testing
  return PythonInstallationInfo(
    available: true,
    executable: '/fake/python3',
    version: 'Python 3.12.4 (simulated)',
    source: PythonSource.system,
  );
}
```

### Bundling Python (Future Implementation)

Steps to bundle Python in the app:

1. Download Python ARM64 standalone build:
   - https://github.com/indygreg/python-build-standalone/releases
   - Choose: `cpython-3.12.X-aarch64-unknown-linux-android.tar.gz`

2. Extract and package:
   ```bash
   tar -xzf cpython-*.tar.gz
   cp -r python/install/* android/app/src/main/assets/python/
   ```

3. Update build.gradle to extract on first run:
   ```kotlin
   // Copy assets/python to app files dir
   ```

4. Update PythonInstaller to use bundled path:
   ```dart
   final appPythonPath = '/data/data/com.offlinemobileide.aioide/files/python/bin/python3';
   ```

Total effort: ~4-6 hours (for experienced dev)

## Summary

**For Hackathon Demo:**
- ✅ Install Termux from F-Droid
- ✅ Run `pkg install python` in Termux
- ✅ Restart Mylonite IDE
- ✅ Python execution works!

**For Production Release:**
- Bundle Python with app
- No user setup required
- Automatic extraction on first run

---

**Created:** 2026-08-30  
**Last Updated:** 2026-08-30  
**Version:** 1.0 (Phase 5 - Python Runtime Integration)
