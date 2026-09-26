# Quick Setup Guide - Mylonite IDE

## 🚀 Quick Start (3 Steps)

### Step 1: Install Python Runtime (5 minutes)

1. **Download Termux from F-Droid** (NOT Google Play!)
   - Link: https://f-droid.org/en/packages/com.termux/
   - Or search "Termux" in F-Droid app

2. **Open Termux and run:**
   ```bash
   pkg update
   pkg install python
   ```

3. **Verify installation:**
   ```bash
   python3 --version
   # Should show: Python 3.12.x
   ```

4. **Restart Mylonite IDE**
   - Python should now be detected automatically!

### Step 2: Optional - Download AI Model (If you want AI code generation)

1. **Open Mylonite IDE → Model Manager tab**
2. **Click "Download" on Gemma 2 2B Q4_K_M**
3. **Wait for download (~1.5GB, takes 2-5 minutes on fast connection)**
4. **Click "Load Model"**
5. **Done! AI agent is ready**

### Step 3: Start Coding!

1. **Go to Projects tab**
2. **Create new Python project**
3. **Write code in Editor**
4. **Press Run button**
5. **See output in Terminal**

---

## 📍 Where Everything Is Stored

### On Your Phone:

```
/data/data/com.offlinemobileide.aioide/files/
├── projects/          # Your code projects
├── models/            # AI models (GGUF files)
└── python/            # Bundled Python (future)
```

### Access via ADB:

```bash
# List files
adb shell "ls /data/data/com.offlinemobileide.aioide/files/"

# Pull a project
adb pull /data/data/com.offlinemobileide.aioide/files/projects/[project-id]/ ./

# View logs
adb logcat | grep -i mylonite
```

---

## 🐍 Python Detection (How It Works)

The app checks in this order:

1. ✅ **`which python3`** ← Works with Termux!
2. ✅ **`python3 --version`** ← Direct execution
3. **App private storage** ← For bundled Python
4. **Termux paths** ← Direct paths (may fail)

**If Python not detected:**
1. Make sure Termux is from F-Droid (not Google Play)
2. Run `pkg install python` in Termux
3. Restart Mylonite IDE
4. Check Terminal tab for Python version chip

---

## 🤖 AI Model Setup (Optional)

### Where to Get GGUF Models:

**Recommended:** Gemma 2 2B Q4_K_M (~1.5GB)

**Download Link:**
```
https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
```

### Option 1: Download via App (Easiest)

1. Model Manager tab → Click "Download"
2. Confirm download
3. Wait for completion
4. Click "Load Model"

### Option 2: Manual Transfer (For Testing)

1. **Download GGUF to PC:**
   ```bash
   wget https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
   ```

2. **Push to phone:**
   ```bash
   adb push gemma-2-2b-it-Q4_K_M.gguf /sdcard/Download/
   ```

3. **Move to app storage (requires run-as):**
   ```bash
   adb shell run-as com.offlinemobileide.aioide sh -c '
     mkdir -p /data/data/com.offlinemobileide.aioide/files/models
     cp /sdcard/Download/gemma-2-2b-it-Q4_K_M.gguf /data/data/com.offlinemobileide.aioide/files/models/
   '
   ```

4. **Refresh Model Manager in app**

### Where Models Are Stored:

```
/data/data/com.offlinemobileide.aioide/files/models/
└── gemma-2-2b-it-Q4_K_M.gguf  (1.5GB)
```

---

## 🔍 Troubleshooting

### Python Not Detected

**Symptom:** Terminal shows "Python runtime not available"

**Fix:**
```bash
# 1. Check Termux has Python
termux:~$ python3 --version

# 2. Make sure python3 is in PATH
termux:~$ which python3
# Should output: /data/data/com.termux/files/usr/bin/python3

# 3. Restart Mylonite IDE

# 4. Check logs
adb logcat | grep -i python
```

### Model Won't Download

**Symptom:** Download starts but fails or is very slow

**Fix:**
- Check internet connection
- Free up storage space (need ~1.5GB free)
- Try downloading to PC and manual transfer
- Check logs: `adb logcat | grep -i download`

### App Crashes

**Symptom:** App closes unexpectedly

**Fix:**
```bash
# Check crash logs
adb logcat | grep -E "(AndroidRuntime|FATAL)"

# Clear app data (WARNING: deletes projects!)
adb shell pm clear com.offlinemobileide.aioide
```

### Code Won't Execute

**Symptom:** Run button pressed but nothing happens

**Fix:**
- Make sure Python is detected (check Terminal tab)
- Save file first before running
- Check Terminal tab for error messages
- View logs: `adb logcat | grep -i execute`

---

## 📊 System Requirements

### Minimum:

- Android 8.0+ (API 26)
- 3GB RAM
- 2GB free storage
- ARM64 processor

### Recommended:

- Android 10+
- 4GB+ RAM
- 3GB free storage
- Good internet for model download

---

## 💾 Storage Usage

| Component | Size |
|---|---|
| App | ~50MB |
| Termux | ~100MB |
| Termux Python | ~75MB |
| Gemma 2 2B Q4_K_M | ~1.5GB |
| Your projects | Varies |
| **Total** | **~1.7GB** |

---

## 🎯 What Works Right Now

✅ **File Management:**
- Create/edit/delete Python files
- Multi-file projects
- File explorer
- Syntax highlighting
- Undo/redo

✅ **Code Execution:**
- Run Python files
- See real-time output
- View errors and tracebacks
- Execution timing

✅ **AI Code Generation:**
- Download AI models
- Generate Python code from natural language
- Streaming responses
- Chat interface

✅ **Terminal:**
- Real-time stdout/stderr
- Exit codes
- Timeout detection
- Clear output

---

## 🚧 What's Coming (Phase 11)

⏸️ **Autonomous Agent Loop:**
- Auto-fix errors
- Multi-step tasks
- Self-correction
- Validation

⏸️ **Advanced Features:**
- Bundled Python (no Termux needed)
- More AI models
- JavaScript runtime
- Package manager

---

## 📞 Getting Help

### View Logs:

```bash
# All logs
adb logcat

# Python only
adb logcat | grep -i python

# Errors only
adb logcat *:E

# App specific
adb logcat | grep -E "(Mylonite|AIOIDE)"
```

### Check Storage:

```bash
# How much space used
adb shell du -sh /data/data/com.offlinemobileide.aioide/

# List projects
adb shell "ls -lh /data/data/com.offlinemobileide.aioide/files/projects/"

# List models
adb shell "ls -lh /data/data/com.offlinemobileide.aioide/files/models/"
```

### Debug Python:

```bash
# Test Python from shell
adb shell python3 --version

# Test from Termux
adb shell am start -n com.termux/.app.TermuxActivity
# Then in Termux: python3 --version
```

---

## ✨ Pro Tips

1. **Save often** - No auto-save yet
2. **Use Termux F-Droid version** - Google Play version is broken
3. **Download models on WiFi** - 1.5GB is a lot!
4. **Check Terminal for errors** - Detailed error messages there
5. **Copy code from AI chat** - Long-press to select

---

## 🎉 You're Ready!

Now you can:
- ✅ Write Python code
- ✅ Execute it locally
- ✅ Use AI to generate code
- ✅ Build real projects

**Have fun coding! 🚀**
