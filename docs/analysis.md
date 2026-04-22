# ALS Study Companion — Project Analysis

> **Course**: Emerging Technologies | SY 2025–2026, Semester 2  
> **Project**: Alternative Learning System (ALS) — Offline-First Learning Management System  
> **Analyzed**: April 22, 2026

---

## 1. What This Project Is

The **ALS Study Companion** is a multi-platform, offline-first Learning Management System (LMS) built for the Philippine government's **Alternative Learning System (ALS)** program — an education pathway for out-of-school youth and adults. It connects three user roles — **Student**, **Teacher**, and **Admin** — across a mobile app and a web portal.

| Platform | App | Audience |
|---|---|---|
| Flutter Mobile (Android/iOS) | `student_phone` | Students & Teachers |
| Flutter Web | `admin_web` | Administrators |

**Core philosophy**: Works completely offline first (SQLite local cache), syncs to the cloud (Supabase) when internet is restored.

---

## 2. Technology Stack

| Layer | Technology | Version |
|---|---|---|
| **Frontend Framework** | Flutter / Dart | SDK ≥ 3.5.0 |
| **State Management** | `flutter_bloc` (student_phone), `ChangeNotifier` / Provider (admin_web) | BLoC ^8.1.6 |
| **Backend / Auth / DB** | Supabase (PostgreSQL + Auth + Storage) | supabase_flutter ^2.8.0 |
| **Local Storage (primary)** | SQLite via `sqflite` | ^2.4.1 |
| **Local Storage (auth cache/sync queue)** | Drift ORM | ^2.16.0 |
| **Routing** | `go_router` | ^14.0.0 |
| **UI** | Google Fonts, flutter_svg, cached_network_image, shimmer | — |
| **Media** | video_player, chewie, mobile_scanner, syncfusion_flutter_pdfviewer | — |
| **Tooling (root)** | Node.js + Supabase CLI | supabase ^2.77.1 |

---

## 3. Repository & Monorepo Architecture

```
emerging-tech-Als-LMS/           ← Git root
├── ALS-LMS/
│   ├── apps/
│   │   ├── admin_web/           ← Flutter Web (Admin portal)
│   │   └── student_phone/       ← Flutter Mobile (Students & Teachers)
│   └── packages/
│       ├── shared_models/       ← Pure Dart: data models, enums, utils
│       ├── shared_services/     ← Flutter: Supabase service wrappers
│       └── shared_ui/           ← Shared UI components
├── supabase/
│   ├── config.toml
│   └── migrations/              ← 10 SQL migration files
├── docs/                        ← Documentation
├── scripts/
├── package.json                 ← Node.js root (Supabase CLI)
├── .gitignore
└── README.md
```

### Dependency Graph

```
shared_models  (no external deps)
     ▲
     │
shared_services  (depends on shared_models + supabase_flutter)
     ▲
     ├─────────────────┐
admin_web          student_phone
(web browser)      (Android/iOS)
```

### Git State

| Item | Value |
|---|---|
| Active branch | `main` |
| Remote `origin` | `https://github.com/EvadNOB/emerging-tech-Als-LMS.git` |
| Remote `new-origin` | `https://github.com/Lamzeez/ALS.git` |
| Total commits | 20+ commits on main |
| Remote branches | `origin/main`, `origin/feature/student-learning-flow`, `new-origin/main` |

---

## 4. Packages Deep Dive

### 4.1 `shared_models` — Pure Dart Library
Single source of truth for all data structures shared across both apps.

**11 Models**: `UserModel`, `LessonModel`, `QuizModel`, `QuestionModel`, `ProgressModel`, `StudentModel`, `TeacherModel`, `AlsCenterModel`, `SessionModel`, `AnnouncementModel`, `DownloadModel`

**5 Enums**: `UserRole` (student/teacher/admin), `SyncStatus`, `LessonStatus`, `QuizStatus`, `DownloadStatus`

**3 Utility Classes**: `AppDateUtils`, `Validators`, `StringExtensions`

All models implement `fromMap()`, `toMap()`, and `copyWith()` — handling both `snake_case` (Supabase) and `camelCase` (SQLite legacy) key naming.

### 4.2 `shared_services` — Flutter Library
Reusable Supabase service layer:

| Service | Responsibility |
|---|---|
| `SupabaseAuthService` | Email/password sign-in, Google OAuth, registration, session management |
| `SupabaseDatabaseService` | Generic CRUD + typed convenience methods for all 11 tables |
| `SupabaseStorageService` | File upload/download with progress, signed URLs |
| `SyncService` | Push/pull sync with exponential backoff retry (up to 5 retries) |

### 4.3 `shared_ui`
Shared UI components used across both apps.

---

## 5. Apps Deep Dive

### 5.1 `admin_web` — Flutter Web Admin Portal

**Auth**: Email + password only (no Google OAuth, no biometrics).

**5 Pages via NavigationRail sidebar**:

| Page | Key Features |
|---|---|
| Dashboard | 8 metric cards, recent audit log activity |
| User Management | Search/filter users, approve/revoke teachers, toggle active, change roles, bulk CSV import |
| Content Management | List/publish/delete lessons and quizzes |
| ALS Center Management | Full CRUD on ALS learning centers |
| Analytics | 6 aggregate metrics, progress indicator, recent audit activity |

**5 ViewModels**: `AdminAuthViewModel`, `AnalyticsViewModel`, `CenterManagementViewModel`, `ContentManagementViewModel`, `UserManagementViewModel`

> **Note**: The admin web app has the Supabase anon key hardcoded in `main.dart` (Known Issue #9). It should be moved to `.env` like `student_phone` does.

### 5.2 `student_phone` — Flutter Mobile App

**Auth**: Email+password, Google Sign-In, Biometric (fingerprint/Face ID).

**Two user flows share one app**:

#### Student Flow (4-tab Navigation)
- **Home**: Welcome card, quick stats, recent lessons
- **Lessons**: Subject-filtered lesson cards with offline access
- **Progress**: Overall circular indicator + per-lesson breakdown; CSV export
- **Downloads**: Per-file download progress, storage summary

#### Teacher Flow (5-tab Navigation)
- **Home**: Quick-action grid (New Lesson, Create Quiz, Schedule, Announce)
- **Lessons**: Create/edit/publish lessons with video upload (real-time progress bar)
- **Students**: View assigned students' progress data
- **Sessions**: Schedule and manage teaching sessions
- **Announcements**: Create/delete announcements

**Key ViewModels**: `AuthViewModel` (central), `LessonViewModel`, `QuizViewModel`, `ProgressViewModel`, `DownloadViewModel`, `SyncViewModel`, `TeacherLessonViewModel`, `QuizCreatorViewModel`, `SessionViewModel`, `StudentMonitorViewModel`, `AnnouncementViewModel`, `VideoUploadViewModel`

---

## 6. Database Architecture

### 6.1 Supabase (PostgreSQL) — Cloud

**11 Tables**: `users`, `lessons`, `quizzes`, `questions`, `progress`, `sessions`, `announcements`, `als_centers`, `students`, `teachers`, `audit_logs`

**Database Triggers & Functions**:
- `handle_new_auth_user()` — Auto-creates `public.users` row from Supabase Auth metadata on registration
- `update_updated_at_column()` — Auto-stamps `updated_at` on every UPDATE
- `validate_user_email()` — Validates `full_name` length and `role` value
- `validate_student_lrn()` — Ensures LRN is exactly 12 digits
- `current_user_role()` — SECURITY DEFINER to avoid RLS recursion

**Row Level Security (RLS)** enforced on all tables:
- Students: read/write own data only
- Teachers: read/write own content + read their students' data
- Admins: full access to all tables

### 6.2 SQLite — Local (sqflite)

Mirrors the Supabase schema but uses **camelCase** column names for legacy compatibility. `DatabaseHelper` singleton manages all 11 local tables. Every record has a `syncStatus` field driving the sync system.

### 6.3 Drift ORM — Local Auth Cache

Two tables: `Users` (auth state cache, populated on every sign-in) and `SyncQueue` (offline write operations queue).

### 6.4 Supabase Storage Buckets

| Bucket | Path Pattern |
|---|---|
| `lesson-videos` | `lessons/{lessonId}/{fileName}` |
| `lesson-materials` | `lessons/{lessonId}/{fileName}` |
| `profile-pictures` | `profile_pictures/{userId}` |

---

## 7. Offline-First Sync System

Every record carries a `syncStatus` field:

| Status | Meaning |
|---|---|
| `synced` | In sync with cloud |
| `pendingUpload` | Modified locally; needs push to Supabase |
| `pendingDownload` | On cloud; not yet fetched locally |
| `syncing` | In-flight operation |
| `error` | Last sync failed |

**Sync cycle** (`SyncViewModel.syncAll()`):
1. **Push** — Query SQLite for `pendingUpload` records → upsert to Supabase → mark `synced`
2. **Pull** — Fetch lessons/quizzes/announcements from Supabase → save to SQLite → mark `synced`

**Retry**: Up to 5 retries with `2^attempt` seconds + random jitter (exponential backoff).

**Conflict resolution**: Last-write-wins based on `updated_at` timestamp.

---

## 8. Authentication Flows

```
Student Registration → Email Verification → Biometric Setup (optional) → Student Dashboard
Teacher Registration → Email Verification → Admin Approval Required → Teacher Dashboard
Admin Login         → Direct to Admin Shell (web browser only)
Google Sign-In      → Supabase OAuth → Role-based routing
Biometric Login     → SecureStorage credentials → signIn()
```

---

## 9. Migration History

| File | Purpose |
|---|---|
| `20260301_base_users_table.sql` | Initial users table |
| `20260309_comprehensive_schema.sql` | Full schema (all 11 tables) |
| `20260310_missing_tables.sql` | Additional tables |
| `20260311_fix_schema_and_policies.sql` | Schema fixes + RLS policies |
| `20260312_fix_schema_issues.sql` | Schema issue patches |
| `20260321_fix_profile_storage_policies.sql` | Storage bucket policies |
| `20260414_add_missing_tables.sql` | Additional table additions |
| `20260415_rls_policies_fixed.sql` | Revised RLS policies |
| `20260416_enable_rls.sql` | Enable RLS on all tables |
| `20260416_fix_onboarding_and_metadata.sql` | Onboarding & metadata fixes |

> [!WARNING]
> Two migrations from 2026-03-11 are near-duplicates (`fix_schema_and_policies` and `fix_schema_issues`). Run these carefully in order — they may conflict if re-applied without idempotent guards.

---

## 10. Known Issues & TODOs

| # | Location | Issue |
|---|---|---|
| 1 | `StudentProgressView` | Overall progress `CircularProgressIndicator` hardcoded to `0.0` — not wired to `ProgressViewModel` |
| 2 | `StudentDownloadsView` | UI is placeholder only — no functional download logic |
| 3 | `TeacherSessionsView` | Empty placeholder — session creation form is TODO |
| 4 | `TeacherStudentsView` | Placeholder — "Students will appear here once assigned by admin" |
| 5 | `TeacherAnnouncementsView` | Placeholder — announcement creation form is TODO |
| 6 | `TeacherLessonCreateView` | `teacherId: ''` is hardcoded — should pull from `AuthViewModel.currentUser.id` |
| 7 | `QuizCreatorRepository` | Uses `camelCase` columns inconsistently with `TeacherLessonRepository` (uses `snake_case`) |
| 8 | `StudentMonitorRepository` | Supabase queries use `camelCase` — may break against cloud data (expects `snake_case`) |
| 9 | `admin_web/main.dart` | Supabase anon key hardcoded — should use `.env` file like `student_phone` |
| 10 | Migrations | Duplicate-risk migrations from 2026-03-11 — apply with caution |

---

## 11. Environment Variables

Both apps use a `.env` file (gitignored — never committed):

```env
SUPABASE_URL=https://trixvamgvaihvuqpyjwc.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> [!IMPORTANT]
> The `.env` files must be shared with collaborators out-of-band (e.g., via secure message, shared notes, or a password manager). **Never push `.env` to GitHub.**

---

## 12. Summary Assessment

| Category | Status |
|---|---|
| Architecture | ✅ Clean monorepo, well-separated concerns |
| State Management | ✅ BLoC + ChangeNotifier appropriately used |
| Offline-First Design | ✅ Solid SQLite + Drift dual-layer cache |
| Auth System | ✅ Email, Google OAuth, Biometric all implemented |
| Database / RLS | ✅ Comprehensive schema with proper security policies |
| Admin Portal | ✅ Feature-complete |
| Student Mobile Flow | ⚠️ Core features work; Downloads & Progress views are placeholders |
| Teacher Mobile Flow | ⚠️ Lesson creation works; Sessions, Students, Announcements views are placeholders |
| Environment Config | ⚠️ Admin web still has hardcoded keys |
| Test Coverage | ⚠️ Test stubs exist but coverage is minimal |
