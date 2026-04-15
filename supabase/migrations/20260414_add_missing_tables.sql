-- 1. system_settings table
CREATE TABLE IF NOT EXISTS public.system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY system_settings_admin_all ON public.system_settings FOR ALL
  USING (public.current_user_role() = 'admin');

-- 2. lesson_media table
CREATE TABLE IF NOT EXISTS public.lesson_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id TEXT NOT NULL,
  media_url TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.lesson_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY lesson_media_select ON public.lesson_media FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY lesson_media_teacher_all ON public.lesson_media FOR ALL
  USING (public.current_user_role() IN ('teacher', 'admin'));

-- 3. courses table
CREATE TABLE IF NOT EXISTS public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  created_by TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. course_enrollments table
CREATE TABLE IF NOT EXISTS public.course_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id TEXT NOT NULL,
  student_id TEXT NOT NULL,
  enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'active',
  UNIQUE(course_id, student_id)
);

-- 5. modules table
CREATE TABLE IF NOT EXISTS public.modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. scores table
CREATE TABLE IF NOT EXISTS public.scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id TEXT NOT NULL,
  quiz_id TEXT NOT NULL,
  score INTEGER NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. module_progress table
CREATE TABLE IF NOT EXISTS public.module_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id TEXT NOT NULL,
  module_id TEXT NOT NULL,
  progress_percent DOUBLE PRECISION DEFAULT 0.0,
  completed_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(student_id, module_id)
);

-- 8. districts table
CREATE TABLE IF NOT EXISTS public.districts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  region TEXT,
  province TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. announcement_comments table
CREATE TABLE IF NOT EXISTS public.announcement_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. learning_centers table (ALIAS for als_centers)
-- OPTION 1: Create a view
CREATE OR REPLACE VIEW public.learning_centers AS
SELECT * FROM public.als_centers;

-- OPTION 2: Rename als_centers → learning_centers in all migrations

-- 11. center_teachers table
CREATE TABLE IF NOT EXISTS public.center_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id TEXT NOT NULL,
  teacher_id TEXT NOT NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(center_id, teacher_id)
);

-- 12. quiz_questions (ALIAS for questions)
CREATE OR REPLACE VIEW public.quiz_questions AS
SELECT * FROM public.questions;