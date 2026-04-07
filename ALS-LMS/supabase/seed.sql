-- ============================================================
-- Seed Data: ALS-LMS Test Environment
-- 1 District, 2 Cohorts, 5 Students, 2 Teachers, 1 Admin
-- ============================================================

-- Note: This seed file creates test data AFTER auth users are created.
-- Users must first be created via Supabase Auth (Dashboard or API),
-- then this script populates the remaining tables.

-- ============================================================
-- 1. DISTRICTS
-- ============================================================
INSERT INTO public.districts (id, name, region) VALUES
    ('d0000001-0000-0000-0000-000000000001', 'Division of Quezon City', 'NCR'),
    ('d0000001-0000-0000-0000-000000000002', 'Division of Laguna', 'Region IV-A');

-- ============================================================
-- 2. COHORTS
-- ============================================================
INSERT INTO public.cohorts (id, district_id, name, barangay, academic_year) VALUES
    ('c0000001-0000-0000-0000-000000000001', 'd0000001-0000-0000-0000-000000000001', 'Barangay Commonwealth ALS', 'Commonwealth', '2026-2027'),
    ('c0000001-0000-0000-0000-000000000002', 'd0000001-0000-0000-0000-000000000001', 'Barangay Holy Spirit ALS', 'Holy Spirit', '2026-2027'),
    ('c0000001-0000-0000-0000-000000000003', 'd0000001-0000-0000-0000-000000000002', 'Barangay San Pablo ALS', 'San Pablo', '2026-2027');

-- ============================================================
-- 3. SAMPLE COURSES (Blueprint + Child)
-- ============================================================
INSERT INTO public.courses (id, title, description, strand, is_blueprint, is_published, schema_version) VALUES
    -- Blueprint courses (master templates)
    ('cr000001-0000-0000-0000-000000000001', 'Communication Skills - ALS A&E', 'Master blueprint for Communication Skills (English & Filipino)', 'communication_skills', true, true, 1),
    ('cr000001-0000-0000-0000-000000000002', 'Mathematical Literacy - ALS A&E', 'Master blueprint for Mathematical & Problem-Solving Skills', 'mathematical_literacy', true, true, 1),
    ('cr000001-0000-0000-0000-000000000003', 'Scientific Literacy - ALS A&E', 'Master blueprint for Scientific Literacy & Critical Thinking', 'scientific_literacy', true, true, 1);

-- ============================================================
-- 4. SAMPLE MODULES (with prerequisite chains)
-- ============================================================
-- Communication Skills modules
INSERT INTO public.modules (id, course_id, title, description, module_type, order_index, prerequisite_id, passing_threshold, estimated_hours, is_published) VALUES
    ('mo000001-0000-0000-0000-000000000001', 'cr000001-0000-0000-0000-000000000001', 'Module 1: Basic Reading Comprehension', 'Foundation reading skills for ALS learners', 'core', 1, NULL, 75.00, 8.0, true),
    ('mo000001-0000-0000-0000-000000000002', 'cr000001-0000-0000-0000-000000000001', 'Module 2: Writing Fundamentals', 'Basic paragraph and essay writing', 'core', 2, 'mo000001-0000-0000-0000-000000000001', 75.00, 10.0, true),
    ('mo000001-0000-0000-0000-000000000003', 'cr000001-0000-0000-0000-000000000001', 'Module 3: Oral Communication', 'Speaking and listening skills', 'core', 3, 'mo000001-0000-0000-0000-000000000002', 75.00, 6.0, true);

-- Math modules
INSERT INTO public.modules (id, course_id, title, description, module_type, order_index, prerequisite_id, passing_threshold, estimated_hours, is_published) VALUES
    ('mo000002-0000-0000-0000-000000000001', 'cr000001-0000-0000-0000-000000000002', 'Module 1: Number Sense & Operations', 'Basic arithmetic and number theory', 'core', 1, NULL, 75.00, 12.0, true),
    ('mo000002-0000-0000-0000-000000000002', 'cr000001-0000-0000-0000-000000000002', 'Module 2: Algebra Basics', 'Introduction to algebraic expressions', 'core', 2, 'mo000002-0000-0000-0000-000000000001', 75.00, 14.0, true),
    ('mo000002-0000-0000-0000-000000000003', 'cr000001-0000-0000-0000-000000000002', 'Module 3: Geometry & Measurement', 'Shapes, areas, volumes', 'core', 3, 'mo000002-0000-0000-0000-000000000002', 80.00, 10.0, true);

-- ============================================================
-- 5. SAMPLE LESSONS
-- ============================================================
INSERT INTO public.lessons (id, module_id, title, content_json, content_type, order_index, duration_minutes, is_published) VALUES
    -- Module 1: Reading Comprehension lessons
    ('le000001-0000-0000-0000-000000000001', 'mo000001-0000-0000-0000-000000000001', 'Lesson 1: Understanding Main Ideas',
        '{"blocks": [{"type": "header", "text": "What is a Main Idea?"}, {"type": "paragraph", "text": "The main idea is the central message of a text. It tells you what the author wants you to know about the topic."}, {"type": "example", "text": "Read the following paragraph and identify the main idea..."}, {"type": "tip", "text": "Look for sentences that summarize the entire paragraph."}]}',
        'text', 1, 30, true),
    ('le000001-0000-0000-0000-000000000002', 'mo000001-0000-0000-0000-000000000001', 'Lesson 2: Finding Supporting Details',
        '{"blocks": [{"type": "header", "text": "Supporting Details"}, {"type": "paragraph", "text": "Supporting details are facts, examples, or descriptions that back up the main idea."}, {"type": "activity", "text": "Read the story and list three supporting details..."}]}',
        'text', 2, 25, true),
    ('le000001-0000-0000-0000-000000000003', 'mo000001-0000-0000-0000-000000000001', 'Lesson 3: Context Clues in Reading',
        '{"blocks": [{"type": "header", "text": "Using Context Clues"}, {"type": "paragraph", "text": "Context clues are hints found in a sentence that help you figure out the meaning of an unfamiliar word."}]}',
        'text', 3, 20, true),
    -- Module 1: Math - Number Sense
    ('le000002-0000-0000-0000-000000000001', 'mo000002-0000-0000-0000-000000000001', 'Lesson 1: Place Value & Number Systems',
        '{"blocks": [{"type": "header", "text": "Understanding Place Value"}, {"type": "paragraph", "text": "Every digit in a number has a place value. The position of a digit determines its value."}, {"type": "example", "text": "In the number 4,523: 4 is in the thousands place, 5 is in the hundreds place..."}]}',
        'text', 1, 35, true),
    ('le000002-0000-0000-0000-000000000002', 'mo000002-0000-0000-0000-000000000001', 'Lesson 2: Addition & Subtraction Strategies',
        '{"blocks": [{"type": "header", "text": "Mental Math Strategies"}, {"type": "paragraph", "text": "Learn efficient ways to add and subtract numbers mentally."}]}',
        'text', 2, 30, true);

-- ============================================================
-- 6. SAMPLE QUIZZES & QUESTIONS
-- ============================================================
INSERT INTO public.quizzes (id, module_id, title, description, passing_score, time_limit_mins, max_attempts, is_published) VALUES
    ('qz000001-0000-0000-0000-000000000001', 'mo000001-0000-0000-0000-000000000001', 'Module 1 Assessment: Reading Comprehension', 'Test your understanding of main ideas, supporting details, and context clues', 75.00, 30, 3, true),
    ('qz000002-0000-0000-0000-000000000001', 'mo000002-0000-0000-0000-000000000001', 'Module 1 Assessment: Number Sense', 'Test your knowledge of place value and basic operations', 75.00, 45, 3, true);

INSERT INTO public.quiz_questions (id, quiz_id, question_type, question_json, order_index, points) VALUES
    -- Reading Comprehension Quiz
    ('qq000001-0000-0000-0000-000000000001', 'qz000001-0000-0000-0000-000000000001', 'multiple_choice',
        '{"text": "What is the main idea of a paragraph?", "options": ["The first sentence", "The central message the author wants to convey", "The last sentence", "A random detail"], "correct_answer": 1, "explanation": "The main idea is the central message or point that the author is making."}',
        1, 2.00),
    ('qq000001-0000-0000-0000-000000000002', 'qz000001-0000-0000-0000-000000000001', 'true_false',
        '{"text": "Supporting details always appear before the main idea.", "correct_answer": false, "explanation": "Supporting details can appear before, after, or around the main idea."}',
        2, 1.00),
    ('qq000001-0000-0000-0000-000000000003', 'qz000001-0000-0000-0000-000000000001', 'multiple_choice',
        '{"text": "Context clues help you:", "options": ["Write better essays", "Understand unfamiliar words", "Memorize vocabulary", "Skip difficult passages"], "correct_answer": 1, "explanation": "Context clues are hints in a sentence that help determine the meaning of unknown words."}',
        3, 2.00),
    -- Math Quiz
    ('qq000002-0000-0000-0000-000000000001', 'qz000002-0000-0000-0000-000000000001', 'multiple_choice',
        '{"text": "In the number 7,395, what is the value of the digit 3?", "options": ["3", "30", "300", "3000"], "correct_answer": 2, "explanation": "The digit 3 is in the hundreds place, so its value is 300."}',
        1, 2.00),
    ('qq000002-0000-0000-0000-000000000002', 'qz000002-0000-0000-0000-000000000001', 'short_answer',
        '{"text": "What is 1,458 + 2,367?", "correct_answer": "3825", "explanation": "1,458 + 2,367 = 3,825"}',
        2, 3.00);

-- ============================================================
-- 7. INITIAL SCHEMA VERSION
-- (Already inserted in migration 006, but included here for completeness)
-- ============================================================
-- Schema version 1 is already seeded by migration 006
