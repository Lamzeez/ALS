-- Migration: Create base users table and essential helper functions
-- This is the FOUNDATIONAL migration - must run first!
-- Date: 2026-04-14

-- =============================================
-- 1. CREATE HELPER FUNCTION (needed by triggers)
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 2. CREATE USERS TABLE
-- This table stores user profiles for all roles (student, teacher, admin)
-- =============================================

CREATE TABLE IF NOT EXISTS public.users (
  id                UUID PRIMARY KEY,  -- Same as auth.users.id (linked by trigger)
  email             TEXT NOT NULL UNIQUE,
  full_name         TEXT NOT NULL,
  role              TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
  
  -- Profile fields
  first_name        TEXT,
  last_name         TEXT,
  student_id_number TEXT,
  date_of_birth     DATE,
  age               INTEGER,
  phone_number      TEXT,
  occupation        TEXT,
  last_school_attended TEXT,
  last_year_attended   TEXT,
  profile_picture_url TEXT,
  als_center_id     TEXT,
  
  -- Status flags
  is_active         BOOLEAN DEFAULT true,
  email_verified    BOOLEAN DEFAULT false,
  teacher_verified  BOOLEAN DEFAULT false,
  
  -- Audit timestamps
  created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 3. CREATE INDEXES
-- =============================================

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users (role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users (is_active);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON public.users (student_id_number)
  WHERE student_id_number IS NOT NULL;

-- =============================================
-- 4. CREATE UPDATED_AT TRIGGER
-- =============================================

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 5. BASIC RLS POLICIES FOR USERS TABLE
-- These will be enhanced in later migrations
-- =============================================

-- Users can read their own row
CREATE POLICY users_select_own ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Users can insert their own row (during signup)
CREATE POLICY users_insert_own ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own row
CREATE POLICY users_update_own ON public.users FOR UPDATE
  USING (auth.uid() = id);
