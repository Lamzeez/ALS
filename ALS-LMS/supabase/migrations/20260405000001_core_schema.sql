-- ============================================================
-- Migration 001: Core Schema
-- Districts, Profiles, Cohorts, Enrollments
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. DISTRICTS - Regional administrative units
-- ============================================================
CREATE TABLE public.districts (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    region      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.districts IS 'DepEd administrative districts/divisions';

-- ============================================================
-- 2. PROFILES - Extends auth.users with ALS-specific fields
-- ============================================================
CREATE TYPE public.user_role AS ENUM ('student', 'teacher', 'school_admin', 'dev_admin');

CREATE TABLE public.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role            public.user_role NOT NULL DEFAULT 'student',
    lrn             TEXT UNIQUE,                          -- Learner Reference Number (students only)
    full_name       TEXT NOT NULL,
    email           TEXT,
    district_id     UUID REFERENCES public.districts(id),
    avatar_url      TEXT,
    device_id       TEXT,                                 -- For FCM kill-switch targeting
    phone_number    TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User profiles extending Supabase Auth with ALS-specific metadata';
COMMENT ON COLUMN public.profiles.lrn IS 'DepEd Learner Reference Number - unique per student';
COMMENT ON COLUMN public.profiles.device_id IS 'Firebase device token for remote wipe / kill switch';

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New User'),
        NEW.email,
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. COHORTS - Barangay-based learning groups
-- ============================================================
CREATE TABLE public.cohorts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    district_id     UUID NOT NULL REFERENCES public.districts(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    barangay        TEXT,
    coordinator_id  UUID REFERENCES public.profiles(id),
    academic_year   TEXT,                                 -- e.g., '2026-2027'
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.cohorts IS 'Barangay-based ALS learning groups within a district';

-- ============================================================
-- 4. ENROLLMENTS - Student <-> Cohort join table
-- ============================================================
CREATE TYPE public.enrollment_status AS ENUM ('active', 'inactive', 'completed', 'dropped');

CREATE TABLE public.enrollments (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    cohort_id   UUID NOT NULL REFERENCES public.cohorts(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status      public.enrollment_status NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(student_id, cohort_id)
);

COMMENT ON TABLE public.enrollments IS 'Maps students to their barangay-based cohorts';

-- ============================================================
-- 5. Updated_at trigger function (reusable)
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER set_districts_updated_at
    BEFORE UPDATE ON public.districts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_cohorts_updated_at
    BEFORE UPDATE ON public.cohorts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_enrollments_updated_at
    BEFORE UPDATE ON public.enrollments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
