# ALS Study Companion — How-To Guide

> Quick reference for understanding and setting up this project.
> Full details: [`analysis.md`](./analysis.md) · [`setup.md`](./setup.md)

---

## What Is This App?

An **offline-first Learning Management System (LMS)** for the Philippine ALS program.

| App | Who Uses It | How to Run |
|---|---|---|
| `mobile_app` | Students & Teachers | `flutter run` (Android/iOS) |
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
| §4 Packages | Learn what `shared_core`, `backend_services`, `shared_ui` do |
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
ALS-LMS/apps/mobile_app/.env
ALS-LMS/apps/admin_web/.env
```
Both files contain:
```env
SUPABASE_URL=<value from owner>
SUPABASE_ANON_KEY=<value from owner>
```

**4. Install Flutter dependencies** — order matters!
```powershell
cd ALS-LMS\packages\shared_core  && flutter pub get
cd ..\backend_services               && flutter pub get
cd ..\shared_ui                     && flutter pub get
cd ..\..\apps\admin_web             && flutter pub get
cd ..\mobile_app                 && flutter pub get
```

**5. Install Node dependencies** (from repo root)
```powershell
cd ..\..\..\
npm install
```

**6. Run the apps**
```powershell
# Mobile app (student & teacher)
cd ALS-LMS\apps\mobile_app
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

## Supabase Setup & Database Work

### Access the Dashboard

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard) and sign in
2. Open the project — Project ID: **`trixvamgvaihvuqpyjwc`**
3. Ask the **project owner (Dave)** to invite you:
   - Supabase Dashboard → Project Settings → Team → Invite Member → enter your email

> You can run the app with just the `.env` keys. Supabase dashboard access is only needed if you want to create/edit tables, run SQL, or manage storage.

---

### Run Existing Migrations

All migrations live in `supabase/migrations/`. To apply them to the cloud project, run them in order via the Supabase SQL Editor:

1. Supabase Dashboard → **SQL Editor** → New Query
2. Open each file from `supabase/migrations/` (oldest to newest) and paste + run:

| Order | File |
|---|---|
| 1 | `20260301_base_users_table.sql` |
| 2 | `20260309_comprehensive_schema.sql` |
| 3 | `20260310_missing_tables.sql` |
| 4 | `20260311_fix_schema_and_policies.sql` |
| 5 | `20260312_fix_schema_issues.sql` |
| 6 | `20260321_fix_profile_storage_policies.sql` |
| 7 | `20260414_add_missing_tables.sql` |
| 8 | `20260415_rls_policies_fixed.sql` |
| 9 | `20260416_enable_rls.sql` |
| 10 | `20260416_fix_onboarding_and_metadata.sql` |

> **Note**: These are already applied to the live project. Only run them if setting up a brand-new Supabase project from scratch.

---

### Create a New Table

**Option 1 — SQL Editor (recommended for complex tables)**

1. Supabase Dashboard → SQL Editor → New Query
2. Write your SQL, for example:
   ```sql
   CREATE TABLE IF NOT EXISTS public.feedback (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     student_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
     message TEXT NOT NULL,
     created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- Auto-update timestamp
   CREATE TRIGGER update_feedback_updated_at
     BEFORE UPDATE ON public.feedback
     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
   ```
3. Click **Run**

**Option 2 — Table Editor (GUI, simpler)**

1. Supabase Dashboard → Table Editor → New Table
2. Fill in table name, columns, types, and constraints via the UI
3. Click **Save**

---

### Add Row Level Security (RLS) to a New Table

Every new table **must have RLS enabled** or all data will be publicly readable/writable.

```sql
-- 1. Enable RLS on your new table
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- 2. Add policies (examples)

-- Students can only read/write their own feedback
CREATE POLICY "Students can insert own feedback"
  ON public.feedback FOR INSERT
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "Students can read own feedback"
  ON public.feedback FOR SELECT
  USING (student_id = auth.uid());

-- Admins can read everything
CREATE POLICY "Admins can read all feedback"
  ON public.feedback FOR SELECT
  USING (current_user_role() = 'admin');
```

> The `current_user_role()` function already exists in this project — use it for role-based policies to avoid RLS recursion.

---

### Save Your Migration

After creating a new table or policy, save it as a migration file so the team has a record:

1. Create a new file in `supabase/migrations/` with today's date:
   ```
   supabase/migrations/20260422_add_feedback_table.sql
   ```
2. Paste the SQL you ran into the file
3. Commit and push it:
   ```powershell
   git add supabase/migrations/
   git commit -m "feat(db): add feedback table with RLS"
   git push private main
   ```

---

### Supabase CLI (Optional — for local dev)

The CLI is already installed via `npm install`. Use it to manage migrations locally:

```powershell
# From the repo root

# List all migrations
npx supabase migration list

# Create a new blank migration file
npx supabase migration new add_feedback_table

# Push local migrations to the live project (requires login)
npx supabase login
npx supabase db push
```

---

### Add a Storage Bucket (for file uploads)

1. Supabase Dashboard → Storage → New Bucket
2. Set a name (e.g., `student-submissions`)
3. Choose **Public** or **Private** access
4. Add storage policies in SQL Editor:
   ```sql
   -- Allow authenticated users to upload to their own folder
   CREATE POLICY "Students can upload own files"
     ON storage.objects FOR INSERT
     WITH CHECK (
       bucket_id = 'student-submissions' AND
       auth.uid()::text = (storage.foldername(name))[1]
     );
   ```

---

## Quick Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` path error | Run in the correct directory; packages before apps |
| `.env` not found | Check the file exists in `apps/mobile_app/` and `apps/admin_web/` |
| Google Sign-In fails | Send your SHA-1 to the repo owner (see above) |
| `flutter run -d chrome` fails | Run `flutter config --enable-web` first |
| Git push asks for password | Use a GitHub Personal Access Token (PAT), not your account password |
| `flutter doctor` errors | Run `flutter doctor --android-licenses` and accept all |
