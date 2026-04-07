-- ============================================================
-- Migration 003: Student Progress & Grading
-- Module Progress, Scores, Attendance, Submission Comments
-- ============================================================

-- ============================================================
-- 1. MODULE_PROGRESS - Mastery tracking
-- ============================================================
CREATE TYPE public.progress_status AS ENUM ('locked', 'available', 'in_progress', 'completed', 'mastered');

CREATE TABLE public.module_progress (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    module_id       UUID NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
    course_id       UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    status          public.progress_status NOT NULL DEFAULT 'locked',
    mastery_score   DECIMAL(5,2) DEFAULT 0.00,            -- Percentage mastery (0-100)
    lessons_viewed  INTEGER NOT NULL DEFAULT 0,
    total_lessons   INTEGER NOT NULL DEFAULT 0,
    time_spent_mins INTEGER NOT NULL DEFAULT 0,            -- Accumulated study time
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    synced_at       TIMESTAMPTZ,                           -- Last cloud sync timestamp
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(student_id, module_id)
);

COMMENT ON TABLE public.module_progress IS 'Tracks student mastery and progress per module with offline sync support';

-- ============================================================
-- 2. SCORES - Quiz attempt records
-- ============================================================
CREATE TABLE public.scores (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    quiz_id         UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    score           DECIMAL(5,2) NOT NULL,
    max_score       DECIMAL(5,2) NOT NULL,
    percentage      DECIMAL(5,2) GENERATED ALWAYS AS (
                        CASE WHEN max_score > 0 THEN (score / max_score) * 100 ELSE 0 END
                    ) STORED,
    attempt_num     INTEGER NOT NULL DEFAULT 1,
    answers_json    JSONB,                                 -- Student's answer data
    time_taken_secs INTEGER,                               -- How long the attempt took
    is_passing      BOOLEAN GENERATED ALWAYS AS (
                        CASE WHEN max_score > 0 THEN (score / max_score) * 100 >= 75 ELSE false END
                    ) STORED,
    synced_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(student_id, quiz_id, attempt_num)
);

COMMENT ON TABLE public.scores IS 'Records every quiz attempt with auto-calculated percentage and pass/fail';

-- ============================================================
-- 3. ATTENDANCE - Offline-capable attendance logs
-- ============================================================
CREATE TYPE public.attendance_status AS ENUM ('present', 'absent', 'late', 'excused');

CREATE TABLE public.attendance (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    teacher_id      UUID NOT NULL REFERENCES public.profiles(id),
    cohort_id       UUID NOT NULL REFERENCES public.cohorts(id),
    date            DATE NOT NULL,
    status          public.attendance_status NOT NULL DEFAULT 'present',
    notes           TEXT,
    synced_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(student_id, date)
);

COMMENT ON TABLE public.attendance IS 'Field attendance records with offline sync support';

-- ============================================================
-- 4. SUBMISSIONS - Student work submissions
-- ============================================================
CREATE TYPE public.submission_status AS ENUM ('draft', 'submitted', 'graded', 'returned');

CREATE TABLE public.submissions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    lesson_id       UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    quiz_id         UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    status          public.submission_status NOT NULL DEFAULT 'draft',
    content_json    JSONB,                                 -- Submitted content
    storage_urls    TEXT[],                                 -- Array of uploaded file URLs
    grade           DECIMAL(5,2),
    graded_by       UUID REFERENCES public.profiles(id),
    graded_at       TIMESTAMPTZ,
    synced_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.submissions IS 'Student work submissions for grading via SpeedGrader';

-- ============================================================
-- 5. SUBMISSION_COMMENTS - SpeedGrader markup storage
-- ============================================================
CREATE TABLE public.submission_comments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    submission_id   UUID NOT NULL REFERENCES public.submissions(id) ON DELETE CASCADE,
    teacher_id      UUID NOT NULL REFERENCES public.profiles(id),
    comment_text    TEXT,
    markup_json     JSONB,                                 -- SVG/drawing layer data from SpeedGrader
    attachment_url  TEXT,                                   -- Optional file attachment
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.submission_comments IS 'Teacher feedback and SpeedGrader markup on student submissions';

-- ============================================================
-- Apply updated_at triggers
-- ============================================================
CREATE TRIGGER set_module_progress_updated_at
    BEFORE UPDATE ON public.module_progress
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_attendance_updated_at
    BEFORE UPDATE ON public.attendance
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_submissions_updated_at
    BEFORE UPDATE ON public.submissions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_submission_comments_updated_at
    BEFORE UPDATE ON public.submission_comments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
