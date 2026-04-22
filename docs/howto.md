# ALS Study Companion — How-To Guide

> Quick reference for understanding and setting up this project.
> Full details: [`analysis.md`](./analysis.md) · [`setup.md`](./setup.md)

---

## What Is This App?

An **offline-first Learning Management System (LMS)** for the Philippine ALS program.

| App | Who Uses It | How to Run |
|---|---|---|
| `student_phone` | Students & Teachers | `flutter run` (Android/iOS) |
| `admin_web` | Admins only | `flutter run -d chrome` |

**Backend**: Supabase (cloud DB + auth + file storage)  
**Offline**: Works without internet — syncs automatically when back online

---

## How to Read `analysis.md`

Use it to understand **what exists in the codebase** before you touch anything.

| Section | Go there when you want to… |
|---|---|
| §2 Tech Stack | Know what versions/libraries are in use |
| §3 Architecture | Understand the folder structure and dependencies |
| §4 Packages | Learn what `shared_models`, `shared_services`, `shared_ui` do |
| §5 Apps | See every screen, ViewModel, and feature in both apps |
| §6 Database | Understand tables, triggers, RLS policies, and local SQLite |
| §7 Sync System | Know how offline → online data sync works |
| §10 Known Issues | See what's broken / still a placeholder before you start coding |

---

## How to Use `setup.md`

### If you're the **repo owner** (pushing to GitHub):

1. **Create a private GitHub repo** at [github.com/new](https://github.com/new) — check **Private**
2. In your terminal:
   ```powershell
   git remote add private https://github.com/YOUR_USERNAME/ALS-LMS.git
   git push private main
   ```
3. **Invite your friend**: GitHub repo → Settings → Collaborators → Add people
4. **Send them the `.env` keys** via private message — do NOT commit them

---

### If you're the **collaborator** (setting up on your machine):

**1. Install tools**
- Flutter SDK ≥ 3.5 · Android Studio · Node.js ≥ 18 · Git

**2. Clone the repo**
```powershell
git clone https://github.com/OWNER_USERNAME/ALS-LMS.git
cd ALS-LMS
```

**3. Create `.env` files** (ask the owner for the values)
```
ALS-LMS/apps/student_phone/.env
ALS-LMS/apps/admin_web/.env
```
Both files contain:
```env
SUPABASE_URL=<value from owner>
SUPABASE_ANON_KEY=<value from owner>
```

**4. Install Flutter dependencies** — order matters!
```powershell
cd ALS-LMS\packages\shared_models  && flutter pub get
cd ..\shared_services               && flutter pub get
cd ..\shared_ui                     && flutter pub get
cd ..\..\apps\admin_web             && flutter pub get
cd ..\student_phone                 && flutter pub get
```

**5. Install Node dependencies** (from repo root)
```powershell
cd ..\..\..\
npm install
```

**6. Run the apps**
```powershell
# Mobile app (student & teacher)
cd ALS-LMS\apps\student_phone
flutter run

# Admin web portal
cd ALS-LMS\apps\admin_web
flutter run -d chrome
```

---

## Google Sign-In Setup (Android only)

If you want Google Sign-In to work on your machine, you need to register your debug key:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copy the **SHA1** value → send it to the repo owner → they register it in Supabase/Google Cloud Console.

> Email/password login works without this step.

---

## Quick Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` path error | Run in the correct directory; packages before apps |
| `.env` not found | Check the file exists in `apps/student_phone/` and `apps/admin_web/` |
| Google Sign-In fails | Send your SHA-1 to the repo owner (see above) |
| `flutter run -d chrome` fails | Run `flutter config --enable-web` first |
| Git push asks for password | Use a GitHub Personal Access Token (PAT), not your account password |
| `flutter doctor` errors | Run `flutter doctor --android-licenses` and accept all |
