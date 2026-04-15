-- =============================================================================
-- Migration: Fix schema drift, RLS infinite recursion, and trigger bugs
-- Date: 2026-03-11
--
-- Fixes:
--   1. Rename camelCase users columns → snake_case (resolves "created_at does
--      not exist" error on the admin Users page)
--   2. Fix validate_user_email() trigger — used NEW."fullName" (quoted camelCase)
--      instead of NEW.full_name; this caused every INSERT to fail
--   3. Create current_user_role() SECURITY DEFINER helper to break the infinite
--      recursion in users RLS policies (resolves analytics "42P17" error)
--   4. Replace all recursive admin-check policies on users with non-recursive
--      versions that use current_user_role()
--   5. Rename audit_logs columns (admin_id→performed_by, target_id→target_user_id)
--      to match what the Dart viewmodel inserts; drop NOT NULL from performed_by
--   6. Add handle_new_auth_user() trigger on auth.users so the public.users
--      profile is created automatically (bypasses RLS timing issue when email
--      confirmation is enabled, preventing orphaned auth accounts)
-- =============================================================================

-- ============================================================
-- 1. RENAME CAMELCASE COLUMNS → SNAKE_CASE ON public.users
-- ============================================================

DO $$
BEGIN
  -- createdAt → created_at
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'createdAt'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "createdAt" TO created_at;
  END IF;

  -- updatedAt → updated_at
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'updatedAt'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "updatedAt" TO updated_at;
  END IF;

  -- fullName → full_name
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'fullName'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "fullName" TO full_name;
  END IF;

  -- isActive → is_active
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'isActive'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "isActive" TO is_active;
  END IF;

  -- profilePictureUrl → profile_picture_url
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'profilePictureUrl'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "profilePictureUrl" TO profile_picture_url;
  END IF;

  -- alsCenterId → als_center_id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'alsCenterId'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "alsCenterId" TO als_center_id;
  END IF;

  -- emailVerified → email_verified
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'emailVerified'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "emailVerified" TO email_verified;
  END IF;

  -- teacherVerified → teacher_verified
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'teacherVerified'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "teacherVerified" TO teacher_verified;
  END IF;

  -- profile_image → profile_picture_url (legacy alias from backend_services schema)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'profile_image'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'profile_picture_url'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN profile_image TO profile_picture_url;
  END IF;
END$$;

-- Ensure all expected snake_case columns exist (idempotent ADD IF NOT EXISTS).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS full_name         TEXT,
  ADD COLUMN IF NOT EXISTS is_active         BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS role              TEXT DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS als_center_id     TEXT,
  ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
  ADD COLUMN IF NOT EXISTS email_verified    BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS teacher_verified  BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS first_name        TEXT,
  ADD COLUMN IF NOT EXISTS last_name         TEXT,
  ADD COLUMN IF NOT EXISTS student_id_number TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth     DATE,
  ADD COLUMN IF NOT EXISTS age               INTEGER,
  ADD COLUMN IF NOT EXISTS phone_number      TEXT,
  ADD COLUMN IF NOT EXISTS occupation        TEXT,
  ADD COLUMN IF NOT EXISTS last_school_attended TEXT,
  ADD COLUMN IF NOT EXISTS last_year_attended   TEXT;

-- Rebuild index on student_id_number in case it was dropped
CREATE INDEX IF NOT EXISTS idx_users_student_id ON public.users (student_id_number)
  WHERE student_id_number IS NOT NULL;

-- ============================================================
-- 2. FIX validate_user_email() TRIGGER
--    Original referenced NEW."fullName" (camelCase quoted column)
--    which does not exist; every INSERT raised an exception.
-- ============================================================

CREATE OR REPLACE FUNCTION validate_user_email()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email IS NULL OR NEW.email !~ '^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$' THEN
    RAISE EXCEPTION 'Invalid email format: %', NEW.email;
  END IF;
  -- Use snake_case column full_name (was incorrectly "fullName" before)
  IF NEW.full_name IS NULL OR LENGTH(TRIM(NEW.full_name)) < 2 THEN
    RAISE EXCEPTION 'Full name must be at least 2 characters';
  END IF;
  IF NEW.role NOT IN ('student', 'teacher', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', NEW.role;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers so they use the fixed function
DROP TRIGGER IF EXISTS validate_user_before_insert ON public.users;
CREATE TRIGGER validate_user_before_insert
  BEFORE INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION validate_user_email();

DROP TRIGGER IF EXISTS validate_user_before_update ON public.users;
CREATE TRIGGER validate_user_before_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION validate_user_email();

-- ============================================================
-- 3. SECURITY DEFINER HELPER — breaks RLS recursion
-- ============================================================
-- Any policy on public.users that does:
--   EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
-- will recurse infinitely because the sub-SELECT also hits every users policy.
-- The SECURITY DEFINER function reads the row without going through RLS.

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid()
$$;

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon;

-- ============================================================
-- 4. REPLACE RECURSIVE RLS POLICIES ON public.users
-- ============================================================
-- Drop every policy that queries public.users from inside its own USING clause.

DROP POLICY IF EXISTS users_admin_select          ON public.users;
DROP POLICY IF EXISTS users_admin_update          ON public.users;
DROP POLICY IF EXISTS users_admin_delete          ON public.users;
DROP POLICY IF EXISTS users_select_own            ON public.users;
DROP POLICY IF EXISTS users_insert_own            ON public.users;
DROP POLICY IF EXISTS users_update_own            ON public.users;
DROP POLICY IF EXISTS users_select_self_or_admin  ON public.users;
DROP POLICY IF EXISTS users_update_self           ON public.users;

-- New, non-recursive policies:

-- Any authenticated user can read their own row; admins can read all rows.
CREATE POLICY users_select ON public.users FOR SELECT
  USING (
    auth.uid() = id
    OR public.current_user_role() = 'admin'
  );

-- A user can only insert their own row (auth uid must equal id).
CREATE POLICY users_insert ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- A user can update their own row; admins can update any row.
CREATE POLICY users_update ON public.users FOR UPDATE
  USING (
    auth.uid() = id
    OR public.current_user_role() = 'admin'
  );

-- Only admins can delete rows.
CREATE POLICY users_delete ON public.users FOR DELETE
  USING (public.current_user_role() = 'admin');

-- ============================================================
-- 5. FIX RECURSIVE POLICIES ON OTHER TABLES
--    (audit_logs, lessons, quizzes, questions, progress reference
--     public.users in their USING clauses — same recursion risk)
-- ============================================================

-- audit_logs
DROP POLICY IF EXISTS audit_logs_admin_select ON public.audit_logs;
DROP POLICY IF EXISTS audit_logs_admin_insert ON public.audit_logs;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='audit_logs') THEN
    EXECUTE '
      CREATE POLICY audit_logs_admin_select ON public.audit_logs FOR SELECT
      USING (public.current_user_role() = ''admin'')';
    EXECUTE '
      CREATE POLICY audit_logs_admin_insert ON public.audit_logs FOR INSERT
      WITH CHECK (public.current_user_role() = ''admin'')';
  END IF;
END$$;

-- lessons: drop recursive admin policies, recreate using helper
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='lessons') THEN
    -- drop old recursive admin policies
    EXECUTE 'DROP POLICY IF EXISTS lessons_admin_select ON public.lessons';
    EXECUTE 'DROP POLICY IF EXISTS lessons_admin_update ON public.lessons';
    EXECUTE 'DROP POLICY IF EXISTS lessons_admin_delete ON public.lessons';
    -- recreate
    EXECUTE '
      CREATE POLICY lessons_admin_select ON public.lessons FOR SELECT
      USING (public.current_user_role() IN (''admin'', ''teacher''))';
    EXECUTE '
      CREATE POLICY lessons_admin_update ON public.lessons FOR UPDATE
      USING (public.current_user_role() = ''admin'')';
    EXECUTE '
      CREATE POLICY lessons_admin_delete ON public.lessons FOR DELETE
      USING (public.current_user_role() = ''admin'')';
  END IF;
END$$;

-- quizzes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='quizzes') THEN
    EXECUTE 'DROP POLICY IF EXISTS quizzes_teacher_all ON public.quizzes';
    EXECUTE '
      CREATE POLICY quizzes_teacher_all ON public.quizzes FOR ALL
      USING (public.current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END$$;

-- questions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='questions') THEN
    EXECUTE 'DROP POLICY IF EXISTS questions_teacher_all ON public.questions';
    EXECUTE '
      CREATE POLICY questions_teacher_all ON public.questions FOR ALL
      USING (public.current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END$$;

-- progress
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='progress') THEN
    EXECUTE 'DROP POLICY IF EXISTS progress_teacher_select ON public.progress';
    EXECUTE '
      CREATE POLICY progress_teacher_select ON public.progress FOR SELECT
      USING (public.current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END$$;

-- storage objects
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='storage' AND table_name='objects') THEN
    EXECUTE 'DROP POLICY IF EXISTS lesson_videos_teacher_insert ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS lesson_materials_teacher_insert ON storage.objects';
    EXECUTE '
      CREATE POLICY lesson_videos_teacher_insert ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = ''lesson-videos'' AND
        public.current_user_role() IN (''teacher'', ''admin'')
      )';
    EXECUTE '
      CREATE POLICY lesson_materials_teacher_insert ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = ''lesson-materials'' AND
        public.current_user_role() IN (''teacher'', ''admin'')
      )';
  END IF;
END$$;

-- als_centers, students, teachers admin policies
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='als_centers') THEN
    EXECUTE 'DROP POLICY IF EXISTS als_centers_admin_all ON public.als_centers';
    EXECUTE '
      CREATE POLICY als_centers_admin_all ON public.als_centers FOR ALL
      USING (public.current_user_role() = ''admin'')';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='students') THEN
    EXECUTE 'DROP POLICY IF EXISTS students_teacher_select ON public.students';
    EXECUTE 'DROP POLICY IF EXISTS students_admin_all ON public.students';
    EXECUTE '
      CREATE POLICY students_teacher_select ON public.students FOR SELECT
      USING (public.current_user_role() IN (''teacher'', ''admin''))';
    EXECUTE '
      CREATE POLICY students_admin_all ON public.students FOR ALL
      USING (public.current_user_role() = ''admin'')';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='teachers') THEN
    EXECUTE 'DROP POLICY IF EXISTS teachers_admin_all ON public.teachers';
    EXECUTE '
      CREATE POLICY teachers_admin_all ON public.teachers FOR ALL
      USING (public.current_user_role() = ''admin'')';
  END IF;
END$$;

-- ============================================================
-- 6. FIX audit_logs COLUMN NAMES
--    Dart code sends: target_user_id, performed_by
--    Schema had:      target_id (TEXT), admin_id (TEXT NOT NULL)
-- ============================================================

DO $$
BEGIN
  -- admin_id → performed_by
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'audit_logs'
      AND column_name = 'admin_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'audit_logs'
      AND column_name = 'performed_by'
  ) THEN
    ALTER TABLE public.audit_logs RENAME COLUMN admin_id TO performed_by;
  END IF;

  -- target_id → target_user_id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'audit_logs'
      AND column_name = 'target_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'audit_logs'
      AND column_name = 'target_user_id'
  ) THEN
    ALTER TABLE public.audit_logs RENAME COLUMN target_id TO target_user_id;
  END IF;
END$$;

-- Add columns in case they were never created (fresh installs)
ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS performed_by   TEXT,
  ADD COLUMN IF NOT EXISTS target_user_id TEXT;

-- Drop NOT NULL constraint from performed_by (renamed from admin_id NOT NULL)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'audit_logs'
      AND column_name = 'performed_by'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.audit_logs ALTER COLUMN performed_by DROP NOT NULL;
  END IF;
END$$;

-- ============================================================
-- 7. AUTO-CREATE public.users PROFILE ON AUTH SIGNUP
--    Runs as SECURITY DEFINER so it bypasses RLS regardless
--    of whether the client has an active session.
--    Reads all profile fields from raw_user_meta_data so the
--    client can pass them in the signUp `data` map.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (
    id,
    email,
    full_name,
    role,
    first_name,
    last_name,
    student_id_number,
    phone_number,
    occupation,
    last_school_attended,
    last_year_attended,
    als_center_id,
    is_active,
    email_verified,
    teacher_verified,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
      NULLIF(
        concat_ws(
          ' ',
          NULLIF(NEW.raw_user_meta_data->>'first_name', ''),
          NULLIF(NEW.raw_user_meta_data->>'last_name',  '')
        ),
        ''
      ),
      split_part(NEW.email, '@', 1)
    ),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'student'),
    NULLIF(NEW.raw_user_meta_data->>'first_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'last_name',  ''),
    NULLIF(NEW.raw_user_meta_data->>'student_id_number', ''),
    NULLIF(NEW.raw_user_meta_data->>'phone_number', ''),
    NULLIF(NEW.raw_user_meta_data->>'occupation', ''),
    NULLIF(NEW.raw_user_meta_data->>'last_school_attended', ''),
    NULLIF(NEW.raw_user_meta_data->>'last_year_attended', ''),
    NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''),
    true,
    false,
    false,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
