-- ALS LMS Consolidated Schema
-- Includes Extensions, Roles, Functions, Tables, and Policies

-- 1. EXTENSIONS & ROLES
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

ALTER ROLE "anon" SET "statement_timeout" TO '3s';
ALTER ROLE "authenticated" SET "statement_timeout" TO '8s';
ALTER ROLE "authenticator" SET "statement_timeout" TO '8s';

-- 2. UTILITY FUNCTIONS
CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text AS $$
SELECT COALESCE((SELECT role FROM public.profiles WHERE id = auth.uid()), 'public');
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_my_center_id() RETURNS uuid AS $$
BEGIN RETURN (SELECT als_center_id FROM public.profiles WHERE id = auth.uid()); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CORE LOGIC FUNCTIONS
CREATE OR REPLACE FUNCTION public.handle_new_auth_user() RETURNS trigger AS $$
DECLARE user_role TEXT; raw_lrn TEXT; onboarding_done BOOLEAN;
BEGIN
  user_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'student');
  raw_lrn := NULLIF(NEW.raw_user_meta_data->>'student_id_number', '');
  onboarding_done := COALESCE((NEW.raw_user_meta_data->>'onboarding_completed')::boolean, true);

  INSERT INTO public.profiles (id, email, full_name, role, first_name, last_name, student_id_number, employee_id, gender, onboarding_completed, updated_at)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)), user_role,
          NULLIF(NEW.raw_user_meta_data->>'first_name', ''), NULLIF(NEW.raw_user_meta_data->>'last_name', ''),
          raw_lrn, NULLIF(NEW.raw_user_meta_data->>'employee_id', ''), NULLIF(NEW.raw_user_meta_data->>'gender', ''), onboarding_done, NOW())
  ON CONFLICT (id) DO UPDATE SET updated_at = NOW();

  BEGIN
    IF user_role = 'student' THEN
      INSERT INTO public.students (user_id, learner_reference_number, grade_level, als_center_id)
      VALUES (NEW.id::text, raw_lrn, 'BLP', NULLIF(NEW.raw_user_meta_data->>'als_center_id', '')) ON CONFLICT (user_id) DO NOTHING;
    ELSIF user_role = 'teacher' THEN
      INSERT INTO public.teachers (user_id, employee_id, specialization, als_center_id)
      VALUES (NEW.id::text, NULLIF(NEW.raw_user_meta_data->>'employee_id', ''), 'General', NULLIF(NEW.raw_user_meta_data->>'als_center_id', '')) ON CONFLICT (user_id) DO NOTHING;
    END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'Role-specific insertion failed: %', SQLERRM;
  END;
  RETURN NEW;
END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. TABLES
CREATE TABLE public.districts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    region text NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.als_center_registrations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    center_name text NOT NULL,
    address text NOT NULL,
    region text NOT NULL,
    contact_number text NOT NULL,
    admin_full_name text NOT NULL,
    admin_email text UNIQUE NOT NULL,
    admin_password text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason text,
    reviewed_by uuid REFERENCES public.profiles(id),
    reviewed_at timestamptz,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.als_centers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    district_id uuid REFERENCES public.districts(id),
    address text NOT NULL,
    region text NOT NULL,
    center_admin_id uuid, -- Reference added via Alter
    registration_id uuid REFERENCES public.als_center_registrations(id),
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE,
    full_name text NOT NULL,
    role text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'center_admin', 'system_admin')),
    lrn text UNIQUE,
    employee_id text UNIQUE,
    district_id text,
    avatar_url text,
    device_id text,
    phone_number text,
    first_name text,
    last_name text,
    date_of_birth date,
    age integer,
    occupation text,
    last_school_attended text,
    last_year_attended text,
    als_center_id uuid REFERENCES public.als_centers(id),
    is_active boolean DEFAULT true,
    approval_status text NOT NULL DEFAULT 'approved',
    onboarding_completed boolean DEFAULT false,
    email_verified boolean DEFAULT false,
    teacher_verified boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    student_id_number text,
    gender text,
    birth_date date
);

CREATE TABLE public.students (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text UNIQUE NOT NULL,
    learner_reference_number text UNIQUE,
    student_id_number text,
    grade_level text NOT NULL DEFAULT 'BLP',
    enrollment_date timestamptz DEFAULT now(),
    guardian_name text,
    guardian_contact text,
    date_of_birth date,
    age integer,
    occupation text,
    last_school_attended text,
    last_year_attended text,
    als_center_id text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.teachers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id text UNIQUE NOT NULL,
    als_center_id text,
    employee_id text UNIQUE,
    specialization text NOT NULL DEFAULT '',
    assigned_student_ids text DEFAULT '',
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.courses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    strand text NOT NULL DEFAULT 'communication_skills',
    teacher_id uuid REFERENCES auth.users(id),
    pin_code text UNIQUE,
    qr_code text,
    is_published boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.modules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    module_type text NOT NULL DEFAULT 'core',
    order_index integer NOT NULL DEFAULT 0,
    prerequisite_id uuid REFERENCES public.modules(id),
    passing_threshold real DEFAULT 75.0,
    estimated_hours real,
    is_published boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.lessons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id uuid NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
    course_id uuid REFERENCES public.courses(id) ON DELETE CASCADE,
    title text NOT NULL,
    content_json jsonb DEFAULT '{}',
    content_type text NOT NULL DEFAULT 'text',
    order_index integer NOT NULL DEFAULT 0,
    duration_minutes integer,
    is_published boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.quizzes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id uuid REFERENCES public.lessons(id) ON DELETE CASCADE,
    module_id uuid REFERENCES public.modules(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    time_limit_mins integer DEFAULT 0,
    passing_score real DEFAULT 75.0,
    is_published boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.questions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    text text NOT NULL,
    type text NOT NULL DEFAULT 'multiple_choice',
    options jsonb DEFAULT '[]',
    correct_answer text,
    explanation text,
    points integer DEFAULT 1,
    order_index integer DEFAULT 0
);

CREATE TABLE public.course_enrollments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'active',
    enrolled_via text NOT NULL DEFAULT 'pin',
    enrolled_at timestamptz DEFAULT now(),
    UNIQUE(course_id, student_id)
);

CREATE TABLE public.module_progress (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    module_id uuid NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
    course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'available',
    mastery_score real DEFAULT 0,
    lessons_viewed integer DEFAULT 0,
    total_lessons integer DEFAULT 0,
    started_at timestamptz,
    completed_at timestamptz,
    updated_at timestamptz DEFAULT now(),
    UNIQUE(student_id, module_id)
);

CREATE TABLE public.scores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    score real NOT NULL,
    max_score real NOT NULL,
    attempt_num integer DEFAULT 1,
    answers_json jsonb DEFAULT '{}',
    time_taken_secs integer,
    completed_at timestamptz DEFAULT now()
);

CREATE TABLE public.announcements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    target jsonb DEFAULT '{}',
    is_pinned boolean DEFAULT false,
    sync_status text DEFAULT 'synced',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id text NOT NULL,
    title text NOT NULL,
    description text DEFAULT '',
    scheduled_at timestamptz NOT NULL,
    duration_minutes integer DEFAULT 60,
    location text,
    status text DEFAULT 'scheduled',
    sync_status text DEFAULT 'synced',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 5. POLICIES (RLS ENABLED)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles_Read" ON public.profiles FOR SELECT USING (auth.uid() = id OR role = 'dev_admin' OR (role = 'school_admin' AND als_center_id = get_my_center_id()) OR auth.role() = 'authenticated');
CREATE POLICY "Profiles_Update" ON public.profiles FOR UPDATE USING (auth.uid() = id OR (role = 'school_admin' AND als_center_id = get_my_center_id()));

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Courses_Read" ON public.courses FOR SELECT USING (id IN (SELECT course_id FROM public.course_enrollments WHERE student_id = auth.uid()) OR is_published = true);
CREATE POLICY "Courses_Write" ON public.courses USING (teacher_id = auth.uid() OR current_user_role() = 'system_admin');

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students_Admin" ON public.students USING (current_user_role() = 'admin');
CREATE POLICY "Students_Self" ON public.students USING (user_id = auth.uid()::text);

-- 6. TRIGGERS
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 7. GRANTS
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
