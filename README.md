# ALS Study Companion — Full Project Summary

> **Philippine Alternative Learning System (ALS) — Offline-First Learning Management System**
> Built with Flutter/Dart · Supabase (PostgreSQL + Auth + Storage) · Multi-platform (Mobile + Web)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Monorepo Architecture](#2-monorepo-architecture)
3. [Package: shared_core](#3-package-shared_core)
4. [Package: backend_services](#4-package-backend_services)
5. [Package: admin_web](#5-package-admin_web)
6. [Package: mobile_app](#6-package-mobile_app)
7. [Database Schema](#7-database-schema)
8. [CRUD Operations](#8-crud-operations)
9. [User Roles & Purposes](#9-user-roles--purposes)
10. [Layer Connections & Data Flow](#10-layer-connections--data-flow)
11. [Offline-First Sync System](#11-offline-first-sync-system)
12. [Authentication Flows](#12-authentication-flows)
13. [Storage Buckets](#13-storage-buckets)
14. [Dependencies](#14-dependencies)
15. [Known Issues / TODOs](#15-known-issues--todos)
16. [Quick Start](#16-quick-start)

---

## 1. Project Overview

The **ALS Study Companion** is an offline-first, multi-platform Learning Management System (LMS) built for the Philippine government's Alternative Learning System (ALS) program. It supports three user roles — **Student**, **Teacher**, and **Admin** — across two platforms:

| Platform | Package | Audience |
|---|---|---|
| Flutter Web App | `admin_web` | Administrators |
| Flutter Mobile App (Android/iOS) | `mobile_app` | Students & Teachers |

**Backend**: Supabase hosted at `https://igaukxfswcpwvgdwcjuh.supabase.co`
- PostgreSQL (primary data store with Row Level Security)
- Supabase Auth (email/password + Google OAuth)
- Supabase Storage (lesson videos, PDF materials, profile pictures)

**Design goals:**
- Works fully offline — all data cached in local SQLite
- Syncs to the cloud when connectivity is restored
- Admin manages everything from the browser; students/teachers use the mobile app

---

## 2. Monorepo Architecture

```
ALS Study Companion/
├── ALS-LMS/                      ← Monorepo Root
│   ├── apps/
│   │   ├── admin_web/            ← Flutter Web app (Admin portal)
│   │   └── student_phone/        ← Flutter Mobile app (Student & Teacher)
│   ├── packages/
│   │   ├── shared_models/        ← Unified data models (matching Supabase schema)
│   │   ├── shared_services/      ← Core business logic (Auth, Supabase, Sync, Storage)
│   │   └── shared_ui/            ← Reusable design system components
├── supabase/
│   ├── config.toml
│   └── migrations/               ← SQL migration history
└── docs/                         ← Setup, dependency, migration guides
```

### Dependency Graph

```
shared_models (no internal deps)
     ▲
     │
shared_services (depends on shared_models)
     ▲
     ├──────────────┐
admin_web         student_phone
(depends on       (depends on
 shared_models +   shared_models +
 shared_services + shared_services +
 shared_ui)        shared_ui)
```

---

## 3. Package: shared_core

**Type**: Pure Dart library (no Flutter, no external runtime deps)  
**Purpose**: Single source of truth for all data models, enums, constants, and utility functions shared across every package.

### 3.1 Models (11 total)

| Model | Key Fields | Purpose |
|---|---|---|
| `UserModel` | `id`, `email`, `fullName`, `role` (UserRole), `profilePictureUrl`, `alsCenterId`, `isActive`, `emailVerified`, `teacherVerified`, student demographic fields (`firstName`, `lastName`, `studentIdNumber`, `dateOfBirth`, `age`, `phoneNumber`, `occupation`, `lastSchoolAttended`, `lastYearAttended`) | Universal user profile for all three roles |
| `LessonModel` | `id`, `title`, `description`, `subject`, `gradeLevel`, `teacherId`, `videoUrl`, `studyGuideUrl`, `thumbnailUrl`, `durationMinutes`, `orderIndex`, `isPublished`, `syncStatus` | A single learning module created by a teacher |
| `QuizModel` | `id`, `lessonId`, `title`, `timeLimitMinutes` (default 30), `passingScore` (default 75%), `totalQuestions`, `teacherId`, `isPublished`, `syncStatus` | A quiz attached to a lesson |
| `QuestionModel` | `id`, `quizId`, `questionText`, `options` (List\<String\>), `correctOptionIndex`, `explanation`, `orderIndex` | A single multiple-choice question; options stored pipe-delimited in SQLite |
| `ProgressModel` | `id`, `studentId`, `lessonId`, `quizId`, `progressPercent`, `quizScore`, `timeSpentMinutes`, `syncStatus`, `lastAccessedAt` | A student's progress on one lesson (unique per student+lesson) |
| `StudentModel` | `id`, `userId`, `teacherId`, `alsCenterId`, `learnerReferenceNumber`, `gradeLevel`, `guardianName`, `guardianContact`, `enrollmentDate`, `isActive` | Extended profile linked to a student user |
| `TeacherModel` | `id`, `userId`, `alsCenterId`, `employeeId`, `specialization`, `assignedStudentIds`, `isActive` | Extended profile linked to a teacher user |
| `AlsCenterModel` | `id`, `name`, `address`, `region`, `contactNumber`, `headTeacherId`, `isActive` | An ALS learning center location |
| `SessionModel` | `id`, `teacherId`, `title`, `description`, `lessonId`, `location`, `scheduledAt`, `durationMinutes` (default 60), `studentIds`, `isCompleted` | A scheduled teaching session |
| `AnnouncementModel` | `id`, `authorId`, `title`, `content`, `targetRole`, `alsCenterId`, `isActive` | A broadcast message from a teacher or admin |
| `DownloadModel` | `id`, `lessonId`, `studentId`, `localFilePath`, `downloadProgress`, `status` (DownloadStatus), `fileSizeBytes` | Tracks an offline download of a lesson file |

All models implement:
- `fromMap(Map<String, dynamic>)` — accepts both `snake_case` (Supabase) and `camelCase` (SQLite legacy) keys
- `toMap()` — always emits `snake_case` keys
- `copyWith(...)` — immutable update pattern

### 3.2 Enums (5 total)

| Enum | Values | Usage |
|---|---|---|
| `UserRole` | `student`, `teacher`, `admin` | Routes user to correct app area on login |
| `SyncStatus` | `synced`, `pendingUpload`, `pendingDownload`, `syncing`, `error` | Tracks cloud sync state per record |
| `LessonStatus` | `notStarted`, `inProgress`, `completed`, `downloaded` | UI state for lesson cards |
| `QuizStatus` | `notStarted`, `inProgress`, `completed`, `passed`, `failed` | UI state for quiz cards |
| `DownloadStatus` | `notDownloaded`, `downloading`, `downloaded`, `failed` | State for download progress |

### 3.3 Constants

| Class | Key Values |
|---|---|
| `AppConstants` | `pageSize=20`, `syncIntervalMinutes=15`, `maxRetries=3`, `maxConcurrentDownloads=3`, `maxVideoSizeBytes=500MB`, `maxDocSizeBytes=50MB`, `defaultPassingScore=75`, `defaultQuizTimeLimit=30` |
| `DbConstants` | All 11 SQLite table name strings (`tableUsers`, `tableLessons`, `tableQuizzes`, etc.), `dbName='als_study_companion.db'`, `dbVersion=3` |
| `FirestoreConstants` | Collection name mirrors + Supabase Storage path prefixes (`lesson_videos/{id}/`, `lesson_materials/{id}/`, `profile_pictures/`) |

### 3.4 Utilities

| Class | Methods |
|---|---|
| `AppDateUtils` | `formatDate()`, `formatTime()`, `formatShortDate()`, `timeAgo()`, `formatDuration()` |
| `Validators` | `validateEmail()`, `validatePassword()` (min 8, upper+lower+digit+special), `validateConfirmPassword()`, `validateFullName()`, `validateLearnerReferenceNumber()` (exactly 12 digits), `validatePhone()`, `validateRequired()`, `validateStudentIdNumber()` |
| `StringExtensions` | `.capitalize`, `.titleCase`, `.truncate(maxLength)`, `.initials` |

---

## 4. Package: backend_services

**Type**: Flutter library  
**Purpose**: Reusable service layer that wraps all Supabase interactions — authentication, database CRUD, file storage, and offline sync.

### 4.1 SupabaseAuthService

| Method | Description |
|---|---|
| `signInWithEmailAndPassword(email, password)` | Supabase email/password sign-in |
| `registerWithEmailAndPassword(email, password, fullName, role, metadata)` | Supabase sign-up; passes all user fields as `user_metadata` so the DB trigger auto-creates the `public.users` row |
| `signOut()` | Clears Supabase session |
| `sendPasswordResetEmail(email)` | Triggers Supabase password reset flow |
| `getCurrentUserModel()` | Reads `public.users` by current auth UID → returns `UserModel` |
| `updateUserProfile(userId, data)` | Updates `public.users` row |
| `deleteUserRecord(userId)` | Deletes `public.users` row |
| `isEmailVerified` | Reads from current Supabase session |

### 4.2 SupabaseDatabaseService

Generic CRUD over any Supabase table:

| Method | Description |
|---|---|
| `addDocument(table, data)` | INSERT |
| `getDocument(table, id)` | SELECT by id |
| `updateDocument(table, id, data)` | UPDATE by id |
| `deleteDocument(table, id)` | DELETE by id |
| `getCollection(table, {limit, offset, orderBy, ascending})` | SELECT with pagination |
| `queryCollection(table, filters, {orderBy, limit})` | SELECT with WHERE filters |

Typed convenience methods:

| Method | Description |
|---|---|
| `getLessons({teacherId})` | Fetch lessons (optionally filtered by teacher) |
| `saveLesson(lesson)` | Upsert a `LessonModel` |
| `getQuizzesForLesson(lessonId)` | Fetch quizzes for a lesson |
| `saveQuiz(quiz)` | Upsert a `QuizModel` |
| `getQuestionsForQuiz(quizId)` | Fetch questions for a quiz |
| `saveQuestion(question)` | Upsert a `QuestionModel` |
| `getStudentProgress(studentId)` | Fetch all progress records for a student |
| `saveProgress(progress)` | Upsert a `ProgressModel` |
| `getTeacherSessions(teacherId)` | Fetch sessions for a teacher |
| `saveSession(session)` | Upsert a `SessionModel` |
| `getAnnouncements({centerId})` | Fetch announcements (optionally by center) |
| `saveAnnouncement(announcement)` | Upsert an `AnnouncementModel` |
| `getAlsCenters()` | Fetch all ALS centers |
| `saveAlsCenter(center)` | Upsert an `AlsCenterModel` |
| `getUsers({role})` | Fetch all users (optionally filtered by role) |

### 4.3 SupabaseStorageService

| Method | Description |
|---|---|
| `uploadFile(bucket, path, bytes, contentType)` | Generic file upload; returns public URL |
| `uploadFileWithProgress(bucket, path, bytes, contentType, onProgress)` | Upload with 0.0→1.0 progress callback (notified in 10 steps) |
| `getPublicUrl(bucket, path)` | Returns permanent public URL |
| `getSignedUrl(bucket, path, {expiresIn=3600})` | Returns time-limited signed URL |
| `deleteFile(bucket, path)` | Deletes a file from storage |
| `uploadLessonVideo(lessonId, videoBytes, fileName, {onProgress})` | Uploads to `lesson-videos/lessons/{lessonId}/{fileName}` |
| `uploadLessonMaterial(lessonId, fileBytes, fileName, contentType)` | Uploads to `lesson-materials/lessons/{lessonId}/{fileName}` |

### 4.4 SyncService

| Method | Description |
|---|---|
| `performSync({pushCallback, pullCallback})` | Runs one push+pull cycle; returns `SyncResult` |
| `performSyncWithRetry({maxRetries=5})` | Retries with exponential backoff (`2^attempt` seconds + random jitter) |
| `resolveConflict(local, remote)` | Last-write-wins: whichever has the later `updated_at` wins |
| `hasConnectivity` | Checks via `ConnectivityPlus` |

---

## 5. Package: admin_web

**Type**: Flutter Web application  
**Audience**: System administrators  
**Purpose**: Browser-based control panel for managing users, content, ALS centers, and viewing analytics. Connects **directly** to Supabase (not via `backend_services`) for most queries.

### 5.1 Pages

#### Login Page (`admin_login_page.dart`)
- Email + password form
- Calls `AdminAuthViewModel.signIn(email, password)`
- Shows loading spinner during auth
- Debug mode pre-fills credentials

#### Admin Shell (`dashboard/admin_shell.dart`)
- Persistent `NavigationRail` sidebar (collapses at width < 1200px)
- 5 navigation destinations mapping to 5 pages:

```
Dashboard → AdminDashboardPage
Users     → UserManagementPage
Content   → ContentManagementPage
Centers   → CenterManagementPage
Analytics → AnalyticsPage
```

#### Dashboard (`AdminDashboardPage`)
- Responsive metric grid (4 columns > 900px, 2 columns otherwise)
- **8 metric cards**: Total Students · Total Teachers · Total Lessons · ALS Centers · Active Users · Avg Progress % · Total Quizzes · Published Lessons
- **Recent Activity** section: last 10 entries from `audit_logs` table

#### User Management (`UserManagementPage`)
Two tabs: **Users** | **Audit Log**

| Feature | Description |
|---|---|
| Summary cards | Total users · Students count · Teachers count · Pending Approval count |
| Search | Full-text search by name or email |
| Role filter | Dropdown: All / Student / Teacher / Admin |
| Approve Teacher | Sets `teacher_verified = true` on `public.users` |
| Revoke Teacher | Sets `teacher_verified = false` |
| Toggle Active | Flips `is_active` boolean |
| Change Role | Updates `role` column |
| Bulk CSV Import | Batch upsert of multiple users at once |
| Audit Log tab | Shows timestamp, admin action, target user for every admin action |

#### Content Management (`ContentManagementPage`)
Two tabs: **Lessons** | **Quizzes**

| Feature | Description |
|---|---|
| Stats row | Total count / Published count for each |
| Search | Filter by title |
| Publish toggle | Flips `is_published` (both lessons and quizzes) |
| Delete | Removes lesson or quiz; requires confirmation |

#### ALS Center Management (`CenterManagementPage`)

| Feature | Description |
|---|---|
| List all centers | Card-based list with name, address, region, head teacher, status |
| Stat chips | Total / Active / Inactive counts |
| Search | Filter centers by name |
| Create center | Dialog form: name, address, region, contact number, head teacher ID, active toggle |
| Edit center | Same dialog pre-filled |
| Delete center | Confirm dialog before deletion |

#### Analytics Page (`AnalyticsPage`)
- 6-metric summary grid (same metrics as dashboard)
- `LinearProgressIndicator` for average overall progress %
- Recent audit activity list (last 5 entries)

### 5.2 Admin ViewModels

| ViewModel | State Exposed | Key Methods |
|---|---|---|
| `AdminAuthViewModel` | `isAuthenticated`, `currentUser`, `isLoading` | `signIn()`, `signOut()`, listens to `onAuthStateChange` stream |
| `AnalyticsViewModel` | `totalStudents`, `totalTeachers`, `totalLessons`, `totalQuizzes`, `averageProgress`, `activeUsers` (last 7 days), `pendingTeachers` | `loadAnalytics()` — parallel queries for all metrics |
| `CenterManagementViewModel` | `centers`, `isLoading`, `errorMessage` | `loadCenters()`, `createCenter()`, `updateCenter()`, `deleteCenter()` |
| `ContentManagementViewModel` | `lessons`, `quizzes`, `isLoading` | `loadContent()`, `deleteLesson()`, `togglePublish()`, `deleteQuiz()`, `toggleQuizPublish()` |
| `UserManagementViewModel` | `users`, `auditLogs`, `pendingTeachersCount`, `isLoading`, `errorMessage`, `successMessage` | `loadUsers()`, `searchUsers()`, `filterByRole()`, `toggleUserActive()`, `approveTeacher()`, `revokeTeacher()`, `changeRole()`, `bulkImportUsers()`, `loadAuditLogs()`, `_logAudit()` |

---

## 6. Package: mobile_app

**Type**: Flutter mobile application (Android + iOS)  
**Audience**: Students and Teachers  
**Purpose**: Offline-first learning app for consuming lessons, taking quizzes, tracking progress, and creating/managing content.

### 6.1 Core Layer

| File | Purpose |
|---|---|
| `app_theme.dart` | `AppColors` (primary `#1565C0`, accent `#26A69A`, error `#D32F2F`), `AppTextStyles` (6 text styles), `AppSpacing` (xs=4 → xxl=48) |
| `database_helper.dart` | `DatabaseHelper.instance` singleton — sqflite, `als_study_companion.db`, version 3; manages all 11 SQLite tables; methods: `insert()`, `queryAll()`, `queryWhere()`, `queryById()`, `update()`, `delete()` |
| `local_database.dart` | Drift ORM — `als_local.sqlite`; 2 typed tables: `Users` (auth state cache) and `SyncQueue` (pending offline operations); migrations v1→v2→v3 |
| `network_config.dart` | `connectionTimeout=30s`, `receiveTimeout=30s`, `maxRetries=3`, `retryDelay=2s` |
| `supabase_auth_service.dart` | Extended auth service (mobile): `signInWithEmailAndPassword()`, `registerStudent()`, `registerTeacher()`, `signInWithGoogle()`, `signOut()`, `sendEmailVerification()`, `getCurrentUserModel()` |
| `biometric_service.dart` | Wraps `local_auth`: `isAvailable()`, `getAvailableBiometrics()`, `getBiometricLabel()` ("Face ID"/"Fingerprint"), `authenticate()`, `cancelAuthentication()` |
| `connectivity_service.dart` | Listens to `Connectivity().onConnectivityChanged`; exposes `isOnline` bool + `onlineStream` |
| `secure_credential_storage.dart` | Wraps `FlutterSecureStorage` (Android: EncryptedSharedPreferences, iOS: Keychain); stores biometric-autofill email+password; `saveCredentials()`, `getCredentials()`, `isEnabled()`, `clearCredentials()` |

### 6.2 Shared Layer — Auth ViewModel

`AuthViewModel` (`ChangeNotifier`) is the central auth state manager:

| State | Type | Description |
|---|---|---|
| `currentUser` | `UserModel?` | Currently signed-in user |
| `currentRole` | `UserRole?` | Drives routing to student/teacher dashboard |
| `isAuthenticated` | `bool` | Whether a valid session exists |
| `needsEmailVerification` | `bool` | True after registration until email verified |
| `needsTeacherApproval` | `bool` | True for teachers until admin approves |
| `isBiometricAvailable` | `bool` | Device supports biometric auth |
| `isBiometricEnabled` | `bool` | User has enrolled biometric credentials |
| `biometricLabel` | `String` | "Face ID" or "Fingerprint" |

| Method | Description |
|---|---|
| `signIn(email, password)` | Supabase sign-in → save user to Drift `LocalDatabase.upsertUser()` |
| `registerStudent(...)` | Full student registration with all demographic fields |
| `registerTeacher(...)` | Teacher registration (simpler form) |
| `signInWithGoogle()` | Google OAuth → Supabase `signInWithIdToken()` |
| `signOut()` | Clears all local state + Supabase session |
| `checkEmailVerified()` | Refreshes session; for teachers also checks `teacher_verified` flag |
| `setupBiometric(email, password)` | Prompts biometric auth → on success saves credentials securely |
| `biometricAutoFill()` | Prompts biometric → retrieves saved credentials → auto-calls `signIn()` |
| `disableBiometric()` | Clears stored credentials |

### 6.3 Shared Layer — Views

| View | Description |
|---|---|
| `RoleSelectionView` | First screen on app launch — two large cards: **Student** / **Teacher**; navigates to `LoginView` with role pre-selected |
| `LoginView` | Email + password form; Google Sign-In button; biometric auto-fill button (if enabled); routes to correct dashboard by role after login |
| `StudentRegistrationView` | Full form: email, password, confirm, firstName, lastName, studentIdNumber, dateOfBirth (DatePicker, age auto-calculated), phone, occupation, lastSchoolAttended, lastYearAttended |
| `TeacherRegistrationView` | Simpler form: email, password, confirm, firstName, lastName, phone |
| `EmailVerificationView` | Polls `checkEmailVerified()` every 3 seconds; resend button with 30s cooldown; on verify → biometric setup (if available) → dashboard |
| `TeacherPendingApprovalView` | Polls `checkEmailVerified()` every 10 seconds; manual refresh button; sign-out option; auto-navigates to teacher dashboard when `teacher_verified=true` |
| `BiometricSetupView` | Offers fingerprint/Face ID enrollment; "Skip" button; on success → dashboard |

### 6.4 Student Layer

#### Student Repositories (SQLite via DatabaseHelper)

| Repository | CRUD Methods |
|---|---|
| `LessonRepository` | `getLocalLessons()`, `getLessonsBySubject(subject)`, `getLessonById()`, `saveLesson()`, `saveLessons()`, `deleteLesson()`, `fetchRemoteLessons()` (Supabase), `uploadLesson()` |
| `QuizRepository` | `getQuizzesByLesson(lessonId)`, `getQuizById()`, `getQuestionsByQuiz(quizId)`, `saveQuiz()`, `saveQuestion()`, `saveQuestions()`, `deleteQuiz()` |
| `ProgressRepository` | `getProgressByStudent(studentId)`, `getProgressForLesson(studentId, lessonId)`, `saveProgress()`, `updateProgress()`, `getPendingSyncProgress()`, `getOverallProgress(studentId)` |
| `DownloadRepository` | `getDownloadsByStudent()`, `getDownloadForLesson()`, `saveDownload()`, `updateDownload()`, `deleteDownload()`, `getCompletedDownloads()` |

#### Student ViewModels

| ViewModel | Key Responsibilities |
|---|---|
| `LessonViewModel` | `loadLessons()`, `loadLessonsBySubject(subject)`, `selectLesson()`, `clearSelection()`; state: `_lessons`, `_selectedLesson`, `_selectedSubject` |
| `QuizViewModel` | Full quiz state machine: `loadQuiz(lessonId)`, `selectAnswer(questionIndex, optionIndex)`, `nextQuestion()`, `previousQuestion()`, `submitQuiz()` → computes `scorePercent`, `passed`, `answeredCount`; `resetQuiz()` |
| `ProgressViewModel` | `loadProgress(studentId)`, `updateLessonProgress({studentId, lessonId, progressPercent, quizScore, timeSpentMinutes})` — upsert with `SyncStatus.pendingUpload`; `overallProgress` (average) |
| `DownloadViewModel` | `loadDownloads()`, `startDownload({lessonId, studentId, videoUrl})`, `getAvailableStorage()`, `getProgress(lessonId)`, `totalStorageUsed` |
| `ProgressExportViewModel` | `exportProgressCsv(studentId)` — joins progress + lessons from SQLite → writes CSV to app documents dir with summary section |

#### Student Views

| View | Description |
|---|---|
| `StudentDashboardView` | 4-tab `NavigationBar`: **Home** (welcome card, quick stats, recent lessons) · **Lessons** · **Progress** · **Downloads** |
| `StudentLessonsView` | `RefreshIndicator` + `ListView`; lesson cards with subject chip (color-coded), duration badge |
| `StudentQuizView` | `LinearProgressIndicator` for question progress; A/B/C/D option tiles with highlight on selection; Previous/Next/Submit navigation; `_QuizResultView` shows score %, pass/fail chip, correct count, Try Again / Continue buttons |
| `StudentProgressView` | `CircularProgressIndicator` for overall progress; per-lesson progress list |
| `StudentDownloadsView` | Download list with per-file progress and storage summary |

### 6.5 Teacher Layer

#### Teacher Repositories (SQLite via DatabaseHelper)

| Repository | CRUD Methods |
|---|---|
| `TeacherLessonRepository` | `getLessonsByTeacher(teacherId)`, `createLesson()`, `updateLesson()`, `deleteLesson()`, `publishLesson(id)` — sets `is_published=1` |
| `QuizCreatorRepository` | `getQuizzesByTeacher(teacherId)`, `createQuiz()`, `updateQuiz()`, `deleteQuiz()`, `addQuestion()`, `deleteQuestion()`, `getQuestionsByQuiz(quizId)` |
| `SessionRepository` | `getSessionsByTeacher()`, `getUpcomingSessions()` (scheduledAt > now && !isCompleted), `createSession()`, `updateSession()`, `deleteSession()`, `completeSession(id)` |
| `StudentMonitorRepository` | `getStudentsByTeacher(teacherId)`, `getStudentProgress(studentId)`, `getStudentById(id)` |
| `AnnouncementRepository` | `getAnnouncements()` (active only), `getAnnouncementsByAuthor(authorId)`, `createAnnouncement()`, `deleteAnnouncement()` |

#### Teacher ViewModels

| ViewModel | Key Responsibilities |
|---|---|
| `TeacherLessonViewModel` | `loadLessons(teacherId)`, `createLesson()`, `updateLesson()`, `publishLesson(lessonId)`, `deleteLesson(lessonId)`; reactive list management |
| `QuizCreatorViewModel` | `loadQuizzes(teacherId)`, `loadQuestions(quizId)`, `createQuiz()`, `addQuestion()`, `deleteQuiz()` |
| `SessionViewModel` | `loadSessions(teacherId)`, `createSession()`, `completeSession(sessionId)`, `deleteSession(sessionId)`; maintains separate `_upcomingSessions` list automatically |
| `StudentMonitorViewModel` | `loadStudents(teacherId)`, `viewStudentProgress(studentId)` → fetches `StudentModel` + `List<ProgressModel>`, `clearSelection()` |
| `AnnouncementViewModel` | `loadAnnouncements({authorId?})`, `createAnnouncement()`, `deleteAnnouncement()` |
| `VideoUploadViewModel` | `uploadLessonVideo({lessonId, videoBytes, fileName})` + `uploadLessonMaterial(...)` via `SupabaseStorageService`; exposes `isUploading`, `uploadProgress` (0.0–1.0), `uploadedUrl`, `errorMessage`; `reset()` |

#### Teacher Views

| View | Description |
|---|---|
| `TeacherDashboardView` | 5-tab `NavigationBar`: **Home** (welcome, 2×2 quick-action grid: New Lesson / Create Quiz / Schedule / Announce, overview stats) · **Lessons** · **Students** · **Sessions** · **Announce** |
| `TeacherLessonsView` | Lists teacher's lessons; FAB opens `TeacherLessonCreateView` |
| `TeacherLessonCreateView` | Full create form: title, description, subject, grade level, duration; file pickers for video (`FileType.video`) and material (PDF/DOC/PPT); real-time upload progress bar via `VideoUploadViewModel`; on submit creates `LessonModel(isPublished: false)` → `TeacherLessonViewModel.createLesson()` |
| `TeacherSessionsView` | Upcoming + past sessions list; FAB for creating new session |
| `TeacherStudentsView` | Assigned students list with progress data drill-down |
| `TeacherAnnouncementsView` | Active announcements list; FAB for creating new announcement |

### 6.6 Sync ViewModel

`SyncViewModel` (`ChangeNotifier`):

| Method | Description |
|---|---|
| `syncAll()` | Push: reads all SQLite records with `syncStatus='pendingUpload'` → upserts to Supabase. Pull: fetches lessons/quizzes/announcements from Supabase → writes to SQLite |
| `syncProgress()` | Push only student progress records marked `pendingUpload` |
| `isSyncing` | `bool` state exposed to UI |
| `_lastSyncTime` | `DateTime?` of last successful sync |

---

## 7. Database Schema

### 7.1 Supabase (PostgreSQL)

#### `users`
```sql
id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
email TEXT NOT NULL UNIQUE
full_name TEXT NOT NULL
role TEXT NOT NULL CHECK (IN ('student','teacher','admin'))
profile_picture_url TEXT
als_center_id UUID REFERENCES als_centers(id)
is_active BOOLEAN DEFAULT TRUE
email_verified BOOLEAN DEFAULT FALSE
teacher_verified BOOLEAN DEFAULT FALSE
-- Student demographic fields:
first_name TEXT, last_name TEXT, student_id_number TEXT
date_of_birth DATE, age INT, phone_number TEXT
occupation TEXT, last_school_attended TEXT, last_year_attended TEXT
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `lessons`
```sql
id UUID PRIMARY KEY
title TEXT, description TEXT, subject TEXT, grade_level TEXT
video_url TEXT, study_guide_url TEXT, thumbnail_url TEXT
teacher_id TEXT, duration_minutes INT, order_index INT DEFAULT 0
is_published BOOLEAN DEFAULT FALSE
sync_status TEXT DEFAULT 'synced'
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `quizzes`
```sql
id UUID PRIMARY KEY
lesson_id TEXT, title TEXT, description TEXT
time_limit_minutes INT DEFAULT 30
passing_score INT DEFAULT 75
order_index INT
is_published BOOLEAN DEFAULT FALSE
sync_status TEXT DEFAULT 'synced'
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `questions`
```sql
id UUID PRIMARY KEY
quiz_id TEXT, question_text TEXT
question_type TEXT DEFAULT 'multiple_choice'
options JSONB, correct_answer TEXT
order_index INT, points INT DEFAULT 1
sync_status TEXT DEFAULT 'synced'
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `progress`
```sql
id UUID PRIMARY KEY
student_id TEXT, lesson_id TEXT, quiz_id TEXT
progress_percent DOUBLE PRECISION DEFAULT 0
quiz_score INT, time_spent_minutes INT
sync_status TEXT DEFAULT 'synced'
last_accessed_at TIMESTAMPTZ
UNIQUE (student_id, lesson_id)
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `sessions`
```sql
id UUID PRIMARY KEY
teacher_id TEXT, title TEXT, description TEXT, location TEXT
scheduled_at TIMESTAMPTZ, duration_minutes INT DEFAULT 60
status TEXT DEFAULT 'scheduled'
sync_status TEXT DEFAULT 'synced'
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `announcements`
```sql
id UUID PRIMARY KEY
teacher_id TEXT, title TEXT, message TEXT
target JSONB, is_pinned BOOLEAN DEFAULT FALSE
sync_status TEXT DEFAULT 'synced'
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `als_centers`
```sql
id UUID PRIMARY KEY
name TEXT, address TEXT, region TEXT, contact_number TEXT
head_teacher_id UUID REFERENCES users(id)
is_active BOOLEAN DEFAULT TRUE
created_at TIMESTAMPTZ
```

#### `students`
```sql
id UUID PRIMARY KEY
user_id TEXT UNIQUE
learner_reference_number TEXT UNIQUE CHECK (~ '^\d{12}$')
student_id_number TEXT, grade_level TEXT
enrollment_date DATE, guardian_name TEXT, guardian_contact TEXT
date_of_birth DATE, age INT, occupation TEXT
last_school_attended TEXT, last_year_attended TEXT
als_center_id UUID REFERENCES als_centers(id)
is_active BOOLEAN DEFAULT TRUE
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `teachers`
```sql
id UUID PRIMARY KEY
user_id TEXT UNIQUE
als_center_id UUID REFERENCES als_centers(id)
employee_id TEXT UNIQUE, specialization TEXT
assigned_student_ids TEXT[] DEFAULT '{}'
is_active BOOLEAN DEFAULT TRUE
created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
```

#### `audit_logs`
```sql
id UUID PRIMARY KEY
performed_by UUID REFERENCES users(id) ON DELETE SET NULL
action TEXT NOT NULL   -- e.g. 'approve_teacher', 'delete_user', 'change_role'
target_user_id UUID
details TEXT
created_at TIMESTAMPTZ
-- RLS: insert/read only for users with role='admin'
```

### 7.2 Database Triggers & Functions

| Name | Type | Purpose |
|---|---|---|
| `update_updated_at_column()` | Trigger Function | Auto-sets `updated_at = NOW()` on every UPDATE across all tables |
| `validate_user_email()` | Trigger Function | Validates `full_name` length ≥ 2, `role` is one of the 3 valid values |
| `validate_student_lrn()` | Trigger Function | Ensures LRN is exactly 12 digits (`^\d{12}$`) |
| `current_user_role()` | SECURITY DEFINER Function | Returns `role` for `auth.uid()` without triggering RLS — prevents infinite recursion in policy checks |
| `handle_new_auth_user()` | Trigger on `auth.users` INSERT | Auto-inserts row into `public.users` using `user_metadata` passed during Supabase Auth sign-up |

### 7.3 Row Level Security Policies

| Table | Student | Teacher | Admin |
|---|---|---|---|
| `users` | Read/update own row | Read/update own row | Read all (via `current_user_role()`) |
| `lessons` | Read `is_published=true` | Read/write own (`teacher_id = auth.uid()`) | All |
| `quizzes` | Read published | Read/write own | All |
| `progress` | Read/write own (`student_id = auth.uid()`) | Read their students' | All |
| `sessions` | Read | CRUD own | All |
| `announcements` | Read (authenticated) | CRUD own | All |
| `als_centers` | Read | Read | All |
| `students` | Read/update own | Read theirs | All |
| `teachers` | Read | Read | All |
| `audit_logs` | None | None | Insert/Read only (`current_user_role()`) |

### 7.4 SQLite Local Schema (sqflite)

Mirrors the Supabase schema but uses **camelCase** column names for legacy compatibility. All `fromMap()` / `toMap()` methods handle both naming conventions.

| Table | Notable Columns |
|---|---|
| `users` | `fullName`, `profilePictureUrl`, `alsCenterId`, `isActive` + all student fields |
| `lessons` | `videoUrl`, `studyGuideUrl`, `teacherId`, `durationMinutes`, `isPublished` (int 0/1), `orderIndex`, `syncStatus` |
| `quizzes` | `lessonId`, `timeLimitMinutes`, `passingScore`, `totalQuestions`, `isPublished` |
| `questions` | `quizId`, `questionText`, `options` (pipe `\|\|\|` delimited), `correctOptionIndex`, `orderIndex` |
| `student_progress` | `studentId`, `lessonId`, `quizId`, `progressPercent`, `quizScore`, `timeSpentMinutes`, `syncStatus`, `lastAccessedAt` |
| `sessions` | `teacherId`, `scheduledAt`, `durationMinutes`, `studentIds` (comma-delimited), `isCompleted` (int) |
| `downloads` | `lessonId`, `studentId`, `localFilePath`, `downloadProgress`, `status`, `fileSizeBytes` |
| `announcements` | `authorId`, `targetRole`, `alsCenterId`, `isActive` (int) |
| `centers` | `contactNumber`, `headTeacherId`, `isActive` (int) |

### 7.5 Drift ORM Schema (`als_local.sqlite`)

| Table | Purpose |
|---|---|
| `Users` | Full user profile cache for auth state; `upsertUser()` called on every sign-in |
| `SyncQueue` | Queue of all offline operations (insert/update/delete); tracks `status` (pending→syncing→synced/failed), `retryCount`, `lastAttemptedAt`, `payload` (JSON) |

---

## 8. CRUD Operations

### Admin Web

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| Users | `bulkImportUsers()` batch upsert | `loadUsers()` with search + role filter | `toggleUserActive()`, `approveTeacher()`, `revokeTeacher()`, `changeRole()` | — |
| Lessons | — | `loadContent()` | `togglePublish(id)` | `deleteLesson(id)` |
| Quizzes | — | loaded with lessons | `toggleQuizPublish(id)` | `deleteQuiz(id)` |
| ALS Centers | `createCenter()` | `loadCenters()` | `updateCenter()` | `deleteCenter(id)` |
| Audit Logs | `_logAudit(adminId, action, targetId, details)` | `loadAuditLogs()` | — | — |

### Mobile App — Student

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| Lessons | `saveLesson()` (from sync) | `getLocalLessons()`, `getLessonsBySubject()`, `fetchRemoteLessons()` | — | `deleteLesson()` |
| Quizzes | `saveQuiz()` (from sync) | `getQuizzesByLesson()` | — | `deleteQuiz()` |
| Questions | `saveQuestion()` (from sync) | `getQuestionsByQuiz()` | — | — |
| Progress | `saveProgress()` (new record) | `getProgressByStudent()`, `getProgressForLesson()`, `getPendingSyncProgress()` | `updateProgress()` (marks `pendingUpload`) | — |
| Downloads | `saveDownload()` | `getDownloadsByStudent()`, `getDownloadForLesson()`, `getCompletedDownloads()` | `updateDownload()` | `deleteDownload()` |

### Mobile App — Teacher

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| Lessons | `createLesson()` + optional Supabase Storage upload | `getLessonsByTeacher()` | `updateLesson()`, `publishLesson()` | `deleteLesson()` |
| Quizzes | `createQuiz()` | `getQuizzesByTeacher()` | `updateQuiz()` | `deleteQuiz()` |
| Questions | `addQuestion()` | `getQuestionsByQuiz()` | — | `deleteQuestion()` |
| Sessions | `createSession()` | `getSessionsByTeacher()`, `getUpcomingSessions()` | `completeSession()` | `deleteSession()` |
| Announcements | `createAnnouncement()` | `getAnnouncements()`, `getAnnouncementsByAuthor()` | — | `deleteAnnouncement()` |

### backend_services (Generic Layer)

| Operation | Method |
|---|---|
| Create | `addDocument(table, data)` |
| Read one | `getDocument(table, id)` |
| Read many | `getCollection(table, ...)` / `queryCollection(table, filters, ...)` |
| Update | `updateDocument(table, id, data)` |
| Delete | `deleteDocument(table, id)` |

---

## 9. User Roles & Purposes

### Student
**Platform**: Mobile (Android/iOS)  
**Authentication**: Email+password, Google OAuth, Biometric (fingerprint/Face ID)  
**Registration**: Full demographic form including Learner Reference Number (12-digit), date of birth, occupation, last school attended

**Capabilities**:
- Browse and read published lessons (offline-capable)
- Filter lessons by subject
- Take quizzes with a full state machine (select answers, navigate, submit, view score)
- Track per-lesson progress percentage and quiz scores
- Export progress report as CSV
- Download lesson videos/materials for offline use
- Monitor available device storage
- Auto-sync progress to cloud when back online

### Teacher
**Platform**: Mobile (Android/iOS)  
**Authentication**: Email+password, Google OAuth, Biometric  
**Registration**: Basic form (name, email, phone); requires **admin approval** before dashboard access

**Capabilities**:
- Create lessons with title, description, subject, grade level, duration
- Upload lesson video (via Supabase Storage, with real-time progress bar)
- Upload lesson materials (PDF, DOC, PPT)
- Publish/unpublish lessons for students
- Create quizzes and add multiple-choice questions
- Schedule teaching sessions (date, time, location, invite students)
- Mark sessions as completed
- Send announcements to students
- View assigned students' profiles and individual progress data

### Admin
**Platform**: Web browser  
**Authentication**: Email+password only (no Google OAuth, no biometric, no mobile app access)

**Capabilities**:
- View aggregate system metrics (users, lessons, quizzes, progress, centers)
- Approve or revoke teacher accounts (`teacher_verified` flag)
- Activate/deactivate any user account
- Change user roles
- Bulk-import users via CSV
- View full admin audit log (who did what, when, to whom)
- Publish/unpublish or delete any lesson or quiz
- Full CRUD on ALS centers (name, address, region, contact info, head teacher)
- View analytics dashboard with active user count and average student progress
- All actions are logged to `audit_logs` table

---

## 10. Layer Connections & Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                         Supabase Cloud                           │
│                                                                  │
│  auth.users ──[handle_new_auth_user trigger]──► public.users     │
│                                                                  │
│  Tables: users · lessons · quizzes · questions · progress        │
│          sessions · announcements · als_centers · students       │
│          teachers · audit_logs                                   │
│                                                                  │
│  Storage Buckets: lesson-videos · lesson-materials               │
│                   profile-pictures                               │
│                                                                  │
│  RLS: per-table policies enforced by current_user_role()         │
└─────────────────────────┬────────────────────────────────────────┘
                          │ supabase_flutter SDK
           ┌──────────────┴──────────────┐
           │       backend_services      │
           │  SupabaseAuthService        │
           │  SupabaseDatabaseService    │
           │  SupabaseStorageService     │
           │  SyncService                │
           └────────┬────────────────────┘
                    │ local path dependency
         ┌──────────┴──────────────┐
         │                         │
  ┌──────▼──────┐         ┌────────▼────────────────────────────┐
  │  admin_web  │         │           mobile_app                │
  │             │         │                                     │
  │ Calls       │         │  ┌─────────────────────────────┐   │
  │ Supabase    │         │  │  Drift ORM (als_local.sqlite)│   │
  │ directly    │         │  │  · Users table (auth cache)  │   │
  │ for most    │         │  │  · SyncQueue table           │   │
  │ operations  │         │  └─────────────────────────────┘   │
  │             │         │  ┌─────────────────────────────┐   │
  │ Providers:  │         │  │  sqflite (als_study_..db)   │   │
  │ 5 ViewModels│         │  │  11 tables (primary store)  │   │
  └─────────────┘         │  └─────────────────────────────┘   │
                          │  student/ + teacher/ + shared/      │
                          └─────────────────────────────────────┘
                                         │
                          ┌──────────────┘
                          │
                  ┌───────▼─────────┐
                  │   shared_core   │
                  │  (Pure Dart)    │
                  │  11 Models      │
                  │  5 Enums        │
                  │  3 Constants    │
                  │  3 Utils        │
                  └─────────────────┘
```

### Mobile App Data Flow

```
User Action
    │
    ▼
ViewModel.method()
    │
    ▼
Repository.query()  ──────────────────────► SQLite (primary store)
    │                                            │
    │ (if online + needed)                       │ (SyncViewModel.syncAll())
    ▼                                            │
SupabaseDatabaseService / StorageService ◄───────┘
    │
    ▼
Supabase Cloud
```

### Auth State Flow

```
App Start
    │
    ▼
AuthViewModel.initState()
    │
    ├── Supabase.auth.currentSession? ──yes──► getCurrentUserModel()
    │                                               │
    │                                               ▼
    │                                        Drift.upsertUser()
    │                                               │
    │                                               ▼
    │                                        Route by UserRole
    │
    └── no ──► RoleSelectionView
                    │
                    ▼
              LoginView / RegistrationView
                    │
                    ▼ (after auth)
              EmailVerificationView
                    │ (verified)
                    ▼
              [Teacher] TeacherPendingApprovalView → (teacher_verified=true)
                    │
                    ▼
              BiometricSetupView (optional)
                    │
                    ▼
              StudentDashboardView / TeacherDashboardView
```

---

## 11. Offline-First Sync System

Every data record has a `syncStatus` field (from `SyncStatus` enum):

| Status | Meaning |
|---|---|
| `synced` | Record matches cloud; no action needed |
| `pendingUpload` | Modified locally; needs to be pushed to Supabase |
| `pendingDownload` | Available on cloud; not yet fetched locally |
| `syncing` | Currently being synced |
| `error` | Last sync attempt failed |

**Sync process** (`SyncViewModel.syncAll()`):
1. **Push**: Query SQLite for all records with `syncStatus = 'pendingUpload'` → upsert to Supabase → mark `synced`
2. **Pull**: Fetch lessons, quizzes, announcements from Supabase → save to SQLite → mark `synced`

**Retry logic** (`SyncService.performSyncWithRetry()`):
- Up to 5 retries
- Delay = `2^attempt` seconds + random jitter (exponential backoff)
- Tracks `_consecutiveFailures`; resets counter on success

**Conflict resolution**: Last-write-wins based on `updated_at` timestamp — whichever record (local or remote) has the later `updated_at` is kept.

**Offline queue** (Drift `SyncQueue` table):
- All write operations are queued here when offline
- Each entry: `entityType`, `entityId`, `operation` (insert/update/delete), `payload` (JSON), `status`, `retryCount`, `lastAttemptedAt`
- Processed on next `syncAll()` call

---

## 12. Authentication Flows

### Student Registration
```
StudentRegistrationView.submit()
    → AuthViewModel.registerStudent(email, password, ...demographics)
        → SupabaseAuthService.registerStudent()
            → supabase.auth.signUp(data: {user_metadata: {...all fields}})
            → DB trigger handle_new_auth_user() → inserts into public.users
        → AuthViewModel sets needsEmailVerification = true
    → Navigate to EmailVerificationView
        → Poll checkEmailVerified() every 3s
        → On verified → BiometricSetupView → StudentDashboardView
```

### Teacher Registration
```
TeacherRegistrationView.submit()
    → AuthViewModel.registerTeacher(email, password, firstName, lastName, phone)
        → SupabaseAuthService.registerTeacher()
        → AuthViewModel sets needsEmailVerification = true
    → EmailVerificationView → on verified → TeacherPendingApprovalView
        → Poll checkEmailVerified()+teacher_verified every 10s
        → Admin approves in admin_web (UserManagementViewModel.approveTeacher())
            → sets teacher_verified = true in public.users
        → Poll detects → navigate to TeacherDashboardView
```

### Google Sign-In
```
LoginView "Sign in with Google"
    → GoogleSignIn().signIn()
    → .authentication.idToken
    → supabase.auth.signInWithIdToken(provider: google, idToken: ...)
    → AuthViewModel.signIn() → route by role
```

### Biometric Login
```
LoginView (biometric icon shown if isBiometricEnabled)
    → AuthViewModel.biometricAutoFill()
        → BiometricService.authenticate()
        → SecureCredentialStorage.getCredentials()
        → AuthViewModel.signIn(email, password)
```

---

## 13. Storage Buckets

| Bucket | Path Pattern | Content |
|---|---|---|
| `lesson-videos` | `lessons/{lessonId}/{fileName}` | Teacher-uploaded lesson videos |
| `lesson-materials` | `lessons/{lessonId}/{fileName}` | PDFs, DOCs, PPTs for lessons |
| `profile-pictures` | `profile_pictures/{userId}` | User profile images |

---

## 14. Dependencies

### shared_core
```yaml
intl: ^0.19.0       # Date formatting
meta: ^1.9.0        # @immutable, @required annotations
```

### backend_services
```yaml
shared_core: path: ../shared_core
supabase_flutter: ^2.5.0
connectivity_plus: ^6.1.4
path: ^1.9.1
```

### admin_web
```yaml
shared_core: path: ../shared_core
backend_services: path: ../backend_services
supabase_flutter: ^2.5.0
provider: ^6.1.2
intl: ^0.19.0
```

### mobile_app
```yaml
shared_core: path: ../shared_core
backend_services: path: ../backend_services
provider: ^6.1.2            # State management
supabase_flutter: ^2.5.0    # Supabase
google_sign_in: ^6.3.0      # Google OAuth
flutter_dotenv: ^5.1.0      # Environment config (.env)
sqflite: ^2.4.2             # SQLite ORM
path: ^1.9.1
drift: ^2.16.0              # Typed ORM (SyncQueue + Users cache)
drift_flutter: ^0.1.0
local_auth: ^2.3.0          # Biometric auth
flutter_secure_storage: ^9.2.2  # Encrypted credential storage
shared_preferences: ^2.3.1
uuid: ^4.4.0                # UUID generation
video_player: ^2.9.5
file_picker: ^8.0.0+1
path_provider: ^2.1.5
connectivity_plus: ^6.1.4
intl: ^0.19.0
```

---

## 15. Known Issues / TODOs

| # | Location | Issue | Status |
|---|---|---|---|
| 1 | `DashboardScreen` | Biometric setup UI flow is partially implemented | ⚠️ WIP |
| 2 | `admin_web` | Batch user import CSV validation could be more robust | ⚠️ WIP |
| 3 | `Supabase` | Storage policies for profile pictures need refinement | ⚠️ WIP |

---

## 16. Quick Start

```bash
# 1. Install Flutter SDK >= 3.22.0

# 2. Install all package dependencies
cd ALS-LMS/packages/shared_models && flutter pub get
cd ../shared_services && flutter pub get
cd ../shared_ui && flutter pub get
cd ../../apps/admin_web && flutter pub get
cd ../student_phone && flutter pub get

# 3. Configure environment
cp .env.example .env
# Fill in: SUPABASE_URL and SUPABASE_ANON_KEY

# 4. Run mobile app
cd ALS-LMS/apps/student_phone
flutter run

# 5. Run admin web
cd ALS-LMS/apps/admin_web
flutter run -d chrome
```

See [docs/SETUP.md](docs/SETUP.md) for detailed developer setup, Supabase project configuration, and Google OAuth setup.
