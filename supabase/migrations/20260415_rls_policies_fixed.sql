-- Migration: Add RLS policies for tables added in 20260414_add_missing_tables.sql
-- Date: 2026-04-15 (Version 2 - Direct policy creation)
-- Purpose: Secure all tables that were left UNRESTRICTED

-- =============================================
-- 1. SYSTEM SETTINGS
-- =============================================

DROP POLICY IF EXISTS system_settings_admin_all ON public.system_settings;
CREATE POLICY system_settings_admin_all ON public.system_settings FOR ALL
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

-- =============================================
-- 2. COURSES TABLE
-- =============================================

DROP POLICY IF EXISTS courses_select_active ON public.courses;
DROP POLICY IF EXISTS courses_admin_all ON public.courses;

CREATE POLICY courses_select_active ON public.courses FOR SELECT
USING (is_active = true);

CREATE POLICY courses_admin_all ON public.courses FOR ALL
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

-- =============================================
-- 3. COURSE ENROLLMENTS TABLE
-- =============================================

DROP POLICY IF EXISTS enrollments_student_select ON public.course_enrollments;
DROP POLICY IF EXISTS enrollments_teacher_select ON public.course_enrollments;
DROP POLICY IF EXISTS enrollments_insert ON public.course_enrollments;

CREATE POLICY enrollments_student_select ON public.course_enrollments FOR SELECT
USING (student_id::uuid = auth.uid());

CREATE POLICY enrollments_teacher_select ON public.course_enrollments FOR SELECT
USING (public.current_user_role() IN ('teacher', 'admin'));

CREATE POLICY enrollments_insert ON public.course_enrollments FOR INSERT
WITH CHECK (public.current_user_role() IN ('teacher', 'admin'));

-- =============================================
-- 4. MODULES TABLE
-- =============================================

DROP POLICY IF EXISTS modules_select_active ON public.modules;
DROP POLICY IF EXISTS modules_admin_all ON public.modules;

CREATE POLICY modules_select_active ON public.modules FOR SELECT
USING (true);

CREATE POLICY modules_admin_all ON public.modules FOR ALL
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

-- =============================================
-- 5. SCORES TABLE
-- =============================================

DROP POLICY IF EXISTS scores_student_select ON public.scores;
DROP POLICY IF EXISTS scores_student_insert ON public.scores;
DROP POLICY IF EXISTS scores_teacher_select ON public.scores;

CREATE POLICY scores_student_select ON public.scores FOR SELECT
USING (student_id::uuid = auth.uid());

CREATE POLICY scores_student_insert ON public.scores FOR INSERT
WITH CHECK (student_id::uuid = auth.uid());

CREATE POLICY scores_teacher_select ON public.scores FOR SELECT
USING (public.current_user_role() IN ('teacher', 'admin'));

-- =============================================
-- 6. MODULE PROGRESS TABLE
-- =============================================

DROP POLICY IF EXISTS module_progress_student_select ON public.module_progress;
DROP POLICY IF EXISTS module_progress_student_insert ON public.module_progress;
DROP POLICY IF EXISTS module_progress_student_update ON public.module_progress;
DROP POLICY IF EXISTS module_progress_teacher_select ON public.module_progress;

CREATE POLICY module_progress_student_select ON public.module_progress FOR SELECT
USING (student_id::uuid = auth.uid());

CREATE POLICY module_progress_student_insert ON public.module_progress FOR INSERT
WITH CHECK (student_id::uuid = auth.uid());

CREATE POLICY module_progress_student_update ON public.module_progress FOR UPDATE
USING (student_id::uuid = auth.uid())
WITH CHECK (student_id::uuid = auth.uid());

CREATE POLICY module_progress_teacher_select ON public.module_progress FOR SELECT
USING (public.current_user_role() IN ('teacher', 'admin'));

-- =============================================
-- 7. DISTRICTS TABLE
-- =============================================

DROP POLICY IF EXISTS districts_select ON public.districts;
DROP POLICY IF EXISTS districts_admin_all ON public.districts;

CREATE POLICY districts_select ON public.districts FOR SELECT
USING (true);

CREATE POLICY districts_admin_all ON public.districts FOR ALL
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

-- =============================================
-- 8. ANNOUNCEMENT COMMENTS TABLE
-- =============================================

DROP POLICY IF EXISTS announcement_comments_select ON public.announcement_comments;
DROP POLICY IF EXISTS announcement_comments_insert ON public.announcement_comments;
DROP POLICY IF EXISTS announcement_comments_delete ON public.announcement_comments;

CREATE POLICY announcement_comments_select ON public.announcement_comments FOR SELECT
USING (auth.uid() IS NOT NULL);

CREATE POLICY announcement_comments_insert ON public.announcement_comments FOR INSERT
WITH CHECK (user_id::uuid = auth.uid());

CREATE POLICY announcement_comments_delete ON public.announcement_comments FOR DELETE
USING (user_id::uuid = auth.uid());

-- =============================================
-- 9. CENTER TEACHERS TABLE
-- =============================================

DROP POLICY IF EXISTS center_teachers_select ON public.center_teachers;
DROP POLICY IF EXISTS center_teachers_admin_all ON public.center_teachers;

CREATE POLICY center_teachers_select ON public.center_teachers FOR SELECT
USING (true);

CREATE POLICY center_teachers_admin_all ON public.center_teachers FOR ALL
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

-- =============================================
-- 10. LESSON MEDIA TABLE
-- =============================================

DROP POLICY IF EXISTS lesson_media_select ON public.lesson_media;
DROP POLICY IF EXISTS lesson_media_teacher_all ON public.lesson_media;

CREATE POLICY lesson_media_select ON public.lesson_media FOR SELECT
USING (auth.uid() IS NOT NULL);

CREATE POLICY lesson_media_teacher_all ON public.lesson_media FOR ALL
USING (public.current_user_role() IN ('teacher', 'admin'))
WITH CHECK (public.current_user_role() IN ('teacher', 'admin'));

-- =============================================
-- 11. VERIFY POLICIES WERE CREATED
-- =============================================

-- This query will output the count of policies per table
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'system_settings';
  RAISE NOTICE 'system_settings policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'courses';
  RAISE NOTICE 'courses policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'course_enrollments';
  RAISE NOTICE 'course_enrollments policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'modules';
  RAISE NOTICE 'modules policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'scores';
  RAISE NOTICE 'scores policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'module_progress';
  RAISE NOTICE 'module_progress policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'districts';
  RAISE NOTICE 'districts policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'announcement_comments';
  RAISE NOTICE 'announcement_comments policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'center_teachers';
  RAISE NOTICE 'center_teachers policies: %', policy_count;
  
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'lesson_media';
  RAISE NOTICE 'lesson_media policies: %', policy_count;
END$$;

-- Note: `learning_centers` and `quiz_questions` are VIEWS, so they don't need RLS policies.
-- They inherit security from their underlying tables (`als_centers` and `questions`).
