-- Migration: Fix schema issues discovered during runtime testing.
--
-- Fixes applied:
--   1. Rename camelCase columns to snake_case on users table (if present).
--   2. Add missing columns to users table (is_active, als_center_id,
--      profile_picture_url) that the app expects but earlier migrations missed.
--   3. Fix validate_user_email() trigger — was referencing "fullName"
--      (camelCase quoted identifier) instead of full_name (snake_case).
--   4. Replace recursive RLS policies on public.users with a SECURITY DEFINER
--      helper function so admin checks no longer query the users table itself.
--   5. Ensure self-registration INSERT policy exists for newly signed-up users.
--   6. Add updated_at trigger on users table.

-- =============================================
-- 0. ENSURE HELPER FUNCTION EXISTS
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 1. RENAME CAMELCASE COLUMNS → SNAKE_CASE
--    (Only runs if the camelCase variant exists)
-- =============================================

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'createdAt'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'updatedAt'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "updatedAt" TO updated_at;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'fullName'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "fullName" TO full_name;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'isActive'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "isActive" TO is_active;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'profilePictureUrl'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "profilePictureUrl" TO profile_picture_url;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'alsCenterId'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "alsCenterId" TO als_center_id;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'emailVerified'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "emailVerified" TO email_verified;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'teacherVerified'
  ) THEN
    ALTER TABLE public.users RENAME COLUMN "teacherVerified" TO teacher_verified;
  END IF;
END $$;

-- =============================================
-- 2. ADD MISSING COLUMNS (idempotent)
-- =============================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_active            BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS als_center_id        TEXT,
  ADD COLUMN IF NOT EXISTS profile_picture_url  TEXT,
  ADD COLUMN IF NOT EXISTS email_verified       BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS teacher_verified     BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS first_name           TEXT,
  ADD COLUMN IF NOT EXISTS last_name            TEXT,
  ADD COLUMN IF NOT EXISTS student_id_number    TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth        DATE,
  ADD COLUMN IF NOT EXISTS age                  INTEGER,
  ADD COLUMN IF NOT EXISTS phone_number         TEXT,
  ADD COLUMN IF NOT EXISTS occupation           TEXT,
  ADD COLUMN IF NOT EXISTS last_school_attended TEXT,
  ADD COLUMN IF NOT EXISTS last_year_attended   TEXT;

-- Ensure created_at and updated_at columns exist with defaults
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- =============================================
-- 3. FIX validate_user_email() TRIGGER
--    Was using NEW."fullName" (camelCase) which doesn't exist.
--    Replace with NEW.full_name (snake_case).
-- =============================================

CREATE OR REPLACE FUNCTION validate_user_email()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email IS NULL OR NEW.email !~ '^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$' THEN
    RAISE EXCEPTION 'Invalid email format: %', NEW.email;
  END IF;
  IF NEW.full_name IS NULL OR LENGTH(TRIM(NEW.full_name)) < 2 THEN
    RAISE EXCEPTION 'Full name must be at least 2 characters';
  END IF;
  IF NEW.role NOT IN ('student', 'teacher', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', NEW.role;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-create triggers (idempotent)
DROP TRIGGER IF EXISTS validate_user_before_insert ON public.users;
CREATE TRIGGER validate_user_before_insert
  BEFORE INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION validate_user_email();

DROP TRIGGER IF EXISTS validate_user_before_update ON public.users;
CREATE TRIGGER validate_user_before_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION validate_user_email();

-- updated_at auto-set trigger
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 4. FIX RECURSIVE RLS ON public.users
--
--    Problem: policies like users_admin_select query public.users
--    from inside a policy ON public.users → infinite recursion.
--
--    Solution: A SECURITY DEFINER function that reads the role
--    directly, bypassing RLS.  Policies then call this function.
-- =============================================

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- Grant execute to authenticated and anon so PostgREST can call it
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon;

-- =============================================
-- 5. DROP OLD (RECURSIVE) POLICIES AND
--    RE-CREATE NON-RECURSIVE ONES
-- =============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop all existing user policies to start clean
DROP POLICY IF EXISTS users_select_self_or_admin   ON public.users;
DROP POLICY IF EXISTS users_update_self            ON public.users;
DROP POLICY IF EXISTS users_insert_admin_only      ON public.users;
DROP POLICY IF EXISTS users_select_own             ON public.users;
DROP POLICY IF EXISTS users_insert_own             ON public.users;
DROP POLICY IF EXISTS users_update_own             ON public.users;
DROP POLICY IF EXISTS users_admin_select           ON public.users;
DROP POLICY IF EXISTS users_admin_update           ON public.users;
DROP POLICY IF EXISTS users_admin_delete           ON public.users;

-- SELECT: users can read their own row; admins can read all
CREATE POLICY users_select_policy ON public.users FOR SELECT USING (
  auth.uid() = id
  OR current_user_role() = 'admin'
);

-- INSERT: users can insert their own record (self-registration)
CREATE POLICY users_insert_policy ON public.users FOR INSERT WITH CHECK (
  auth.uid() = id
);

-- UPDATE: users can update their own row; admins can update any
CREATE POLICY users_update_policy ON public.users FOR UPDATE USING (
  auth.uid() = id
  OR current_user_role() = 'admin'
);

-- DELETE: only admins
CREATE POLICY users_delete_policy ON public.users FOR DELETE USING (
  current_user_role() = 'admin'
);

-- =============================================
-- 6. FIX AUDIT_LOGS POLICIES (also recursive)
--    Replace inline subqueries with current_user_role()
-- =============================================

DROP POLICY IF EXISTS audit_logs_admin_select ON public.audit_logs;
DROP POLICY IF EXISTS audit_logs_admin_insert ON public.audit_logs;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'audit_logs') THEN
    EXECUTE '
      CREATE POLICY audit_logs_select_policy ON public.audit_logs FOR SELECT
      USING (current_user_role() = ''admin'')';
    EXECUTE '
      CREATE POLICY audit_logs_insert_policy ON public.audit_logs FOR INSERT
      WITH CHECK (current_user_role() = ''admin'')';
  END IF;
END $$;

-- =============================================
-- 7. FIX OTHER TABLE POLICIES THAT RECURSIVELY
--    QUERY public.users
-- =============================================

-- lessons
DROP POLICY IF EXISTS lessons_admin_select ON public.lessons;
DROP POLICY IF EXISTS lessons_admin_update ON public.lessons;
DROP POLICY IF EXISTS lessons_admin_delete ON public.lessons;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'lessons') THEN
    EXECUTE '
      CREATE POLICY lessons_admin_select ON public.lessons FOR SELECT
      USING (current_user_role() = ''admin'')';
    EXECUTE '
      CREATE POLICY lessons_admin_update ON public.lessons FOR UPDATE
      USING (current_user_role() = ''admin'')';
    EXECUTE '
      CREATE POLICY lessons_admin_delete ON public.lessons FOR DELETE
      USING (current_user_role() = ''admin'')';
  END IF;
END $$;

-- quizzes
DROP POLICY IF EXISTS quizzes_teacher_all ON public.quizzes;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'quizzes') THEN
    EXECUTE '
      CREATE POLICY quizzes_teacher_all ON public.quizzes FOR ALL
      USING (current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END $$;

-- questions
DROP POLICY IF EXISTS questions_teacher_all ON public.questions;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'questions') THEN
    EXECUTE '
      CREATE POLICY questions_teacher_all ON public.questions FOR ALL
      USING (current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END $$;

-- progress
DROP POLICY IF EXISTS progress_teacher_select ON public.progress;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'progress') THEN
    EXECUTE '
      CREATE POLICY progress_teacher_select ON public.progress FOR SELECT
      USING (current_user_role() IN (''teacher'', ''admin''))';
  END IF;
END $$;

-- als_centers
DROP POLICY IF EXISTS als_centers_admin_all ON public.als_centers;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'als_centers') THEN
    EXECUTE '
      CREATE POLICY als_centers_admin_all ON public.als_centers FOR ALL
      USING (current_user_role() = ''admin'')';
  END IF;
END $$;

-- students
DROP POLICY IF EXISTS students_teacher_select ON public.students;
DROP POLICY IF EXISTS students_admin_all      ON public.students;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'students') THEN
    EXECUTE '
      CREATE POLICY students_teacher_select ON public.students FOR SELECT
      USING (current_user_role() IN (''teacher'', ''admin''))';
    EXECUTE '
      CREATE POLICY students_admin_all ON public.students FOR ALL
      USING (current_user_role() = ''admin'')';
  END IF;
END $$;

-- teachers
DROP POLICY IF EXISTS teachers_admin_all ON public.teachers;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'teachers') THEN
    EXECUTE '
      CREATE POLICY teachers_admin_all ON public.teachers FOR ALL
      USING (current_user_role() = ''admin'')';
  END IF;
END $$;

-- storage policies (lesson-videos, lesson-materials) — only fix if objects exist
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'lesson_videos_teacher_insert') THEN
    DROP POLICY lesson_videos_teacher_insert ON storage.objects;
    EXECUTE '
      CREATE POLICY lesson_videos_teacher_insert ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = ''lesson-videos''
        AND current_user_role() IN (''teacher'', ''admin'')
      )';
  END IF;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'lesson_materials_teacher_insert') THEN
    DROP POLICY lesson_materials_teacher_insert ON storage.objects;
    EXECUTE '
      CREATE POLICY lesson_materials_teacher_insert ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = ''lesson-materials''
        AND current_user_role() IN (''teacher'', ''admin'')
      )';
  END IF;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- =============================================
-- 8. INDEXES (idempotent)
-- =============================================

CREATE INDEX IF NOT EXISTS idx_users_role       ON public.users (role);
CREATE INDEX IF NOT EXISTS idx_users_is_active  ON public.users (is_active);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON public.users (student_id_number)
  WHERE student_id_number IS NOT NULL;
