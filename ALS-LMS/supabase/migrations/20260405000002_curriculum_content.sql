-- ============================================================
-- Migration 002: Curriculum & Content
-- Courses, Modules, Lessons, Media, Quizzes, Quiz Questions
-- ============================================================

-- ============================================================
-- 1. COURSES - With blueprint support
-- ============================================================
CREATE TYPE public.als_strand AS ENUM (
    'communication_skills',       -- Communication Skills (English & Filipino)
    'scientific_literacy',        -- Scientific Literacy & Critical Thinking
    'mathematical_literacy',      -- Mathematical & Problem-Solving Skills
    'life_livelihood_skills',     -- Life and Livelihood Skills
    'digital_literacy',           -- Understanding Self and Society / Digital Lit
    'understanding_self_society'  -- Understanding Self & Society
);

CREATE TABLE public.courses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    description     TEXT,
    strand          public.als_strand NOT NULL,
    teacher_id      UUID REFERENCES public.profiles(id),
    cohort_id       UUID REFERENCES public.cohorts(id),
    blueprint_id    UUID REFERENCES public.courses(id),   -- Parent blueprint reference
    is_blueprint    BOOLEAN NOT NULL DEFAULT false,
    is_published    BOOLEAN NOT NULL DEFAULT false,
    schema_version  INTEGER NOT NULL DEFAULT 1,            -- For SQLite sync versioning
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.courses IS 'ALS Curriculum courses with blueprint/child relationship support';
COMMENT ON COLUMN public.courses.blueprint_id IS 'References the master Blueprint course this was cloned from';
COMMENT ON COLUMN public.courses.schema_version IS 'Incremented on structural changes to trigger SQLite migration on devices';

-- ============================================================
-- 2. MODULES - With prerequisite chaining (self-referential)
-- ============================================================
CREATE TYPE public.module_type AS ENUM ('core', 'elective', 'assessment', 'enrichment');

CREATE TABLE public.modules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id       UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT,
    module_type     public.module_type NOT NULL DEFAULT 'core',
    order_index     INTEGER NOT NULL DEFAULT 0,
    prerequisite_id UUID REFERENCES public.modules(id),   -- Self-ref for prerequisite chain
    passing_threshold DECIMAL(5,2) DEFAULT 75.00,         -- Mastery threshold percentage
    estimated_hours DECIMAL(4,1),                          -- Expected completion time
    is_published    BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.modules IS 'Course modules with sequential prerequisite locking';
COMMENT ON COLUMN public.modules.prerequisite_id IS 'Module that must be completed before this one unlocks';

-- ============================================================
-- 3. LESSONS - Content storage with content_json
-- ============================================================
CREATE TYPE public.lesson_content_type AS ENUM ('text', 'video', 'pdf', 'interactive', 'mixed');

CREATE TABLE public.lessons (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id       UUID NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    content_json    JSONB,                                 -- Rich content (RCE output)
    content_type    public.lesson_content_type NOT NULL DEFAULT 'text',
    order_index     INTEGER NOT NULL DEFAULT 0,
    duration_minutes INTEGER,                              -- Estimated reading/watch time
    is_published    BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.lessons IS 'Individual lesson content within a module';

-- ============================================================
-- 4. LESSON_MEDIA - Supabase Storage URL mapping
-- ============================================================
CREATE TYPE public.media_file_type AS ENUM ('video', 'pdf', 'image', 'audio', 'document');

CREATE TABLE public.lesson_media (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id       UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    storage_url     TEXT NOT NULL,                          -- Supabase Storage path
    file_name       TEXT NOT NULL,
    file_type       public.media_file_type NOT NULL,
    file_size_bytes BIGINT,
    mime_type       TEXT,
    is_downloadable BOOLEAN NOT NULL DEFAULT true,         -- Can students cache locally?
    order_index     INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.lesson_media IS 'Maps Supabase Storage files to lessons for offline caching';

-- ============================================================
-- 5. QUIZZES
-- ============================================================
CREATE TABLE public.quizzes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id       UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    module_id       UUID REFERENCES public.modules(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT,
    passing_score   DECIMAL(5,2) NOT NULL DEFAULT 75.00,
    time_limit_mins INTEGER,                               -- NULL = no limit
    max_attempts    INTEGER DEFAULT 3,
    shuffle_questions BOOLEAN NOT NULL DEFAULT false,
    is_published    BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Quiz must belong to either a lesson or a module
    CONSTRAINT quiz_parent_check CHECK (
        (lesson_id IS NOT NULL AND module_id IS NULL) OR
        (lesson_id IS NULL AND module_id IS NOT NULL)
    )
);

COMMENT ON TABLE public.quizzes IS 'Assessment quizzes attachable to lessons or modules';

-- ============================================================
-- 6. QUIZ_QUESTIONS
-- ============================================================
CREATE TYPE public.question_type AS ENUM ('multiple_choice', 'true_false', 'short_answer', 'matching', 'essay');

CREATE TABLE public.quiz_questions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id         UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    question_type   public.question_type NOT NULL DEFAULT 'multiple_choice',
    question_json   JSONB NOT NULL,                        -- { text, options[], correct_answer, explanation }
    order_index     INTEGER NOT NULL DEFAULT 0,
    points          DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.quiz_questions IS 'Individual quiz questions with JSON-encoded content and answers';

-- ============================================================
-- Apply updated_at triggers
-- ============================================================
CREATE TRIGGER set_courses_updated_at
    BEFORE UPDATE ON public.courses
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_modules_updated_at
    BEFORE UPDATE ON public.modules
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_lessons_updated_at
    BEFORE UPDATE ON public.lessons
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_quizzes_updated_at
    BEFORE UPDATE ON public.quizzes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_quiz_questions_updated_at
    BEFORE UPDATE ON public.quiz_questions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
