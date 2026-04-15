-- Migration: Enable RLS on all tables
-- Date: 2026-04-15
-- Purpose: RLS was not enabled on tables added in previous migrations

-- =============================================
-- Enable Row Level Security on all tables
-- =============================================

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.module_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.center_teachers ENABLE ROW LEVEL SECURITY;

-- These should already be enabled, but just to be sure:
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_media ENABLE ROW LEVEL SECURITY;

-- Note: Views (learning_centers, quiz_questions) don't need RLS enabled
-- They inherit security from underlying tables
