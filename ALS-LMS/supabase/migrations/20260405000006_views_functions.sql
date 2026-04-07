-- ============================================================
-- Migration 006: Views & Functions
-- Participation Scores, District Heatmap, Time-on-Task
-- ============================================================

-- ============================================================
-- 1. PARTICIPATION SCORE VIEW
-- Score = (L × 0.2) + (Q × 0.5) + (V × 0.3)
-- L = Lessons Viewed ratio, Q = Quiz Average, V = Resource Downloads ratio
-- ============================================================
CREATE MATERIALIZED VIEW public.mv_participation_scores AS
WITH student_lessons AS (
    -- L: Ratio of lessons viewed to total lessons per course
    SELECT
        mp.student_id,
        mp.course_id,
        CASE WHEN SUM(mp.total_lessons) > 0
            THEN (SUM(mp.lessons_viewed)::DECIMAL / SUM(mp.total_lessons)) * 100
            ELSE 0
        END AS lesson_view_pct
    FROM public.module_progress mp
    GROUP BY mp.student_id, mp.course_id
),
student_quizzes AS (
    -- Q: Average quiz percentage across all attempts
    SELECT
        s.student_id,
        c.id AS course_id,
        COALESCE(AVG(s.percentage), 0) AS quiz_avg
    FROM public.scores s
    JOIN public.quizzes q ON q.id = s.quiz_id
    LEFT JOIN public.modules m ON m.id = q.module_id
    LEFT JOIN public.lessons l ON l.id = q.lesson_id
    LEFT JOIN public.modules m2 ON m2.id = l.module_id
    JOIN public.courses c ON c.id = COALESCE(m.course_id, m2.course_id)
    GROUP BY s.student_id, c.id
),
student_time AS (
    -- V: Time-on-task ratio (normalized to 100 based on estimated hours)
    SELECT
        mp.student_id,
        mp.course_id,
        CASE WHEN SUM(mo.estimated_hours) > 0
            THEN LEAST(
                (SUM(mp.time_spent_mins)::DECIMAL / (SUM(mo.estimated_hours) * 60)) * 100,
                100
            )
            ELSE 0
        END AS time_engagement_pct
    FROM public.module_progress mp
    JOIN public.modules mo ON mo.id = mp.module_id
    GROUP BY mp.student_id, mp.course_id
)
SELECT
    COALESCE(sl.student_id, sq.student_id, st.student_id) AS student_id,
    COALESCE(sl.course_id, sq.course_id, st.course_id) AS course_id,
    COALESCE(sl.lesson_view_pct, 0) AS lessons_viewed_pct,
    COALESCE(sq.quiz_avg, 0) AS quiz_average,
    COALESCE(st.time_engagement_pct, 0) AS time_engagement_pct,
    -- Weighted participation score
    ROUND(
        (COALESCE(sl.lesson_view_pct, 0) * 0.2) +
        (COALESCE(sq.quiz_avg, 0) * 0.5) +
        (COALESCE(st.time_engagement_pct, 0) * 0.3),
        2
    ) AS participation_score,
    now() AS calculated_at
FROM student_lessons sl
FULL OUTER JOIN student_quizzes sq
    ON sl.student_id = sq.student_id AND sl.course_id = sq.course_id
FULL OUTER JOIN student_time st
    ON COALESCE(sl.student_id, sq.student_id) = st.student_id
    AND COALESCE(sl.course_id, sq.course_id) = st.course_id;

-- Index for fast lookups
CREATE UNIQUE INDEX idx_mv_participation_student_course
    ON public.mv_participation_scores (student_id, course_id);

-- ============================================================
-- 2. DISTRICT HEATMAP DATA VIEW
-- Aggregates sync metadata for geographic visualization
-- ============================================================
CREATE MATERIALIZED VIEW public.mv_district_heatmap AS
SELECT
    d.id AS district_id,
    d.name AS district_name,
    d.region,
    c.id AS cohort_id,
    c.name AS cohort_name,
    c.barangay,
    COUNT(DISTINCT e.student_id) AS total_students,
    COUNT(DISTINCT sm.user_id) AS active_sync_students,
    ROUND(
        CASE WHEN COUNT(DISTINCT e.student_id) > 0
            THEN (COUNT(DISTINCT sm.user_id)::DECIMAL / COUNT(DISTINCT e.student_id)) * 100
            ELSE 0
        END,
        2
    ) AS sync_rate_pct,
    AVG(sm.approx_lat) AS avg_lat,
    AVG(sm.approx_lng) AS avg_lng,
    MAX(sm.last_sync_at) AS latest_sync,
    COUNT(sm.id) AS total_syncs_30d,
    now() AS calculated_at
FROM public.districts d
JOIN public.cohorts c ON c.district_id = d.id
LEFT JOIN public.enrollments e ON e.cohort_id = c.id AND e.status = 'active'
LEFT JOIN public.sync_metadata sm
    ON sm.user_id = e.student_id
    AND sm.last_sync_at > now() - INTERVAL '30 days'
GROUP BY d.id, d.name, d.region, c.id, c.name, c.barangay;

CREATE UNIQUE INDEX idx_mv_heatmap_cohort
    ON public.mv_district_heatmap (cohort_id);

-- ============================================================
-- 3. TIME-ON-TASK AGGREGATE VIEW
-- Calculates hours spent per module per student
-- ============================================================
CREATE VIEW public.v_time_on_task AS
SELECT
    mp.student_id,
    p.full_name AS student_name,
    c.title AS course_title,
    c.strand,
    m.title AS module_title,
    m.estimated_hours,
    ROUND(mp.time_spent_mins / 60.0, 2) AS actual_hours,
    CASE
        WHEN m.estimated_hours IS NOT NULL AND m.estimated_hours > 0
        THEN ROUND((mp.time_spent_mins / 60.0) / m.estimated_hours * 100, 2)
        ELSE NULL
    END AS completion_pct,
    mp.status,
    mp.mastery_score,
    mp.started_at,
    mp.completed_at
FROM public.module_progress mp
JOIN public.profiles p ON p.id = mp.student_id
JOIN public.modules m ON m.id = mp.module_id
JOIN public.courses c ON c.id = mp.course_id;

-- ============================================================
-- 4. STUDENT GRADEBOOK VIEW
-- Aggregates all grades for a student across courses
-- ============================================================
CREATE VIEW public.v_student_gradebook AS
SELECT
    s.student_id,
    p.full_name AS student_name,
    p.lrn,
    c.title AS course_title,
    c.strand,
    q.title AS quiz_title,
    s.score,
    s.max_score,
    s.percentage,
    s.is_passing,
    s.attempt_num,
    s.created_at AS attempt_date
FROM public.scores s
JOIN public.profiles p ON p.id = s.student_id
JOIN public.quizzes q ON q.id = s.quiz_id
LEFT JOIN public.modules m ON m.id = q.module_id
LEFT JOIN public.lessons l ON l.id = q.lesson_id
LEFT JOIN public.modules m2 ON m2.id = l.module_id
JOIN public.courses c ON c.id = COALESCE(m.course_id, m2.course_id);

-- ============================================================
-- 5. AT-RISK STUDENT DETECTION VIEW
-- Flags students with low engagement or failing scores
-- ============================================================
CREATE VIEW public.v_at_risk_students AS
SELECT
    p.id AS student_id,
    p.full_name,
    p.lrn,
    e.cohort_id,
    ch.name AS cohort_name,
    ch.barangay,
    -- Last sync check (no sync in 7+ days = concern)
    MAX(sm.last_sync_at) AS last_sync,
    CASE
        WHEN MAX(sm.last_sync_at) < now() - INTERVAL '7 days' THEN true
        WHEN MAX(sm.last_sync_at) IS NULL THEN true
        ELSE false
    END AS no_recent_sync,
    -- Average quiz score
    COALESCE(AVG(sc.percentage), 0) AS avg_quiz_score,
    CASE WHEN COALESCE(AVG(sc.percentage), 0) < 60 THEN true ELSE false END AS low_scores,
    -- Module completion rate
    COUNT(CASE WHEN mp.status IN ('completed', 'mastered') THEN 1 END) AS modules_completed,
    COUNT(mp.id) AS modules_total,
    -- Overall risk flag
    CASE
        WHEN MAX(sm.last_sync_at) IS NULL THEN 'HIGH'
        WHEN MAX(sm.last_sync_at) < now() - INTERVAL '14 days' THEN 'HIGH'
        WHEN MAX(sm.last_sync_at) < now() - INTERVAL '7 days' THEN 'MEDIUM'
        WHEN COALESCE(AVG(sc.percentage), 0) < 50 THEN 'HIGH'
        WHEN COALESCE(AVG(sc.percentage), 0) < 60 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_level
FROM public.profiles p
JOIN public.enrollments e ON e.student_id = p.id AND e.status = 'active'
JOIN public.cohorts ch ON ch.id = e.cohort_id
LEFT JOIN public.sync_metadata sm ON sm.user_id = p.id
LEFT JOIN public.scores sc ON sc.student_id = p.id
LEFT JOIN public.module_progress mp ON mp.student_id = p.id
WHERE p.role = 'student' AND p.is_active = true
GROUP BY p.id, p.full_name, p.lrn, e.cohort_id, ch.name, ch.barangay;

-- ============================================================
-- 6. REFRESH MATERIALIZED VIEWS FUNCTION
-- Called periodically or on-demand by Edge Functions
-- ============================================================
CREATE OR REPLACE FUNCTION public.refresh_analytics_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_participation_scores;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_district_heatmap;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. SCHEMA VERSION TRACKER
-- Used by mobile apps to detect when SQLite needs migration
-- ============================================================
CREATE TABLE public.schema_versions (
    id          SERIAL PRIMARY KEY,
    version     INTEGER NOT NULL UNIQUE,
    description TEXT NOT NULL,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.schema_versions (version, description) VALUES
    (1, 'Initial ALS-LMS schema - Core, Curriculum, Progress, Audit, RLS, Views');

-- RLS for schema_versions (read-only for all authenticated users)
ALTER TABLE public.schema_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view schema versions"
    ON public.schema_versions FOR SELECT
    USING (auth.uid() IS NOT NULL);
