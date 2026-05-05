# ALS Study Companion — Setup Guide

> Step-by-step guide to push this project to a private GitHub repo, invite a collaborator, and get the system running on any machine.

---

## Part A — Your Machine: Push to a Private GitHub Repo

### Prerequisites (Your Machine)
Make sure you have these installed before proceeding:

| Tool | Version | Download |
|---|---|---|
| Git | Any recent version | https://git-scm.com |
| GitHub account | — | https://github.com |
| Flutter SDK | ≥ 3.5.0 | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio |
| Node.js | ≥ 18.x | https://nodejs.org |

---

### Step 1 — Create a New Private GitHub Repository

1. Go to [https://github.com/new](https://github.com/new)
2. Fill in the form:
   - **Repository name**: `ALS-LMS` (or any name you prefer)
   - **Visibility**: ✅ **Private**
   - **Initialize with README**: ❌ Leave unchecked
   - **Add .gitignore**: ❌ Leave unchecked
3. Click **"Create repository"**
4. Copy the repository URL shown — it will look like:
   ```
   https://github.com/YOUR_USERNAME/ALS-LMS.git
   ```

---

### Step 2 — Add Your New Private Repo as a Remote

Open a terminal in your project root (`emerging-tech-Als-LMS/`) and run:

```powershell
# Navigate to the project root
cd "d:\Documents\Studies\SY_2025-2026\SEM2\EmergingTech\ALS-Bondave\emerging-tech-Als-LMS"

# Add your new private repo as a remote (replace the URL with yours)
git remote add private https://github.com/YOUR_USERNAME/ALS-LMS.git

# Verify all your remotes
git remote -v
```

You should now see three remotes: `origin`, `new-origin`, and `private`.

> [!NOTE]
> You already have two remotes: `origin` (EvadNOB's original repo) and `new-origin` (Lamzeez's repo). Adding `private` keeps your new private repo separate.

---

### Step 3 — Push to Your Private Repo

```powershell
# Make sure you're on the main branch
git checkout main

# Push all commits to your private repo
git push private main

# Optional: set private as the default push remote
git push --set-upstream private main
```

If prompted, sign in with your GitHub credentials (or use a Personal Access Token).

> [!TIP]
> If GitHub asks for a password, use a **Personal Access Token (PAT)** instead of your account password.
> Go to: GitHub → Settings → Developer Settings → Personal Access Tokens → Generate new token (classic)
> Grant it: `repo` scope. Copy and use it as the password.

---

### Step 4 — Invite Your Collaborator

1. Go to your new private repo on GitHub: `https://github.com/YOUR_USERNAME/ALS-LMS`
2. Click **Settings** (top menu bar)
3. Click **Collaborators** (left sidebar under "Access")
4. Click **"Add people"**
5. Search for your friend's **GitHub username or email**
6. Click **"Add YOUR_FRIEND to this repository"**

Your friend will receive an email invitation. They must **accept it** before they can clone the repo.

---

### Step 5 — Share the Environment Variables Securely

The `.env` files are **gitignored** (never pushed to GitHub for security). You must share these with your friend via a secure channel (e.g., Messenger, Discord DM, or shared notes).

Send your friend **both** of these `.env` file contents:

**For `mobile_app` and `admin_web` (same values)**:
```env
SUPABASE_URL=https://trixvamgvaihvuqpyjwc.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyaXh2YW1ndmFpaHZ1cXB5andjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNzU3MDUsImV4cCI6MjA5MTc1MTcwNX0.FgJpB5VvimONIS11L1_LvB-G-5M4S7l8xPS2O2w4F5s
```

> [!CAUTION]
> Never commit `.env` files to Git. The `.gitignore` already blocks them, but double-check before pushing. These keys grant access to your Supabase project.

---

---

## Part B — Collaborator's Machine: Full Setup from Scratch

> These are the instructions your friend needs to follow after accepting the GitHub invitation.

---

### Step 1 — Install Prerequisites

| Tool | Version | Link |
|---|---|---|
| **Git** | Latest | https://git-scm.com/download/win |
| **Flutter SDK** | ≥ 3.5.0 | https://docs.flutter.dev/get-started/install/windows |
| **Android Studio** | Latest | https://developer.android.com/studio |
| **VS Code** (optional, recommended) | Latest | https://code.visualstudio.com |
| **Node.js** | ≥ 18.x LTS | https://nodejs.org |

#### Flutter Setup (Windows)

```powershell
# After installing Flutter, add it to PATH and verify
flutter doctor
```

Make sure `flutter doctor` shows no critical errors. Acceptable warnings:
- ✅ Flutter
- ✅ Android toolchain
- ✅ Android Studio
- ⚠️ Chrome (only needed for admin_web)
- ⚠️ VS Code (optional)

If Android toolchain shows issues, run:
```powershell
flutter doctor --android-licenses
# Accept all licenses by pressing 'y' repeatedly
```

---

### Step 2 — Clone the Repository

```powershell
# Clone your friend's private repo (they must accept invite first)
git clone https://github.com/YOUR_USERNAME/ALS-LMS.git

# Navigate into the project
cd ALS-LMS
```

If prompted for credentials, use GitHub username + Personal Access Token.

---

### Step 3 — Create the `.env` Files

The `.env` files are not included in the repo (gitignored). Create them manually using the values shared securely.

```powershell
# Create .env for mobile_app
New-Item -Path "ALS-LMS\apps\mobile_app\.env" -ItemType File -Force
```

Then open the file and paste:
```env
SUPABASE_URL=https://trixvamgvaihvuqpyjwc.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyaXh2YW1ndmFpaHZ1cXB5andjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNzU3MDUsImV4cCI6MjA5MTc1MTcwNX0.FgJpB5VvimONIS11L1_LvB-G-5M4S7l8xPS2O2w4F5s
```

```powershell
# Create .env for admin_web
New-Item -Path "ALS-LMS\apps\admin_web\.env" -ItemType File -Force
```

Same content in `admin_web/.env`.

---

### Step 4 — Install Flutter Dependencies

Run `flutter pub get` in each package and app, **in this exact order** (packages first, apps second):

```powershell
# 1. shared_core (no deps — must be first)
cd ALS-LMS\packages\shared_core
flutter pub get

# 2. backend_services (depends on shared_core)
cd ..\backend_services
flutter pub get

# 3. shared_ui
cd ..\shared_ui
flutter pub get

# 4. admin_web app
cd ..\..\apps\admin_web
flutter pub get

# 5. mobile_app app
cd ..\mobile_app
flutter pub get
```

> [!IMPORTANT]
> Order matters. `shared_core` must be resolved before `backend_services`, and both before the apps — otherwise local path dependencies won't resolve correctly.

---

### Step 5 — Install Node.js Dependencies (Supabase CLI tooling)

```powershell
# From the repo root
cd ..\..\..\
npm install
```

This installs the Supabase CLI and JS dependencies defined in `package.json`.

---

### Step 6 — Android Setup for `mobile_app`

#### 6a. Open in Android Studio

1. Open **Android Studio**
2. Click **Open** → navigate to `ALS-LMS/apps/mobile_app`
3. Let Gradle sync complete (first time may take a few minutes)

#### 6b. Set Up an Android Emulator (if no physical device)

1. In Android Studio: **Tools → Device Manager → Create Device**
2. Choose **Pixel 6** (or similar) → **API 34** (Android 14)
3. Click **Finish** and start the emulator

#### 6c. Google Sign-In — Register Your Debug SHA-1 (Required!)

Google Sign-In will fail unless your machine's debug SHA-1 fingerprint is registered in the Supabase/Google Cloud Console.

Get your SHA-1:
```powershell
# Run from anywhere (uses the default debug keystore)
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copy the **SHA1** value from the output (e.g., `AA:BB:CC:...`).

Then ask **the repo owner (your friend/Dave)** to add this SHA-1 to:
- **Supabase Dashboard** → Authentication → Providers → Google → Add SHA-1

OR add it yourself if you have access to the Google Cloud Console project:
- [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials → Your OAuth client → Add SHA-1

> [!NOTE]
> Without registering your SHA-1, Google Sign-In will throw a `PlatformException` on Android. Email/password login will still work fine.

---

### Step 7 — Run the Apps

#### Run `mobile_app` (Mobile)

```powershell
cd ALS-LMS\apps\mobile_app

# List available devices
flutter devices

# Run on connected device or emulator
flutter run

# Run on a specific device
flutter run -d emulator-5554
```

#### Run `admin_web` (Web)

```powershell
cd ALS-LMS\apps\admin_web

# Run in Chrome
flutter run -d chrome

# Or with a specific port
flutter run -d chrome --web-port 8080
```

> [!TIP]
> If Chrome isn't detected, run `flutter config --enable-web` first, then restart the terminal.

---

### Step 8 — Verify the Setup

After the apps launch, verify:

| Check | Expected Result |
|---|---|
| `mobile_app` loads | Role selection screen (Student / Teacher) appears |
| `admin_web` loads | Admin login page appears |
| Register a test student | Goes through email verification flow |
| Admin login | Dashboard shows metrics (may be 0 on fresh setup) |
| Lesson sync | Lessons appear after first sync with Supabase |

---

---

## Part C — Ongoing Collaboration Workflow

### Pulling Latest Changes

```powershell
# From repo root
git pull origin main

# Or pull from the private repo
git pull private main
```

### Pushing New Work

```powershell
git add .
git commit -m "feat: your descriptive commit message"
git push private main
```

### Branch-Based Workflow (Recommended)

```powershell
# Create a feature branch
git checkout -b feature/your-feature-name

# Work, commit...
git push private feature/your-feature-name

# Open a Pull Request on GitHub to merge into main
```

---

## Part D — Supabase Dashboard Access (Optional)

If your collaborator needs direct database/admin access to Supabase:

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Your project: `trixvamgvaihvuqpyjwc`
3. Ask the **Supabase project owner** to invite them:
   - Supabase Dashboard → Project Settings → Team → Invite Member
   - Enter their email and assign role (Developer or Admin)

> [!NOTE]
> Supabase project access is separate from GitHub access. Your friend can run the app without Supabase dashboard access — they only need it if they want to view/edit the database directly, manage migrations, or configure storage.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` fails with path error | Make sure you're running it from the correct directory; packages must be resolved before apps |
| `pubspec.lock` conflicts | Delete `pubspec.lock` in the problematic package and re-run `flutter pub get` |
| `SUPABASE_URL not found` | Double-check `.env` file exists in the correct app directory and has no typos |
| Google Sign-In fails on Android | Register your debug SHA-1 in Google Cloud Console (Step 6c) |
| `flutter doctor` shows Android SDK missing | Open Android Studio → SDK Manager → Install Android SDK |
| `flutter run -d chrome` not working | Run `flutter config --enable-web` and restart terminal |
| Build fails with `null safety` errors | Ensure Flutter SDK is ≥ 3.5.0 (`flutter --version`) |
| Git push requires password | Use a GitHub Personal Access Token (PAT) as your password |
| Emulator too slow | Enable hardware acceleration (HAXM on Intel, Hyper-V on AMD) in BIOS/Android Studio |
