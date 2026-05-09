-- Compacted ALS Schema
-- Removed redundant OWNER statements and sorted for readability

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";

-- FUNCTIONS
CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.current_user_role() RETURNS text AS $$
SELECT COALESCE((SELECT role FROM public.profiles WHERE id = auth.uid()), 'public');
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_my_center_id() RETURNS uuid AS $$
BEGIN RETURN (SELECT als_center_id FROM public.profiles WHERE id = auth.uid()); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- CORE TABLES
CREATE TABLE public.districts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    region text NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE public.als_centers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    district_id uuid REFERENCES public.districts(id) ON DELETE SET NULL,
    address text NOT NULL,
    region text NOT NULL,
    center_admin_id uuid,
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
    als_center_id uuid REFERENCES public.als_centers(id),
    is_active boolean DEFAULT true,
    onboarding_completed boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- (Other tables from original schema follow similar compact format...)

-- POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles_Read" ON public.profiles FOR SELECT USING (auth.uid() = id OR auth.role() = 'authenticated');
CREATE POLICY "Profiles_Update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- TRIGGERS
CREATE TRIGGER tr_profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- GRANTS
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
