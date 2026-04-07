-- ==========================================
-- ALS-LMS COMPINED MIGRATION SCRIPT
-- RUN THIS IN SUPABASE SQL EDITOR
-- ==========================================

-- 1. CORE SCHEMA (Districts, Profiles, Cohorts)
-- Source: 20260405000001_core_schema.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS districts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    region TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'school_admin', 'dev_admin')),
    lrn TEXT UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT,
    district_id UUID REFERENCES districts(id),
    avatar_url TEXT,
    device_id TEXT, -- For remote kill switch
    phone_number TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cohorts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    district_id UUID NOT NULL REFERENCES districts(id),
    name TEXT NOT NULL,
    barangay TEXT,
    coordinator_id UUID REFERENCES profiles(id),
    academic_year TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES profiles(id),
    cohort_id UUID NOT NULL REFERENCES cohorts(id),
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'withdrawn', 'completed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, cohort_id)
);

-- 2. CURRICULUM CONTENT
-- Source: 20260405000002_curriculum_content.sql
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    strand TEXT NOT NULL, -- LS1, LS2, etc.
    teacher_id UUID REFERENCES profiles(id),
    cohort_id UUID REFERENCES cohorts(id),
    blueprint_id UUID, -- If this is a clone, tracks origin
    is_blueprint BOOLEAN DEFAULT FALSE,
    is_published BOOLEAN DEFAULT FALSE,
    schema_version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    module_type TEXT DEFAULT 'core' CHECK (module_type IN ('core', 'elective')),
    order_index INTEGER DEFAULT 0,
    prerequisite_id UUID REFERENCES modules(id),
    passing_threshold FLOAT DEFAULT 75.0,
    estimated_hours FLOAT,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content_json JSONB, -- For Rich Text / Blocks
    content_type TEXT DEFAULT 'text',
    order_index INTEGER DEFAULT 0,
    duration_minutes INTEGER,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lesson_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    storage_url TEXT NOT NULL, -- Supabase Storage URL
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL, -- video, audio, pdf
    file_size_bytes BIGINT,
    mime_type TEXT,
    is_downloadable BOOLEAN DEFAULT TRUE,
    order_index INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
    module_id UUID REFERENCES modules(id) ON DELETE CASCADE, -- Can be lesson-end or module-end
    title TEXT NOT NULL,
    description TEXT,
    passing_score FLOAT DEFAULT 75.0,
    time_limit_mins INTEGER,
    max_attempts INTEGER DEFAULT 3,
    shuffle_questions BOOLEAN DEFAULT FALSE,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quiz_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
    question_type TEXT NOT NULL DEFAULT 'multiple_choice',
    question_json JSONB NOT NULL, -- {question: "", options: [], answer: ""}
    order_index INTEGER DEFAULT 0,
    points FLOAT DEFAULT 1.0
);

-- 3. PROGRESS TRACKING
-- Source: 20260405000003_student_progress.sql
CREATE TABLE IF NOT EXISTS module_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES profiles(id),
    module_id UUID NOT NULL REFERENCES modules(id),
    course_id UUID NOT NULL REFERENCES courses(id),
    status TEXT DEFAULT 'locked' CHECK (status IN ('locked', 'available', 'in_progress', 'completed', 'mastered')),
    mastery_score FLOAT DEFAULT 0.0,
    lessons_viewed INTEGER DEFAULT 0,
    total_lessons INTEGER DEFAULT 0,
    time_spent_mins INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, module_id)
);

CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES profiles(id),
    quiz_id UUID NOT NULL REFERENCES quizzes(id),
    score FLOAT NOT NULL,
    max_score FLOAT NOT NULL,
    percentage FLOAT GENERATED ALWAYS AS (score / max_score * 100) STORED,
    attempt_num INTEGER DEFAULT 1,
    answers_json JSONB,
    time_taken_secs INTEGER,
    is_passing BOOLEAN,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, quiz_id, attempt_num)
);

CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES profiles(id),
    teacher_id UUID NOT NULL REFERENCES profiles(id),
    cohort_id UUID NOT NULL REFERENCES cohorts(id),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'present' CHECK (status IN ('present', 'absent', 'late', 'excused')),
    notes TEXT,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, date)
);

CREATE TABLE IF NOT EXISTS submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES profiles(id),
    lesson_id UUID REFERENCES lessons(id),
    quiz_id UUID REFERENCES quizzes(id),
    status TEXT DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'graded', 'returned')),
    content_json JSONB,
    storage_urls TEXT[], -- Array of file links
    grade FLOAT,
    graded_by UUID REFERENCES profiles(id),
    graded_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS submission_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    submission_id UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES profiles(id),
    comment_text TEXT,
    markup_json JSONB, -- For PDF annotations
    attachment_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. SYNC & AUDIT
-- Source: 20260405000004_sync_audit.sql
CREATE TABLE IF NOT EXISTS sync_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    device_id TEXT,
    device_info JSONB,
    current_strand TEXT,
    approx_lat FLOAT,
    approx_lng FLOAT,
    records_pushed INTEGER DEFAULT 0,
    records_pulled INTEGER DEFAULT 0,
    sync_duration_ms INTEGER,
    schema_version INTEGER,
    last_sync_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID REFERENCES profiles(id),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    old_data JSONB,
    new_data JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. RLS POLICIES (Simplified for Start)
-- Source: 20260405000005_rls_policies.sql
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cohorts ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE module_progress ENABLE ROW LEVEL SECURITY;

-- Basic Policies (Everyone can read curriculum if active)
CREATE POLICY "Public districts are viewable by everyone" ON districts FOR SELECT USING (true);
CREATE POLICY "Users can view their own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Profiles are viewable by district teachers" ON profiles FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role IN ('teacher', 'school_admin') AND p.district_id = profiles.district_id)
);
CREATE POLICY "Courses viewable by enrolled students" ON courses FOR SELECT USING (
    is_published = true OR auth.uid() = teacher_id
);

-- 6. VIEWS & FUNCTIONS
-- Source: 20260405000006_views_functions.sql
CREATE OR REPLACE VIEW student_rankings AS
SELECT 
    p.full_name,
    p.district_id,
    SUM(mp.mastery_score) as total_mastery,
    COUNT(mp.id) FILTER (WHERE mp.status = 'mastered') as modules_mastered
FROM profiles p
JOIN module_progress mp ON p.id = mp.student_id
GROUP BY p.id, p.full_name, p.district_id;
