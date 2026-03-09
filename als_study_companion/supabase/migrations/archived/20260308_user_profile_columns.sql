-- ARCHIVED on 2026-03-09: superseded by 20260311_fix_schema_and_policies.sql
-- Original: als_study_companion/supabase/migrations/20260308_user_profile_columns.sql
-- This migration was made idempotent and then archived to avoid applying
-- redundant/overlapping schema changes. The authoritative fixes live
-- in the 20260311_* migrations.

-- Add student-specific and teacher-specific profile columns to the users table.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS first_name      TEXT,
  ADD COLUMN IF NOT EXISTS last_name       TEXT,
  ADD COLUMN IF NOT EXISTS student_id_number TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth   DATE,
  ADD COLUMN IF NOT EXISTS age             INTEGER,
  ADD COLUMN IF NOT EXISTS phone_number    TEXT,
  ADD COLUMN IF NOT EXISTS occupation      TEXT,
  ADD COLUMN IF NOT EXISTS last_school_attended TEXT,
  ADD COLUMN IF NOT EXISTS last_year_attended   TEXT;

-- Index on student_id_number for fast look-ups
CREATE INDEX IF NOT EXISTS idx_users_student_id ON public.users (student_id_number)
  WHERE student_id_number IS NOT NULL;

-- RLS: users can read their own row and teachers can read their assigned students
-- (assumes RLS is already enabled on users table; add if not)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their own record
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'users_select_own'
  ) THEN
    EXECUTE 'CREATE POLICY users_select_own ON public.users FOR SELECT USING (auth.uid()::text = id)';
  END IF;
END$$;

-- Allow authenticated users to insert their own record
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'users_insert_own'
  ) THEN
    EXECUTE 'CREATE POLICY users_insert_own ON public.users FOR INSERT WITH CHECK (auth.uid()::text = id)';
  END IF;
END$$;

-- Allow authenticated users to update their own record
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'users_update_own'
  ) THEN
    EXECUTE 'CREATE POLICY users_update_own ON public.users FOR UPDATE USING (auth.uid()::text = id)';
  END IF;
END$$;
