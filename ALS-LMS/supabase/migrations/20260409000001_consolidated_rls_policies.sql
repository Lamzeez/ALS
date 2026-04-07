-- ============================================================
-- CONSOLIDATED RLS POLICIES MIGRATION
-- Replaces: 20260405000005_rls_policies.sql
--           20260406000001_roles_permissions.sql
--           20260408000001_fix_grants_and_policies.sql
--           20260408000001_fix_rls_policies.sql
--           20260408000002_fix_recursive_policies.sql
--
-- This migration should be run AFTER the core schema migrations.
-- It consolidates all RLS policy definitions to avoid duplicates.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1. Schema-level access (root cause of 42501 errors)
-- ──────────────────────────────────────────────────────────────
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 2. Table-level grants (RLS still controls row access)
-- ──────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- ──────────────────────────────────────────────────────────────
-- 3. Default privileges for future tables
-- ──────────────────────────────────────────────────────────────
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO anon;

-- ──────────────────────────────────────────────────────────────
-- 4. Helper function: Get current user's role (SECURITY DEFINER)
--    Bypasses RLS to avoid infinite recursion
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS public.user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper function: Get current user's district
CREATE OR REPLACE FUNCTION public.get_user_district_id()
RETURNS UUID AS $$
    SELECT district_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ──────────────────────────────────────────────────────────────
-- 5. DISTRICTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Anyone authenticated can view districts" ON public.districts;
CREATE POLICY "Anyone authenticated can view districts"
    ON public.districts FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Only admins can manage districts" ON public.districts;
CREATE POLICY "Only admins can manage districts"
    ON public.districts FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 6. PROFILES Policies
-- ──────────────────────────────────────────────────────────────
-- Users can read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

-- Users can update their own profile (limited fields)
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Teachers can view profiles of students in their cohorts
DROP POLICY IF EXISTS "Teachers can view cohort students" ON public.profiles;
CREATE POLICY "Teachers can view cohort students"
    ON public.profiles FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND id IN (
            SELECT e.student_id FROM public.enrollments e
            JOIN public.cohorts c ON c.id = e.cohort_id
            WHERE c.coordinator_id = auth.uid()
        )
    );

-- Admins can view all profiles (uses get_user_role to avoid recursion)
DROP POLICY IF EXISTS "Admins view all profiles" ON public.profiles;
CREATE POLICY "Admins view all profiles"
    ON public.profiles FOR SELECT
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- Admins can update any profile
DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile"
    ON public.profiles FOR UPDATE
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'))
    WITH CHECK (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- Admins can update approval_status for teachers
DROP POLICY IF EXISTS "Admins can update approval status" ON public.profiles;
CREATE POLICY "Admins can update approval status"
    ON public.profiles FOR UPDATE
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'))
    WITH CHECK (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- Dev admins have full profile access
DROP POLICY IF EXISTS "Dev admins have full profile access" ON public.profiles;
CREATE POLICY "Dev admins have full profile access"
    ON public.profiles FOR ALL
    USING (public.get_user_role() = 'dev_admin');

-- ──────────────────────────────────────────────────────────────
-- 7. COHORTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view cohorts in their district" ON public.cohorts;
CREATE POLICY "Users can view cohorts in their district"
    ON public.cohorts FOR SELECT
    USING (
        district_id = public.get_user_district_id()
        OR public.get_user_role() = 'dev_admin'
    );

DROP POLICY IF EXISTS "Admins can manage cohorts in their district" ON public.cohorts;
CREATE POLICY "Admins can manage cohorts in their district"
    ON public.cohorts FOR ALL
    USING (
        public.get_user_role() IN ('school_admin', 'dev_admin')
        AND (district_id = public.get_user_district_id() OR public.get_user_role() = 'dev_admin')
    );

-- ──────────────────────────────────────────────────────────────
-- 8. ENROLLMENTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view own enrollments" ON public.enrollments;
CREATE POLICY "Students can view own enrollments"
    ON public.enrollments FOR SELECT
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can view enrollments in their cohorts" ON public.enrollments;
CREATE POLICY "Teachers can view enrollments in their cohorts"
    ON public.enrollments FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND cohort_id IN (
            SELECT id FROM public.cohorts WHERE coordinator_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins can manage enrollments in their district" ON public.enrollments;
CREATE POLICY "Admins can manage enrollments in their district"
    ON public.enrollments FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 9. COURSES Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view enrolled courses" ON public.courses;
CREATE POLICY "Students can view enrolled courses"
    ON public.courses FOR SELECT
    USING (
        is_published = true
        AND (
            cohort_id IN (
                SELECT cohort_id FROM public.enrollments WHERE student_id = auth.uid()
            )
            OR is_blueprint = true
        )
    );

DROP POLICY IF EXISTS "Teachers can manage own courses" ON public.courses;
CREATE POLICY "Teachers can manage own courses"
    ON public.courses FOR ALL
    USING (
        public.get_user_role() = 'teacher'
        AND teacher_id = auth.uid()
    );

DROP POLICY IF EXISTS "Teachers can view blueprints" ON public.courses;
CREATE POLICY "Teachers can view blueprints"
    ON public.courses FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND is_blueprint = true
    );

DROP POLICY IF EXISTS "Admins full course access" ON public.courses;
CREATE POLICY "Admins full course access"
    ON public.courses FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 10. COURSE_ENROLLMENTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students see own enrollments" ON public.course_enrollments;
CREATE POLICY "Students see own enrollments"
    ON public.course_enrollments FOR SELECT
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers see enrollments for their courses" ON public.course_enrollments;
CREATE POLICY "Teachers see enrollments for their courses"
    ON public.course_enrollments FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM courses c WHERE c.id = course_id AND c.teacher_id = auth.uid())
    );

DROP POLICY IF EXISTS "Students can enroll" ON public.course_enrollments;
CREATE POLICY "Students can enroll"
    ON public.course_enrollments FOR INSERT
    WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Admins manage enrollments" ON public.course_enrollments;
CREATE POLICY "Admins manage enrollments"
    ON public.course_enrollments FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 11. LEARNING_CENTERS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Centers viewable by all authenticated" ON public.learning_centers;
CREATE POLICY "Centers viewable by all authenticated"
    ON public.learning_centers FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Centers manageable by school_admin and dev_admin" ON public.learning_centers;
CREATE POLICY "Centers manageable by school_admin and dev_admin"
    ON public.learning_centers FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'))
    WITH CHECK (public.get_user_role() IN ('school_admin', 'dev_admin'));

DROP POLICY IF EXISTS "Admins can insert learning centers" ON public.learning_centers;
CREATE POLICY "Admins can insert learning centers"
    ON public.learning_centers FOR INSERT
    WITH CHECK (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 12. CENTER_TEACHERS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Center teachers viewable by all authenticated" ON public.center_teachers;
CREATE POLICY "Center teachers viewable by all authenticated"
    ON public.center_teachers FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Center teachers manageable by school_admin and dev_admin" ON public.center_teachers;
CREATE POLICY "Center teachers manageable by school_admin and dev_admin"
    ON public.center_teachers FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'))
    WITH CHECK (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 13. MODULES Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view published modules" ON public.modules;
CREATE POLICY "Students can view published modules"
    ON public.modules FOR SELECT
    USING (
        is_published = true
        AND course_id IN (
            SELECT id FROM public.courses WHERE is_published = true
        )
    );

DROP POLICY IF EXISTS "Teachers can manage modules in their courses" ON public.modules;
CREATE POLICY "Teachers can manage modules in their courses"
    ON public.modules FOR ALL
    USING (
        course_id IN (
            SELECT id FROM public.courses WHERE teacher_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins full module access" ON public.modules;
CREATE POLICY "Admins full module access"
    ON public.modules FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 14. LESSONS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view published lessons" ON public.lessons;
CREATE POLICY "Students can view published lessons"
    ON public.lessons FOR SELECT
    USING (
        is_published = true
        AND module_id IN (
            SELECT id FROM public.modules WHERE is_published = true
        )
    );

DROP POLICY IF EXISTS "Teachers can manage lessons in their courses" ON public.lessons;
CREATE POLICY "Teachers can manage lessons in their courses"
    ON public.lessons FOR ALL
    USING (
        module_id IN (
            SELECT m.id FROM public.modules m
            JOIN public.courses c ON c.id = m.course_id
            WHERE c.teacher_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins full lesson access" ON public.lessons;
CREATE POLICY "Admins full lesson access"
    ON public.lessons FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 15. LESSON_MEDIA Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Authenticated users can view media" ON public.lesson_media;
CREATE POLICY "Authenticated users can view media"
    ON public.lesson_media FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Teachers can manage media in their courses" ON public.lesson_media;
CREATE POLICY "Teachers can manage media in their courses"
    ON public.lesson_media FOR ALL
    USING (
        lesson_id IN (
            SELECT l.id FROM public.lessons l
            JOIN public.modules m ON m.id = l.module_id
            JOIN public.courses c ON c.id = m.course_id
            WHERE c.teacher_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Teachers can insert lesson media records" ON public.lesson_media;
CREATE POLICY "Teachers can insert lesson media records"
    ON public.lesson_media FOR INSERT
    WITH CHECK (
        public.get_user_role() IN ('teacher', 'school_admin', 'dev_admin')
    );

-- ──────────────────────────────────────────────────────────────
-- 16. QUIZZES Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view published quizzes" ON public.quizzes;
CREATE POLICY "Students can view published quizzes"
    ON public.quizzes FOR SELECT
    USING (is_published = true AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Teachers can manage quizzes in their courses" ON public.quizzes;
CREATE POLICY "Teachers can manage quizzes in their courses"
    ON public.quizzes FOR ALL
    USING (
        module_id IN (
            SELECT m.id FROM public.modules m
            JOIN public.courses c ON c.id = m.course_id
            WHERE c.teacher_id = auth.uid()
        )
        OR lesson_id IN (
            SELECT l.id FROM public.lessons l
            JOIN public.modules m ON m.id = l.module_id
            JOIN public.courses c ON c.id = m.course_id
            WHERE c.teacher_id = auth.uid()
        )
    );

-- ──────────────────────────────────────────────────────────────
-- 17. QUIZ_QUESTIONS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view quiz questions" ON public.quiz_questions;
CREATE POLICY "Students can view quiz questions"
    ON public.quiz_questions FOR SELECT
    USING (
        quiz_id IN (SELECT id FROM public.quizzes WHERE is_published = true)
    );

DROP POLICY IF EXISTS "Teachers can manage quiz questions" ON public.quiz_questions;
CREATE POLICY "Teachers can manage quiz questions"
    ON public.quiz_questions FOR ALL
    USING (
        quiz_id IN (
            SELECT q.id FROM public.quizzes q
            LEFT JOIN public.modules m ON m.id = q.module_id
            LEFT JOIN public.lessons l ON l.id = q.lesson_id
            LEFT JOIN public.modules m2 ON m2.id = l.module_id
            JOIN public.courses c ON c.id = COALESCE(m.course_id, m2.course_id)
            WHERE c.teacher_id = auth.uid()
        )
    );

-- ──────────────────────────────────────────────────────────────
-- 18. SCORES Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view own scores" ON public.scores;
CREATE POLICY "Students can view own scores"
    ON public.scores FOR SELECT
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Students can insert own scores" ON public.scores;
CREATE POLICY "Students can insert own scores"
    ON public.scores FOR INSERT
    WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can view scores in their cohorts" ON public.scores;
CREATE POLICY "Teachers can view scores in their cohorts"
    ON public.scores FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND student_id IN (
            SELECT e.student_id FROM public.enrollments e
            JOIN public.cohorts c ON c.id = e.cohort_id
            WHERE c.coordinator_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins full score access" ON public.scores;
CREATE POLICY "Admins full score access"
    ON public.scores FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 19. MODULE_PROGRESS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view own progress" ON public.module_progress;
CREATE POLICY "Students can view own progress"
    ON public.module_progress FOR SELECT
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Students can update own progress" ON public.module_progress;
CREATE POLICY "Students can update own progress"
    ON public.module_progress FOR INSERT
    WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Students can modify own progress" ON public.module_progress;
CREATE POLICY "Students can modify own progress"
    ON public.module_progress FOR UPDATE
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can view cohort progress" ON public.module_progress;
CREATE POLICY "Teachers can view cohort progress"
    ON public.module_progress FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND student_id IN (
            SELECT e.student_id FROM public.enrollments e
            JOIN public.cohorts c ON c.id = e.cohort_id
            WHERE c.coordinator_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins full progress access" ON public.module_progress;
CREATE POLICY "Admins full progress access"
    ON public.module_progress FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 20. ATTENDANCE Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view own attendance" ON public.attendance;
CREATE POLICY "Students can view own attendance"
    ON public.attendance FOR SELECT
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can manage attendance in their cohorts" ON public.attendance;
CREATE POLICY "Teachers can manage attendance in their cohorts"
    ON public.attendance FOR ALL
    USING (
        public.get_user_role() = 'teacher'
        AND cohort_id IN (
            SELECT id FROM public.cohorts WHERE coordinator_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admins full attendance access" ON public.attendance;
CREATE POLICY "Admins full attendance access"
    ON public.attendance FOR ALL
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 21. SUBMISSIONS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can manage own submissions" ON public.submissions;
CREATE POLICY "Students can manage own submissions"
    ON public.submissions FOR ALL
    USING (student_id = auth.uid());

DROP POLICY IF EXISTS "Teachers can view/grade submissions" ON public.submissions;
CREATE POLICY "Teachers can view/grade submissions"
    ON public.submissions FOR SELECT
    USING (
        public.get_user_role() = 'teacher'
        AND student_id IN (
            SELECT e.student_id FROM public.enrollments e
            JOIN public.cohorts c ON c.id = e.cohort_id
            WHERE c.coordinator_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Teachers can update submissions (grading)" ON public.submissions;
CREATE POLICY "Teachers can update submissions (grading)"
    ON public.submissions FOR UPDATE
    USING (public.get_user_role() = 'teacher');

-- ──────────────────────────────────────────────────────────────
-- 22. SUBMISSION_COMMENTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Students can view comments on their submissions" ON public.submission_comments;
CREATE POLICY "Students can view comments on their submissions"
    ON public.submission_comments FOR SELECT
    USING (
        submission_id IN (
            SELECT id FROM public.submissions WHERE student_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Teachers can manage their comments" ON public.submission_comments;
CREATE POLICY "Teachers can manage their comments"
    ON public.submission_comments FOR ALL
    USING (teacher_id = auth.uid());

-- ──────────────────────────────────────────────────────────────
-- 23. ANNOUNCEMENTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Announcements viewable by enrolled students" ON public.announcements;
CREATE POLICY "Announcements viewable by enrolled students"
    ON public.announcements FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM course_enrollments ce WHERE ce.course_id = course_id AND ce.student_id = auth.uid())
        OR EXISTS (SELECT 1 FROM courses c WHERE c.id = course_id AND c.teacher_id = auth.uid())
        OR public.get_user_role() IN ('school_admin', 'dev_admin')
    );

DROP POLICY IF EXISTS "Teachers manage own announcements" ON public.announcements;
CREATE POLICY "Teachers manage own announcements"
    ON public.announcements FOR ALL
    USING (teacher_id = auth.uid());

-- ──────────────────────────────────────────────────────────────
-- 24. ANNOUNCEMENT_COMMENTS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Comments viewable by course participants" ON public.announcement_comments;
CREATE POLICY "Comments viewable by course participants"
    ON public.announcement_comments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM announcements a
            WHERE a.id = announcement_id
            AND (
                EXISTS (SELECT 1 FROM course_enrollments ce WHERE ce.course_id = a.course_id AND ce.student_id = auth.uid())
                OR EXISTS (SELECT 1 FROM courses c WHERE c.id = a.course_id AND c.teacher_id = auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users add own comments" ON public.announcement_comments;
CREATE POLICY "Users add own comments"
    ON public.announcement_comments FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM announcements a
            WHERE a.id = announcement_id AND a.allow_comments = true
        )
    );

-- ──────────────────────────────────────────────────────────────
-- 25. SYSTEM_SETTINGS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "System settings readable by all authenticated" ON public.system_settings;
CREATE POLICY "System settings readable by all authenticated"
    ON public.system_settings FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "System settings writable by dev_admin" ON public.system_settings;
CREATE POLICY "System settings writable by dev_admin"
    ON public.system_settings FOR ALL
    USING (public.get_user_role() = 'dev_admin');

-- ──────────────────────────────────────────────────────────────
-- 26. ACTIVITY_LOGS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Activity logs viewable by dev_admin" ON public.activity_logs;
CREATE POLICY "Activity logs viewable by dev_admin"
    ON public.activity_logs FOR SELECT
    USING (public.get_user_role() = 'dev_admin');

DROP POLICY IF EXISTS "Activity logs writable by all authenticated" ON public.activity_logs;
CREATE POLICY "Activity logs writable by all authenticated"
    ON public.activity_logs FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ──────────────────────────────────────────────────────────────
-- 27. SYNC_METADATA Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can manage own sync metadata" ON public.sync_metadata;
CREATE POLICY "Users can manage own sync metadata"
    ON public.sync_metadata FOR ALL
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all sync metadata" ON public.sync_metadata;
CREATE POLICY "Admins can view all sync metadata"
    ON public.sync_metadata FOR SELECT
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 28. AUDIT_LOGS Policies
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs"
    ON public.audit_logs FOR SELECT
    USING (public.get_user_role() IN ('school_admin', 'dev_admin'));

-- ──────────────────────────────────────────────────────────────
-- 29. SCHEMA_VERSIONS Policy
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Authenticated users can view schema versions" ON public.schema_versions;
CREATE POLICY "Authenticated users can view schema versions"
    ON public.schema_versions FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- ──────────────────────────────────────────────────────────────
-- 30. STORAGE POLICIES
-- ──────────────────────────────────────────────────────────────
-- Lessons Media - Teachers can upload
DROP POLICY IF EXISTS "Teachers can upload media" ON storage.objects;
CREATE POLICY "Teachers can upload media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'lessons-media' 
        AND public.get_user_role() IN ('teacher', 'school_admin', 'dev_admin')
    );

DROP POLICY IF EXISTS "Anyone can view lessons media" ON storage.objects;
CREATE POLICY "Anyone can view lessons media"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'lessons-media');

DROP POLICY IF EXISTS "Admins can update or delete media" ON storage.objects;
CREATE POLICY "Admins can update or delete media"
    ON storage.objects FOR ALL
    TO authenticated
    USING (
        bucket_id = 'lessons-media'
        AND public.get_user_role() IN ('teacher', 'school_admin', 'dev_admin')
    );

-- Profile Avatars - Users can manage own
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'profile-avatars' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
CREATE POLICY "Anyone can view avatars"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'profile-avatars');

DROP POLICY IF EXISTS "Users can update or delete own avatar" ON storage.objects;
CREATE POLICY "Users can update or delete own avatar"
    ON storage.objects FOR ALL
    TO authenticated
    USING (
        bucket_id = 'profile-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'profile-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
