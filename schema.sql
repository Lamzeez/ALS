


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."approve_center_registration"("p_registration_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
     DECLARE
       v_reg record;
       v_new_center_id UUID;
       v_new_user_id UUID;
     BEGIN
       -- 1. Fetch registration details
       SELECT * INTO v_reg FROM public.als_center_registrations WHERE id = p_registration_id;
   
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Registration request not found';
      END IF;
   
      IF v_reg.status != 'pending' THEN
        RAISE EXCEPTION 'This request has already been processed';
      END IF;
   
      -- 2. Create the ALS Center
      INSERT INTO public.als_centers (name, region, address, registration_id)
      VALUES (v_reg.center_name, v_reg.region, v_reg.address, p_registration_id)
      RETURNING id INTO v_new_center_id;
   
      -- 3. Update registration status
      UPDATE public.als_center_registrations
      SET
        status = 'approved',
        reviewed_at = NOW(),
        reviewed_by = auth.uid()
      WHERE id = p_registration_id;
   
      -- NOTE: The actual User Account creation for the Center Admin
      -- should be handled via Supabase Auth API from the frontend/service
      -- or a separate Auth-hook, because SQL cannot directly create Auth users
      -- without using the 'auth' schema extensions which are restricted.
   
      -- We'll store the center ID in the registration for the frontend to pick up.
    END;
    $$;


ALTER FUNCTION "public"."approve_center_registration"("p_registration_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_role"() RETURNS "text"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
       SELECT COALESCE(
         (SELECT role FROM public.profiles WHERE id = auth.uid()),
         'public'
       );
     $$;


ALTER FUNCTION "public"."current_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_center_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
    BEGIN
      RETURN (SELECT als_center_id FROM public.profiles WHERE id = auth.uid());
    END;
    $$;


ALTER FUNCTION "public"."get_my_center_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    DECLARE
      user_role TEXT;
      raw_lrn TEXT;
      onboarding_done BOOLEAN;
    BEGIN
      user_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'student');
      raw_lrn := NULLIF(NEW.raw_user_meta_data->>'student_id_number', '');
      onboarding_done := COALESCE((NEW.raw_user_meta_data->>'onboarding_completed')::boolean, true);
   
      -- 1. Insert into base 'profiles' table (This usually always succeeds)
      INSERT INTO public.profiles (
        id, email, full_name, role, first_name, last_name,
        student_id_number, employee_id, gender, onboarding_completed, updated_at
      )
      VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        user_role,
        NULLIF(NEW.raw_user_meta_data->>'first_name', ''),
        NULLIF(NEW.raw_user_meta_data->>'last_name', ''),
        raw_lrn,
        NULLIF(NEW.raw_user_meta_data->>'employee_id', ''),
        NULLIF(NEW.raw_user_meta_data->>'gender', ''),
        onboarding_done,
        NOW()
      )
      ON CONFLICT (id) DO UPDATE SET updated_at = NOW();
   
      -- 2. Insert into role-specific tables (Wrapped in Exception block to prevent 500 crashes)
      BEGIN
        IF user_role = 'student' THEN
          INSERT INTO public.students (user_id, learner_reference_number, grade_level, als_center_id)
          VALUES (NEW.id::text, raw_lrn, 'BLP', NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''))
          ON CONFLICT (user_id) DO NOTHING;
        ELSIF user_role = 'teacher' THEN
          INSERT INTO public.teachers (user_id, employee_id, specialization, als_center_id)
          VALUES (NEW.id::text, NULLIF(NEW.raw_user_meta_data->>'employee_id', ''), 'General',
    NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''))
          ON CONFLICT (user_id) DO NOTHING;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- If LRN is wrong (not 12 digits), we still want the user to be able to register.
        -- The error is logged but the transaction continues.
        RAISE WARNING 'Role-specific table insertion failed: %', SQLERRM;
      END;
   
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
      BEGIN
        INSERT INTO public.profiles (
          id,
          email,
          full_name,
          role,
          is_active,
          email_verified,
          created_at,
          updated_at
        ) VALUES (
          NEW.id,
          NEW.email,
          COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
          COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
          true,
          COALESCE(NEW.email_confirmed_at IS NOT NULL, false),
          NEW.created_at,
          NEW.created_at
        );
        RETURN NEW;
      EXCEPTION
        WHEN OTHERS THEN
          -- Log error but don't block signup
          RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
          RETURN NEW;
      END;
      $$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_lesson"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.title IS NULL OR LENGTH(TRIM(NEW.title)) < 1 THEN
    RAISE EXCEPTION 'Lesson title is required';
  END IF;
  IF NEW.subject IS NULL OR LENGTH(TRIM(NEW.subject)) < 1 THEN
    RAISE EXCEPTION 'Lesson subject is required';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_lesson"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.progress_percent < 0 OR NEW.progress_percent > 100 THEN
    RAISE EXCEPTION 'Progress percent must be between 0 and 100';
  END IF;
  IF NEW.quiz_score IS NOT NULL AND (NEW.quiz_score < 0 OR NEW.quiz_score > 100) THEN
    RAISE EXCEPTION 'Quiz score must be between 0 and 100';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_student_lrn"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
  IF NEW.learner_reference_number IS NOT NULL AND
     NEW.learner_reference_number !~ '^\d{12}$' THEN
    RAISE EXCEPTION 'LRN must be exactly 12 digits: %', NEW.learner_reference_number;
  END IF;
  RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."validate_student_lrn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_user_email"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
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
$_$;


ALTER FUNCTION "public"."validate_user_email"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."als_center_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "center_name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "region" "text" NOT NULL,
    "contact_number" "text" NOT NULL,
    "admin_full_name" "text" NOT NULL,
    "admin_email" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "rejection_reason" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "admin_password" "text",
    CONSTRAINT "als_center_registrations_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."als_center_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."als_centers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "district_id" "uuid",
    "address" "text" NOT NULL,
    "region" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "registration_id" "uuid",
    "center_admin_id" "uuid"
);


ALTER TABLE "public"."als_centers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcement_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "announcement_id" "text" NOT NULL,
    "user_id" "text" NOT NULL,
    "comment" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."announcement_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "target" "jsonb" DEFAULT '{}'::"jsonb",
    "is_pinned" boolean DEFAULT false,
    "sync_status" "text" DEFAULT 'synced'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "performed_by" "text",
    "action" "text" NOT NULL,
    "target_user_id" "text",
    "details" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."center_subjects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "als_center_id" "uuid" NOT NULL,
    "subject_name" "text" NOT NULL,
    "subject_code" "text" NOT NULL,
    "grade_level" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."center_subjects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."center_teachers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "center_id" "text" NOT NULL,
    "teacher_id" "text" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."center_teachers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."certificates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "enrollment_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "course_id" "uuid" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "now"(),
    "certificate_url" "text"
);


ALTER TABLE "public"."certificates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."course_enrollments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "enrolled_via" "text" DEFAULT 'pin'::"text" NOT NULL,
    "enrolled_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."course_enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."course_timeline" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "lesson_id" "uuid",
    "start_date" "date",
    "end_date" "date",
    "order_index" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."course_timeline" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "strand" "text" DEFAULT 'communication_skills'::"text" NOT NULL,
    "teacher_id" "uuid",
    "pin_code" "text",
    "qr_code" "text",
    "is_published" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."courses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."districts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "region" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."districts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."downloads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lesson_id" "text" NOT NULL,
    "student_id" "text" NOT NULL,
    "local_file_path" "text",
    "download_progress" double precision DEFAULT 0.0,
    "status" "text" DEFAULT 'notDownloaded'::"text",
    "file_size_bytes" bigint DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."downloads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "content_json" "jsonb" DEFAULT '{}'::"jsonb",
    "content_type" "text" DEFAULT 'text'::"text" NOT NULL,
    "order_index" integer DEFAULT 0 NOT NULL,
    "duration_minutes" integer,
    "is_published" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "course_id" "uuid"
);


ALTER TABLE "public"."lessons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."module_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "module_id" "uuid" NOT NULL,
    "course_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    "mastery_score" real DEFAULT 0,
    "lessons_viewed" integer DEFAULT 0,
    "total_lessons" integer DEFAULT 0,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."module_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."modules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "module_type" "text" DEFAULT 'core'::"text" NOT NULL,
    "order_index" integer DEFAULT 0 NOT NULL,
    "prerequisite_id" "uuid",
    "passing_threshold" real DEFAULT 75.0,
    "estimated_hours" real,
    "is_published" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."modules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "full_name" "text" NOT NULL,
    "role" "text" DEFAULT 'student'::"text" NOT NULL,
    "lrn" "text",
    "employee_id" "text",
    "district_id" "text",
    "avatar_url" "text",
    "device_id" "text",
    "phone_number" "text",
    "first_name" "text",
    "last_name" "text",
    "date_of_birth" "date",
    "age" integer,
    "occupation" "text",
    "last_school_attended" "text",
    "last_year_attended" "text",
    "als_center_id" "uuid",
    "is_active" boolean DEFAULT true,
    "approval_status" "text" DEFAULT 'approved'::"text" NOT NULL,
    "onboarding_completed" boolean DEFAULT false,
    "email_verified" boolean DEFAULT false,
    "teacher_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "student_id_number" "text",
    "gender" "text",
    "birth_date" "date",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['student'::"text", 'teacher'::"text", 'center_admin'::"text", 'system_admin'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "quiz_id" "uuid" NOT NULL,
    "text" "text" NOT NULL,
    "type" "text" DEFAULT 'multiple_choice'::"text" NOT NULL,
    "options" "jsonb" DEFAULT '[]'::"jsonb",
    "correct_answer" "text",
    "explanation" "text",
    "points" integer DEFAULT 1,
    "order_index" integer DEFAULT 0
);


ALTER TABLE "public"."questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."quizzes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "lesson_id" "uuid",
    "module_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "time_limit_mins" integer DEFAULT 0,
    "passing_score" real DEFAULT 75.0,
    "is_published" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."quizzes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "quiz_id" "uuid" NOT NULL,
    "score" real NOT NULL,
    "max_score" real NOT NULL,
    "attempt_num" integer DEFAULT 1,
    "answers_json" "jsonb" DEFAULT '{}'::"jsonb",
    "time_taken_secs" integer,
    "completed_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "teacher_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "scheduled_at" timestamp with time zone NOT NULL,
    "duration_minutes" integer DEFAULT 60,
    "location" "text",
    "status" "text" DEFAULT 'scheduled'::"text",
    "sync_status" "text" DEFAULT 'synced'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."students" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "learner_reference_number" "text",
    "student_id_number" "text",
    "grade_level" "text" DEFAULT 'BLP'::"text" NOT NULL,
    "enrollment_date" timestamp with time zone DEFAULT "now"(),
    "guardian_name" "text",
    "guardian_contact" "text",
    "date_of_birth" "date",
    "age" integer,
    "occupation" "text",
    "last_school_attended" "text",
    "last_year_attended" "text",
    "als_center_id" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."students" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."system_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."teachers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "als_center_id" "text",
    "employee_id" "text",
    "specialization" "text" DEFAULT ''::"text" NOT NULL,
    "assigned_student_ids" "text" DEFAULT ''::"text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."teachers" OWNER TO "postgres";


ALTER TABLE ONLY "public"."als_center_registrations"
    ADD CONSTRAINT "als_center_registrations_admin_email_key" UNIQUE ("admin_email");



ALTER TABLE ONLY "public"."als_center_registrations"
    ADD CONSTRAINT "als_center_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcement_comments"
    ADD CONSTRAINT "announcement_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."center_subjects"
    ADD CONSTRAINT "center_subjects_als_center_id_subject_code_grade_level_key" UNIQUE ("als_center_id", "subject_code", "grade_level");



ALTER TABLE ONLY "public"."center_subjects"
    ADD CONSTRAINT "center_subjects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."center_teachers"
    ADD CONSTRAINT "center_teachers_center_id_teacher_id_key" UNIQUE ("center_id", "teacher_id");



ALTER TABLE ONLY "public"."center_teachers"
    ADD CONSTRAINT "center_teachers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."certificates"
    ADD CONSTRAINT "certificates_enrollment_id_key" UNIQUE ("enrollment_id");



ALTER TABLE ONLY "public"."certificates"
    ADD CONSTRAINT "certificates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_course_id_student_id_key" UNIQUE ("course_id", "student_id");



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."course_timeline"
    ADD CONSTRAINT "course_timeline_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_pin_code_key" UNIQUE ("pin_code");



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."districts"
    ADD CONSTRAINT "districts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."downloads"
    ADD CONSTRAINT "downloads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."als_centers"
    ADD CONSTRAINT "learning_centers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lessons"
    ADD CONSTRAINT "lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."module_progress"
    ADD CONSTRAINT "module_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."module_progress"
    ADD CONSTRAINT "module_progress_student_id_module_id_key" UNIQUE ("student_id", "module_id");



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_employee_id_key" UNIQUE ("employee_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_lrn_key" UNIQUE ("lrn");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."questions"
    ADD CONSTRAINT "questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quizzes"
    ADD CONSTRAINT "quizzes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_learner_reference_number_key" UNIQUE ("learner_reference_number");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."system_settings"
    ADD CONSTRAINT "system_settings_key_key" UNIQUE ("key");



ALTER TABLE ONLY "public"."system_settings"
    ADD CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."teachers"
    ADD CONSTRAINT "teachers_employee_id_key" UNIQUE ("employee_id");



ALTER TABLE ONLY "public"."teachers"
    ADD CONSTRAINT "teachers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."teachers"
    ADD CONSTRAINT "teachers_user_id_key" UNIQUE ("user_id");



CREATE INDEX "idx_announcements_teacher" ON "public"."announcements" USING "btree" ("teacher_id");



CREATE INDEX "idx_audit_logs_admin" ON "public"."audit_logs" USING "btree" ("performed_by");



CREATE INDEX "idx_audit_logs_created" ON "public"."audit_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_sessions_teacher" ON "public"."sessions" USING "btree" ("teacher_id");



CREATE INDEX "idx_students_center" ON "public"."students" USING "btree" ("als_center_id");



CREATE INDEX "idx_students_lrn" ON "public"."students" USING "btree" ("learner_reference_number");



CREATE INDEX "idx_students_user_id" ON "public"."students" USING "btree" ("user_id");



CREATE INDEX "idx_teachers_center" ON "public"."teachers" USING "btree" ("als_center_id");



CREATE INDEX "idx_teachers_user_id" ON "public"."teachers" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "update_announcements_updated_at" BEFORE UPDATE ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_downloads_updated_at" BEFORE UPDATE ON "public"."downloads" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sessions_updated_at" BEFORE UPDATE ON "public"."sessions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_students_updated_at" BEFORE UPDATE ON "public"."students" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_teachers_updated_at" BEFORE UPDATE ON "public"."teachers" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "validate_student_before_insert" BEFORE INSERT ON "public"."students" FOR EACH ROW EXECUTE FUNCTION "public"."validate_student_lrn"();



CREATE OR REPLACE TRIGGER "validate_student_before_update" BEFORE UPDATE ON "public"."students" FOR EACH ROW EXECUTE FUNCTION "public"."validate_student_lrn"();



ALTER TABLE ONLY "public"."als_center_registrations"
    ADD CONSTRAINT "als_center_registrations_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."als_centers"
    ADD CONSTRAINT "als_centers_center_admin_id_fkey" FOREIGN KEY ("center_admin_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."als_centers"
    ADD CONSTRAINT "als_centers_registration_id_fkey" FOREIGN KEY ("registration_id") REFERENCES "public"."als_center_registrations"("id");



ALTER TABLE ONLY "public"."center_subjects"
    ADD CONSTRAINT "center_subjects_als_center_id_fkey" FOREIGN KEY ("als_center_id") REFERENCES "public"."als_centers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."certificates"
    ADD CONSTRAINT "certificates_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."certificates"
    ADD CONSTRAINT "certificates_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "public"."course_enrollments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."certificates"
    ADD CONSTRAINT "certificates_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_timeline"
    ADD CONSTRAINT "course_timeline_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_timeline"
    ADD CONSTRAINT "course_timeline_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."als_centers"
    ADD CONSTRAINT "learning_centers_district_id_fkey" FOREIGN KEY ("district_id") REFERENCES "public"."districts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."lessons"
    ADD CONSTRAINT "lessons_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lessons"
    ADD CONSTRAINT "lessons_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."module_progress"
    ADD CONSTRAINT "module_progress_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."module_progress"
    ADD CONSTRAINT "module_progress_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."module_progress"
    ADD CONSTRAINT "module_progress_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_prerequisite_id_fkey" FOREIGN KEY ("prerequisite_id") REFERENCES "public"."modules"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."questions"
    ADD CONSTRAINT "questions_quiz_id_fkey" FOREIGN KEY ("quiz_id") REFERENCES "public"."quizzes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quizzes"
    ADD CONSTRAINT "quizzes_lesson_id_fkey" FOREIGN KEY ("lesson_id") REFERENCES "public"."lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."quizzes"
    ADD CONSTRAINT "quizzes_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "public"."modules"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_quiz_id_fkey" FOREIGN KEY ("quiz_id") REFERENCES "public"."quizzes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Profiles_Read_Policy" ON "public"."profiles" FOR SELECT USING ((("auth"."uid"() = "id") OR ("role" = 'dev_admin'::"text") OR (("role" = 'school_admin'::"text") AND ("als_center_id" = "public"."get_my_center_id"())) OR ("auth"."role"() = 'authenticated'::"text")));



CREATE POLICY "Profiles_Update_Policy" ON "public"."profiles" FOR UPDATE USING ((("auth"."uid"() = "id") OR (("role" = 'school_admin'::"text") AND ("als_center_id" = "public"."get_my_center_id"()))));



CREATE POLICY "Students_Insert_Own_Enrollments" ON "public"."course_enrollments" FOR INSERT WITH CHECK (("auth"."uid"() = "student_id"));



CREATE POLICY "Students_Insert_Own_Scores" ON "public"."scores" FOR INSERT WITH CHECK (("auth"."uid"() = "student_id"));



CREATE POLICY "Students_Manage_Own_Progress" ON "public"."module_progress" USING (("auth"."uid"() = "student_id"));



CREATE POLICY "Students_View_Own_Enrollments" ON "public"."course_enrollments" FOR SELECT USING (("auth"."uid"() = "student_id"));



CREATE POLICY "Students_View_Own_Scores" ON "public"."scores" FOR SELECT USING (("auth"."uid"() = "student_id"));



ALTER TABLE "public"."als_center_registrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."announcement_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcement_comments_delete" ON "public"."announcement_comments" FOR DELETE USING ((("user_id")::"uuid" = "auth"."uid"()));



CREATE POLICY "announcement_comments_insert" ON "public"."announcement_comments" FOR INSERT WITH CHECK ((("user_id")::"uuid" = "auth"."uid"()));



CREATE POLICY "announcement_comments_select" ON "public"."announcement_comments" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcements_student_select" ON "public"."announcements" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "announcements_teacher_all" ON "public"."announcements" USING (("teacher_id" = ("auth"."uid"())::"text"));



ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_logs_insert_policy" ON "public"."audit_logs" FOR INSERT WITH CHECK (("public"."current_user_role"() = 'admin'::"text"));



CREATE POLICY "audit_logs_select_policy" ON "public"."audit_logs" FOR SELECT USING (("public"."current_user_role"() = 'admin'::"text"));



ALTER TABLE "public"."center_subjects" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "center_subjects_admin_all" ON "public"."center_subjects" USING (("public"."current_user_role"() = ANY (ARRAY['center_admin'::"text", 'system_admin'::"text"])));



CREATE POLICY "center_subjects_read" ON "public"."center_subjects" FOR SELECT USING (true);



ALTER TABLE "public"."center_teachers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "center_teachers_admin_all" ON "public"."center_teachers" USING (("public"."current_user_role"() = 'admin'::"text")) WITH CHECK (("public"."current_user_role"() = 'admin'::"text"));



CREATE POLICY "center_teachers_select" ON "public"."center_teachers" FOR SELECT USING (true);



ALTER TABLE "public"."certificates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."course_enrollments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."course_timeline" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."courses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "courses_student_select" ON "public"."courses" FOR SELECT USING ((("id" IN ( SELECT "course_enrollments"."course_id"
   FROM "public"."course_enrollments"
  WHERE ("course_enrollments"."student_id" = "auth"."uid"()))) OR ("is_published" = true)));



CREATE POLICY "courses_teacher_all" ON "public"."courses" USING ((("teacher_id" = "auth"."uid"()) OR ("public"."current_user_role"() = 'system_admin'::"text")));



ALTER TABLE "public"."downloads" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "downloads_student_all" ON "public"."downloads" USING (("student_id" = ("auth"."uid"())::"text"));



CREATE POLICY "enrollments_student_manage" ON "public"."course_enrollments" USING (("student_id" = "auth"."uid"()));



CREATE POLICY "enrollments_teacher_view" ON "public"."course_enrollments" FOR SELECT USING ((("course_id" IN ( SELECT "courses"."id"
   FROM "public"."courses"
  WHERE ("courses"."teacher_id" = "auth"."uid"()))) OR ("public"."current_user_role"() = ANY (ARRAY['center_admin'::"text", 'system_admin'::"text"]))));



ALTER TABLE "public"."lessons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."module_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."modules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quizzes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "registrations_admin_all" ON "public"."als_center_registrations" TO "authenticated" USING (("public"."current_user_role"() = 'system_admin'::"text"));



CREATE POLICY "registrations_public_insert" ON "public"."als_center_registrations" FOR INSERT WITH CHECK (true);



ALTER TABLE "public"."scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sessions_student_select" ON "public"."sessions" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "sessions_teacher_all" ON "public"."sessions" USING (("teacher_id" = ("auth"."uid"())::"text"));



ALTER TABLE "public"."students" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "students_admin_all" ON "public"."students" USING (("public"."current_user_role"() = 'admin'::"text"));



CREATE POLICY "students_own_insert" ON "public"."students" FOR INSERT WITH CHECK (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "students_own_select" ON "public"."students" FOR SELECT USING (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "students_own_update" ON "public"."students" FOR UPDATE USING (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "students_teacher_select" ON "public"."students" FOR SELECT USING (("public"."current_user_role"() = ANY (ARRAY['teacher'::"text", 'admin'::"text"])));



ALTER TABLE "public"."system_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "system_settings_admin_all" ON "public"."system_settings" USING (("public"."current_user_role"() = 'admin'::"text")) WITH CHECK (("public"."current_user_role"() = 'admin'::"text"));



ALTER TABLE "public"."teachers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "teachers_admin_all" ON "public"."teachers" USING (("public"."current_user_role"() = 'admin'::"text"));



CREATE POLICY "teachers_own_insert" ON "public"."teachers" FOR INSERT WITH CHECK (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "teachers_own_select" ON "public"."teachers" FOR SELECT USING (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "teachers_own_update" ON "public"."teachers" FOR UPDATE USING (("user_id" = ("auth"."uid"())::"text"));



CREATE POLICY "teachers_student_select" ON "public"."teachers" FOR SELECT USING (("auth"."uid"() IS NOT NULL));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."approve_center_registration"("p_registration_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_center_registration"("p_registration_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_center_registration"("p_registration_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_center_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_center_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_center_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_lesson"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_lesson"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_lesson"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_progress"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_progress"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_progress"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_student_lrn"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_student_lrn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_student_lrn"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_user_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_user_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_user_email"() TO "service_role";


















GRANT ALL ON TABLE "public"."als_center_registrations" TO "anon";
GRANT ALL ON TABLE "public"."als_center_registrations" TO "authenticated";
GRANT ALL ON TABLE "public"."als_center_registrations" TO "service_role";



GRANT ALL ON TABLE "public"."als_centers" TO "anon";
GRANT ALL ON TABLE "public"."als_centers" TO "authenticated";
GRANT ALL ON TABLE "public"."als_centers" TO "service_role";



GRANT ALL ON TABLE "public"."announcement_comments" TO "anon";
GRANT ALL ON TABLE "public"."announcement_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."announcement_comments" TO "service_role";



GRANT ALL ON TABLE "public"."announcements" TO "anon";
GRANT ALL ON TABLE "public"."announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."announcements" TO "service_role";



GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";



GRANT ALL ON TABLE "public"."center_subjects" TO "anon";
GRANT ALL ON TABLE "public"."center_subjects" TO "authenticated";
GRANT ALL ON TABLE "public"."center_subjects" TO "service_role";



GRANT ALL ON TABLE "public"."center_teachers" TO "anon";
GRANT ALL ON TABLE "public"."center_teachers" TO "authenticated";
GRANT ALL ON TABLE "public"."center_teachers" TO "service_role";



GRANT ALL ON TABLE "public"."certificates" TO "anon";
GRANT ALL ON TABLE "public"."certificates" TO "authenticated";
GRANT ALL ON TABLE "public"."certificates" TO "service_role";



GRANT ALL ON TABLE "public"."course_enrollments" TO "anon";
GRANT ALL ON TABLE "public"."course_enrollments" TO "authenticated";
GRANT ALL ON TABLE "public"."course_enrollments" TO "service_role";



GRANT ALL ON TABLE "public"."course_timeline" TO "anon";
GRANT ALL ON TABLE "public"."course_timeline" TO "authenticated";
GRANT ALL ON TABLE "public"."course_timeline" TO "service_role";



GRANT ALL ON TABLE "public"."courses" TO "anon";
GRANT ALL ON TABLE "public"."courses" TO "authenticated";
GRANT ALL ON TABLE "public"."courses" TO "service_role";



GRANT ALL ON TABLE "public"."districts" TO "anon";
GRANT ALL ON TABLE "public"."districts" TO "authenticated";
GRANT ALL ON TABLE "public"."districts" TO "service_role";



GRANT ALL ON TABLE "public"."downloads" TO "anon";
GRANT ALL ON TABLE "public"."downloads" TO "authenticated";
GRANT ALL ON TABLE "public"."downloads" TO "service_role";



GRANT ALL ON TABLE "public"."lessons" TO "anon";
GRANT ALL ON TABLE "public"."lessons" TO "authenticated";
GRANT ALL ON TABLE "public"."lessons" TO "service_role";



GRANT ALL ON TABLE "public"."module_progress" TO "anon";
GRANT ALL ON TABLE "public"."module_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."module_progress" TO "service_role";



GRANT ALL ON TABLE "public"."modules" TO "anon";
GRANT ALL ON TABLE "public"."modules" TO "authenticated";
GRANT ALL ON TABLE "public"."modules" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."questions" TO "anon";
GRANT ALL ON TABLE "public"."questions" TO "authenticated";
GRANT ALL ON TABLE "public"."questions" TO "service_role";



GRANT ALL ON TABLE "public"."quizzes" TO "anon";
GRANT ALL ON TABLE "public"."quizzes" TO "authenticated";
GRANT ALL ON TABLE "public"."quizzes" TO "service_role";



GRANT ALL ON TABLE "public"."scores" TO "anon";
GRANT ALL ON TABLE "public"."scores" TO "authenticated";
GRANT ALL ON TABLE "public"."scores" TO "service_role";



GRANT ALL ON TABLE "public"."sessions" TO "anon";
GRANT ALL ON TABLE "public"."sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."sessions" TO "service_role";



GRANT ALL ON TABLE "public"."students" TO "anon";
GRANT ALL ON TABLE "public"."students" TO "authenticated";
GRANT ALL ON TABLE "public"."students" TO "service_role";



GRANT ALL ON TABLE "public"."system_settings" TO "anon";
GRANT ALL ON TABLE "public"."system_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."system_settings" TO "service_role";



GRANT ALL ON TABLE "public"."teachers" TO "anon";
GRANT ALL ON TABLE "public"."teachers" TO "authenticated";
GRANT ALL ON TABLE "public"."teachers" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































