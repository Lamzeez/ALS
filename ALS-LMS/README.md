# ALS-LMS (Alternative Learning System - Learning Management System)

> **Offline-first, mastery-based Learning Management System** for the Philippine Department of Education's Alternative Learning System (ALS). Built with Flutter + Supabase.

## 🏗️ Architecture

This is a **monorepo** managed by [Melos](https://melos.invertase.dev/) containing:

| Directory | Description |
|-----------|-------------|
| `apps/student_phone/` | Android phone app for ALS learners (offline-first) |
| `apps/teacher_tablet/` | Tablet/web app for ALS teachers (SpeedGrader, CMS) |
| `apps/admin_web/` | Web portal for School Admins (analytics, LIS) |
| `packages/shared_models/` | Dart data classes shared across all apps |
| `packages/shared_services/` | Auth, sync, storage services |
| `packages/shared_ui/` | Common widgets and design system |
| `supabase/` | Database migrations, Edge Functions, seed data |

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x (stable channel)
- Dart 3.x
- Supabase CLI
- Melos (`dart pub global activate melos`)

### Setup
```bash
# Clone and bootstrap
git clone <repo-url>
cd ALS-LMS
cp .env.example .env  # Fill in your credentials
melos bootstrap

# Link Supabase
supabase link --project-ref pgfhypaqpzypjofbyugi

# Push migrations
supabase db push

# Run student app
cd apps/student_phone
flutter run
```

## 📱 Target Platforms
- **Primary:** Android Phone (Student App)
- **Secondary:** Android Tablet (Teacher App), Web (Admin Portal)

## 🔐 Security
- Row-Level Security (RLS) on all tables
- Role-based access: `student`, `teacher`, `school_admin`, `dev_admin`
- JWT token caching for offline auth
- Immutable audit logs with tamper prevention

## 📊 Key Features
- **Offline-First:** Full curriculum available without internet via SQLite
- **Mastery-Based:** Prerequisite module locking with mastery scores
- **Delta-Sync:** Efficient data synchronization when connectivity is available
- **SpeedGrader:** Teacher markup tool for student submissions
- **Heatmaps:** Geographic visualization of learner engagement
- **Kill Switch:** Remote device wipe via Firebase FCM
