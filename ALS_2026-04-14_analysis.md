# ALS Study Companion — Project Analysis

**Analysis Date:** April 14, 2026  
**Repository:** emerging-tech-Als-LMS  
**Branch:** main (HEAD: a419a95)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Architecture](#2-project-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Monorepo Structure](#4-monorepo-structure)
5. [Database Schema](#5-database-schema)
6. [Key Features](#6-key-features)
7. [User Roles](#7-user-roles)
8. [Setup Instructions](#8-setup-instructions)
9. [Running the Applications](#9-running-the-applications)
10. [Known Issues & TODOs](#10-known-issues--todos)
11. [Recommendations for Improvement](#11-recommendations-for-improvement)
12. [Next Steps](#12-next-steps)

---

## 1. Executive Summary

The **ALS Study Companion** is an offline-first Learning Management System (LMS) built for the Philippine Alternative Learning System (ALS) program. It's a multi-platform application consisting of:

- **Admin Web Portal** (Flutter Web) — For system administrators to manage users, courses, centers, and monitor system health
- **Student Mobile App** (Flutter Mobile) — For students to access lessons, take quizzes, and track progress offline

The backend is powered by **Supabase** (PostgreSQL + Auth + Storage), providing real-time data synchronization, authentication, and file storage.

**Key Design Principle:** Offline-first architecture — all critical data is cached locally in SQLite, enabling full functionality without internet connectivity.

---

## 2. Project Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend Layer                            │
├──────────────────────────┬──────────────────────────────────────┤
│   Admin Web (Flutter)    │   Student Phone App (Flutter)        │
│   - User Management      │   - Lesson Viewing                   │
│   - Course Management    │   - Quiz Taking                      │
│   - System Controls      │   - Progress Tracking                │
│   - Analytics Dashboard  │   - Offline Downloads                │
│   - Media Library        │   - Biometric Auth                   │
└───────────┬──────────────┴──────────────┬───────────────────────┘
            │                             │
            │         Shared Packages     │
            ├─────────────────────────────┤
            │  • shared_models            │
            │  • shared_services          │
            │  • shared_ui                │
            └─────────────┬───────────────┘
                          │
┌─────────────────────────┼───────────────────────────────────────┐
│                    Backend Layer                                 │
├─────────────────────────┼───────────────────────────────────────┤
│                    Supabase Platform                            │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │ PostgreSQL   │  │ Supabase     │  │ Supabase Storage    │   │
│  │ (Database)   │  │ Auth         │  │ (Videos, PDFs,      │   │
│  │              │  │ (Email/      │  │  Images)            │   │
│  │              │  │  Google)     │  │                     │   │
│  └──────────────┘  └──────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Dependency Flow

```
shared_models (pure Dart, no Flutter deps)
      ▲
      │
shared_services (depends on shared_models + supabase_flutter)
      ▲
      │
shared_ui (depends on shared_models + google_fonts)
      ▲
      ├──────────────┐
admin_web         student_phone
```

---

## 3. Technology Stack

### Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | stable (SDK 3.5.0+) | Cross-platform UI framework |
| **Dart** | ^3.5.0 | Programming language |
| **flutter_bloc** | ^8.1.6 | State management (BLoC pattern) |
| **equatable** | ^2.0.7 | Value equality for models |

### Backend & Services

| Technology | Version | Purpose |
|------------|---------|---------|
| **Supabase** | Hosted | Backend-as-a-Service |
| **supabase_flutter** | ^2.8.0 | Supabase client for Flutter |
| **PostgreSQL** | 15 | Primary database (via Supabase) |
| **Supabase Auth** | — | Email/Password + Google OAuth |
| **Supabase Storage** | — | File storage for lessons/media |

### Offline Storage (Mobile App)

| Technology | Version | Purpose |
|------------|---------|---------|
| **sqflite** | ^2.4.1 | Local SQLite database |
| **shared_preferences** | ^2.3.2 | Simple key-value storage |
| **flutter_secure_storage** | ^9.2.3 | Secure credential storage |

### Networking & Connectivity

| Technology | Version | Purpose |
|------------|---------|---------|
| **connectivity_plus** | ^6.1.1 | Network connectivity monitoring |
| **http** | ^1.2.2 | HTTP client for API calls |

### UI Components

| Technology | Version | Purpose |
|------------|---------|---------|
| **google_fonts** | ^6.2.1+ | Typography |
| **flutter_svg** | ^2.0.16+ | SVG rendering |
| **cached_network_image** | ^3.4.1 | Image caching |
| **shimmer** | ^3.0.0 | Loading skeleton animations |
| **percent_indicator** | ^4.2.3 | Progress indicators |
| **file_picker** | ^8.1.3 | File selection dialogs |
| **image_picker** | ^1.1.2 | Camera/gallery access |
| **mobile_scanner** | ^5.2.3 | QR/barcode scanning |

### Authentication & Security

| Technology | Version | Purpose |
|------------|---------|---------|
| **google_sign_in** | ^6.2.2 | Google OAuth sign-in |
| **local_auth** | ^2.3.0 | Biometric authentication (fingerprint/Face ID) |
| **flutter_secure_storage** | ^9.2.3 | Encrypted local storage |

### Development Tools

| Technology | Version | Purpose |
|------------|---------|---------|
| **build_runner** | ^2.4.13 | Code generation |
| **json_serializable** | ^6.8.0 | JSON serialization code gen |
| **json_annotation** | ^4.9.0 | JSON annotation support |
| **uuid** | ^4.5.1 | Unique ID generation |
| **intl** | ^0.19.0 | Internationalization & date formatting |
| **path_provider** | ^2.1.5 | Platform-specific path access |
| **path** | ^1.9.1 | Path manipulation utilities |

---

## 4. Monorepo Structure

```
emerging-tech-Als-LMS/
│
├── ALS-LMS/                              ← Flutter monorepo root
│   ├── apps/
│   │   ├── admin_web/                    ← Admin web portal (Flutter Web)
│   │   │   ├── lib/
│   │   │   │   └── main.dart             ← App entry point
│   │   │   ├── assets/                   ← Images, icons
│   │   │   ├── android/                  ← Android build config
│   │   │   ├── ios/                      ← iOS build config
│   │   │   ├── web/                      ← Web build config
│   │   │   ├── macos/                    ← macOS build config
│   │   │   ├── test/                     ← Unit/widget tests
│   │   │   ├── pubspec.yaml              ← Dependencies
│   │   │   └── analysis_options.yaml     ← Linting rules
│   │   │
│   │   └── student_phone/                ← Student mobile app
│   │       ├── lib/
│   │       │   ├── main.dart             ← App entry point
│   │       │   ├── app/                  ← App configuration, BLoC observer
│   │       │   └── features/             ← Feature-based architecture
│   │       │       ├── auth/             ← Authentication flows
│   │       │       ├── splash/           ← Splash/loading screens
│   │       │       ├── dashboard/        ← Student dashboard
│   │       │       ├── courses/          ← Lesson/course browsing
│   │       │       ├── enrollment/       ← Course enrollment
│   │       │       ├── announcements/    ← Announcements system
│   │       │       ├── teacher/          ← Teacher-facing features
│   │       │       └── maintenance/      ← System maintenance mode
│   │       ├── assets/                   ← Images, icons, animations
│   │       ├── android/                  ← Android build config
│   │       ├── ios/                      ← iOS build config
│   │       ├── test/                     ← Unit/widget tests
│   │       ├── pubspec.yaml              ← Dependencies
│   │       └── analysis_options.yaml     ← Linting rules
│   │
│   └── packages/
│       ├── shared_models/                ← Data models (pure Dart)
│       │   ├── lib/
│       │   └── pubspec.yaml
│       │
│       ├── shared_services/              ← Service layer (Supabase, Auth, Sync)
│       │   ├── lib/
│       │   └── pubspec.yaml
│       │
│       └── shared_ui/                    ← Shared UI components & theme
│           ├── lib/
│           └── pubspec.yaml
│
├── supabase/
│   ├── config.toml                       ← Supabase CLI configuration
│   └── migrations/                       ← Database migrations
│       ├── 20260309_comprehensive_schema.sql
│       ├── 20260310_missing_tables.sql
│       ├── 20260311_fix_schema_and_policies.sql
│       ├── 20260311_fix_schema_issues.sql
│       ├── 20260321_fix_profile_storage_policies.sql
│       └── archived/                     ← Archived migrations
│           ├── 20260306_grants.sql
│           └── 20260307_grants.sql
│
├── docs/
│   ├── SETUP.md                          ← Developer setup guide
│   ├── DEPENDENCIES.md                   ← Dependency audit
│   ├── MIGRATIONS.md                     ← Migration guidance
│   └── NATIVE_AUDIT.md                   ← Native code audit
│
├── scripts/
│   ├── lock-deps.ps1                     ← PowerShell dependency locking
│   └── release.sh                        ← Release automation
│
├── .github/
│   └── workflows/
│       └── flutter-ci.yml                ← CI/CD pipeline
│
├── package.json                          ← Root Node.js dependencies
├── .gitignore                            ← Git ignore rules
├── README.md                             ← Main project documentation
└── CONTRIBUTING.md                       ← Contribution guidelines
```

---

## 5. Database Schema

### Supabase PostgreSQL Tables

Based on the migrations and code analysis, the database includes:

| Table | Purpose |
|-------|---------|
| **profiles** | User profiles (students, teachers, admins) with role, email, full_name, is_active |
| **districts** | Geographic districts for organizing schools |
| **learning_centers** | ALS learning center locations |
| **courses** | Course/lesson content |
| **course_enrollments** | Student enrollments in courses |
| **lesson_media** | Media files associated with lessons |
| **activity_logs** | System audit logs for tracking admin actions |
| **system_settings** | Global configuration (kill switch, maintenance mode, etc.) |
| **quizzes** | Quiz definitions linked to lessons |
| **questions** | Quiz questions with options and correct answers |
| **progress** | Student progress tracking per lesson/quiz |
| **announcements** | System announcements |
| **sessions** | Scheduled teaching sessions |
| **downloads** | Offline download tracking |

### Local SQLite (Mobile App)

The mobile app uses sqflite for offline storage with tables mirroring the Supabase schema:
- lessons
- quizzes
- questions
- progress
- downloads
- sync_queue (pending offline operations)

---

## 6. Key Features

### 6.1 Admin Web Portal

#### Dev Admin View
- **Global Overview**: Total users, students, teachers, courses, centers, enrollments
- **User Management**: CRUD operations on users, role editing, activate/deactivate
- **System Controls**: Kill switch (emergency lockdown), maintenance mode toggle
- **Activity Logs**: Audit trail of all system actions
- **Media Library**: View/manage lesson media files
- **Database Browser**: Direct database inspection
- **System Settings**: Configure global settings

#### School Admin View
- **District Management**: View/manage geographic districts
- **Learning Centers**: CRUD operations on centers
- **User Management**: Local user management
- **Course Management**: Create/edit courses
- **Teacher Approvals**: Approve/reject teacher registrations
- **Analytics**: Local metrics and progress tracking

### 6.2 Student Mobile App

#### Authentication
- Email/password sign-in and registration
- Google OAuth sign-in
- Biometric authentication (fingerprint/Face ID)
- Email verification flow
- Secure credential storage (encrypted)

#### Learning Features
- **Course Browsing**: View available courses and lessons
- **Offline Access**: Download lessons for offline viewing
- **Quiz System**: Take quizzes with instant scoring
- **Progress Tracking**: Track completion and mastery levels
- **Announcements**: View system-wide announcements

#### Teacher Features
- **Lesson Creation**: Create and publish lessons
- **Quiz Management**: Build quizzes with multiple questions
- **Session Scheduling**: Schedule teaching sessions
- **Student Monitoring**: Track assigned student progress
- **Announcements**: Broadcast messages to students

#### Offline-First Architecture
- All content cached locally in SQLite
- Automatic sync when connectivity restored
- Conflict resolution (last-write-wins)
- Retry logic with exponential backoff

### 6.3 Shared Features
- **Role-Based Access Control**: Student, Teacher, Dev Admin, School Admin
- **Responsive Design**: Adapts to different screen sizes
- **Dark Mode Support**: Light and dark themes
- **Error Handling**: Graceful degradation on network failure
- **Security**: Row Level Security (RLS) policies on all tables

---

## 7. User Roles

| Role | Platform | Permissions |
|------|----------|-------------|
| **Dev Admin** | Web | Full system access, global settings, kill switch, activity logs |
| **School Admin** | Web | Manage local centers, users, courses, teacher approvals |
| **Student** | Mobile | View lessons, take quizzes, track progress, download content |
| **Teacher** | Mobile | Create lessons/quizzes, schedule sessions, monitor students, announce |

---

## 8. Setup Instructions

### Prerequisites

1. **Install Flutter SDK**
   - Download from: https://flutter.dev/docs/get-started/install
   - Recommended: Stable channel, SDK 3.11.x or later
   - Verify installation:
     ```bash
     flutter doctor
     ```

2. **Install Node.js** (optional, for helper scripts)
   - Download from: https://nodejs.org/
   - Verify:
     ```bash
     node --version
     npm --version
     ```

3. **Install Supabase CLI** (optional, for local DB management)
   ```bash
   npm install -g supabase
   ```

4. **Code Editor**
   - Recommended: VS Code with Flutter extension
   - Or: Android Studio with Flutter plugin

### Step-by-Step Setup

#### Step 1: Clone the Repository

```bash
cd D:\Documents\Studies\SY_2025-2026\SEM2\EmergingTech\ALS-Bondave
git clone <your-repo-url> emerging-tech-Als-LMS
cd emerging-tech-Als-LMS
```

#### Step 2: Set Up Supabase Backend

**Option A: Use Hosted Supabase (Recommended for Development)**

1. The app is configured to use a hosted Supabase instance
2. You'll need the Supabase URL and anon key from your friend
3. Create environment files (see Step 3)

**Option B: Run Supabase Locally**

1. Install Docker Desktop: https://www.docker.com/products/docker-desktop
2. Start Supabase locally:
   ```bash
   cd emerging-tech-Als-LMS
   supabase start
   ```
3. Apply migrations:
   ```bash
   supabase db push
   ```
4. Note the local Supabase URL and anon key from the output

#### Step 3: Configure Environment Variables

Create environment files for both apps:

**For admin_web:**
```bash
cd ALS-LMS\apps\admin_web
# Create a new file called .env (DO NOT commit this)
```

Add the following content:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**For student_phone:**
```bash
cd ALS-LMS\apps\student_phone
# Create a new file called .env (DO NOT commit this)
```

Add the same content:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

> **⚠️ IMPORTANT:** Get the actual Supabase credentials from your friend. Check if there's a `.env.example` file or ask them directly.

#### Step 4: Install Flutter Dependencies

Install dependencies for each package (run from repository root):

```bash
# Install shared_models
cd ALS-LMS\packages\shared_models
flutter pub get

# Install shared_services
cd ..\shared_services
flutter pub get

# Install shared_ui
cd ..\shared_ui
flutter pub get

# Install admin_web
cd ..\..\apps\admin_web
flutter pub get

# Install student_phone
cd ..\student_phone
flutter pub get
```

**Or use this one-liner (PowerShell):**
```powershell
Get-ChildItem -Path "ALS-LMS\packages","ALS-LMS\apps" -Recurse -Filter "pubspec.yaml" | ForEach-Object { Push-Location $_.DirectoryName; flutter pub get; Pop-Location }
```

#### Step 5: Verify Setup

Run the analyzer to check for issues:

```bash
cd ALS-LMS\apps\admin_web
flutter analyze

cd ..\student_phone
flutter analyze
```

---

## 9. Running the Applications

### 9.1 Running Admin Web (Flutter Web)

```bash
cd ALS-LMS\apps\admin_web

# Run in Chrome
flutter run -d chrome

# Or run in Edge (Windows)
flutter run -d edge
```

**To build for production:**
```bash
flutter build web --release
```

The admin web app will open in your browser at `http://localhost:XXXX` (port shown in console).

### 9.2 Running Student Mobile App

**Option A: Android Emulator**

1. Start Android Studio
2. Open AVD Manager and create/start an emulator
3. In terminal:
   ```bash
   cd ALS-LMS\apps\student_phone
   flutter run
   ```

**Option B: Physical Android Device**

1. Enable Developer Options on your phone
2. Enable USB Debugging
3. Connect via USB
4. Run:
   ```bash
   cd ALS-LMS\apps\student_phone
   flutter devices  # Verify device detected
   flutter run
   ```

**Option C: iOS Simulator (macOS only)**

```bash
cd ALS-LMS\apps\student_phone
flutter run -d iphone
```

### 9.3 Running in Debug Mode

All apps support hot reload during development:

```bash
flutter run --debug
```

While running, use these commands:
- `r` — Hot reload
- `R` — Hot restart
- `p` — Toggle platform overlay
- `q` — Quit

### 9.4 Running Tests

```bash
cd ALS-LMS\apps\admin_web
flutter test

cd ..\student_phone
flutter test
```

---

## 10. Known Issues & TODOs

### 10.1 Dependency Updates

From `DEPENDENCIES.md` audit (March 8, 2026):

- **mobile_app**: Several packages need updates:
  - `connectivity_plus` → 7.0.0 (currently 6.1.1)
  - `google_sign_in` → 7.x (currently 6.2.2)
  - `drift` → 2.32.0
  - `flutter_dotenv` → 6.0.0
  - `js` package is **discontinued** — should be replaced or removed

- **backend_services**: `connectivity_plus` → 7.0.0

### 10.2 Architecture Concerns

1. **Monorepo Path Mismatch**: 
   - README references `als_study_companion/` but actual structure uses `ALS-LMS/`
   - CI workflow references old paths that may not work

2. **Missing Package**: 
   - README mentions `mobile_app` but actual directory is `student_phone`
   - README mentions `backend_services` but structure shows `shared_services`

3. **Environment Variables**: 
   - No `.env.example` files found in current structure
   - Need to clarify where Supabase credentials should be stored

4. **Code Generation**: 
   - If using `drift` or `json_serializable`, need to run:
     ```bash
     flutter pub run build_runner build --delete-conflicting-outputs
     ```

### 10.3 Database

- Migration files span from March 2026 — review for conflicts or missing tables
- Some migrations archived — verify current schema is complete
- Row Level Security (RLS) policies need thorough testing

### 10.4 Features Mentioned in README but Not Verified

The extensive README describes features that may or may not be fully implemented:
- Offline sync with conflict resolution
- Biometric authentication setup flow
- Progress CSV export
- Video upload with progress tracking
- Bulk CSV user import
- Analytics dashboards

**Action Required**: Test each feature to verify implementation status.

---

## 11. Recommendations for Improvement

### 11.1 Immediate Actions

1. **Fix Monorepo Structure References**
   - Update README.md to match actual directory structure
   - Update CI workflow paths to use `ALS-LMS/apps/` and `ALS-LMS/packages/`

2. **Add Environment Configuration**
   - Create `.env.example` files for both apps
   - Document required environment variables in SETUP.md

3. **Update Dependencies**
   - Run `flutter pub upgrade` in a feature branch
   - Test thoroughly after updates
   - Replace discontinued packages

4. **Run Code Generation**
   ```bash
   cd ALS-LMS\apps\student_phone
   flutter pub run build_runner build --delete-conflicting-outputs
   
   cd ALS-LMS\packages\shared_models
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### 11.2 Short-Term Improvements

1. **Add Integration Tests**
   - Test critical user flows (registration → lesson → quiz)
   - Test offline → online sync scenarios

2. **Improve Error Handling**
   - Add user-friendly error messages
   - Implement retry mechanisms for failed operations

3. **Add Loading States**
   - Ensure all async operations have proper loading indicators
   - Add skeleton screens for better UX

4. **Implement Proper Logging**
   - Add structured logging (e.g., `logger` package)
   - Different log levels for debug vs. production

### 11.3 Long-Term Enhancements

1. **Feature Completeness Audit**
   - Test all features described in README
   - Create issue tracker for missing features
   - Prioritize implementation

2. **Performance Optimization**
   - Implement lazy loading for large lists
   - Add pagination for course/lesson browsing
   - Optimize image caching strategy

3. **Accessibility**
   - Add screen reader support
   - Ensure proper color contrast
   - Add keyboard navigation for web

4. **Internationalization**
   - Add Filipino/Tagalog language support
   - Extract all strings to ARB files
   - Implement locale switching

5. **Documentation**
   - Add API documentation
   - Create user guides for each role
   - Add architecture decision records (ADRs)

6. **CI/CD Enhancement**
   - Add automated builds
   - Add deployment pipelines
   - Add code coverage reporting

---

## 12. Next Steps

### For Getting Started:

1. ✅ Review this analysis document
2. ⏳ Get Supabase credentials from your friend
3. ⏳ Install Flutter SDK and verify with `flutter doctor`
4. ⏳ Create `.env` files with Supabase credentials
5. ⏳ Run `flutter pub get` for all packages
6. ⏳ Start admin web: `cd ALS-LMS\apps\admin_web && flutter run -d chrome`
7. ⏳ Start student app: `cd ALS-LMS\apps\student_phone && flutter run`
8. ⏳ Explore both apps to understand current functionality

### For Contributing:

1. Create a feature branch for each improvement
2. Test changes on both web and mobile
3. Run `flutter analyze` before committing
4. Write tests for new features
5. Update documentation when adding features

---

## Appendix A: Quick Reference Commands

### Installation
```bash
# Install all dependencies (PowerShell one-liner)
Get-ChildItem -Path "ALS-LMS\packages","ALS-LMS\apps" -Recurse -Filter "pubspec.yaml" | ForEach-Object { Push-Location $_.DirectoryName; flutter pub get; Pop-Location }
```

### Running Apps
```bash
# Admin Web
cd ALS-LMS\apps\admin_web && flutter run -d chrome

# Student Mobile
cd ALS-LMS\apps\student_phone && flutter run
```

### Code Generation
```bash
cd ALS-LMS\apps\student_phone
flutter pub run build_runner build --delete-conflicting-outputs
```

### Testing
```bash
cd ALS-LMS\apps\admin_web && flutter test
cd ALS-LMS\apps\student_phone && flutter test
```

### Analysis
```bash
cd ALS-LMS\apps\admin_web && flutter analyze
cd ALS-LMS\apps\student_phone && flutter analyze
```

### Supabase (if running locally)
```bash
supabase start
supabase db push
supabase stop
```

---

## Appendix B: Useful Resources

- **Flutter Docs**: https://flutter.dev/docs
- **BLoC Library**: https://bloclibrary.dev/
- **Supabase Docs**: https://supabase.com/docs
- **Dart Pub**: https://pub.dev/
- **Project Repo**: https://github.com/EvadNOB/emerging-tech-Als-LMS

---

**Document prepared by:** AI Assistant  
**Date:** April 14, 2026  
**Purpose:** Project onboarding and improvement planning
