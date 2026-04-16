-- Migration: Final Onboarding & Trigger Fix
-- Date: 2026-04-16
-- Purpose: 
--   1. Fix handle_new_auth_user to respect onboarding_completed from metadata (defaults to true)
--   2. Correctly map learner_reference_number for students
--   3. Ensure NOT NULL constraints for grade_level and specialization are satisfied

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role TEXT;
  raw_lrn TEXT;
  onboarding_done BOOLEAN;
BEGIN
  user_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'student');
  raw_lrn := NULLIF(NEW.raw_user_meta_data->>'student_id_number', '');
  
  -- Use onboarding_completed from metadata if present, otherwise default to true 
  -- because our new registration form collects everything.
  onboarding_done := COALESCE((NEW.raw_user_meta_data->>'onboarding_completed')::boolean, true);

  -- 1. Insert into base 'profiles' table
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    first_name,
    last_name,
    student_id_number,
    employee_id,
    gender,
    birth_date,
    als_center_id,
    onboarding_completed,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
      NULLIF(
        concat_ws(' ', 
          NULLIF(NEW.raw_user_meta_data->>'first_name', ''), 
          NULLIF(NEW.raw_user_meta_data->>'last_name', '')
        ), 
        ''
      ),
      split_part(NEW.email, '@', 1)
    ),
    user_role,
    NULLIF(NEW.raw_user_meta_data->>'first_name', ''),
    NULLIF(NEW.raw_user_meta_data->>'last_name', ''),
    raw_lrn,
    NULLIF(NEW.raw_user_meta_data->>'employee_id', ''),
    NULLIF(NEW.raw_user_meta_data->>'gender', ''),
    CASE 
      WHEN NULLIF(NEW.raw_user_meta_data->>'date_of_birth', '') IS NOT NULL 
      THEN (NEW.raw_user_meta_data->>'date_of_birth')::DATE 
      ELSE NULL 
    END,
    NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''),
    onboarding_done,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    onboarding_completed = EXCLUDED.onboarding_completed,
    updated_at = NOW();

  -- 2. Insert into role-specific tables
  IF user_role = 'student' THEN
    INSERT INTO public.students (user_id, learner_reference_number, als_center_id, date_of_birth, grade_level)
    VALUES (
      NEW.id::text, 
      raw_lrn, -- This maps the app's LRN input to the required 12-digit column
      NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''),
      CASE 
        WHEN NULLIF(NEW.raw_user_meta_data->>'date_of_birth', '') IS NOT NULL 
        THEN (NEW.raw_user_meta_data->>'date_of_birth')::DATE 
        ELSE NULL 
      END,
      'BLP' -- Satisfaction for NOT NULL constraint
    )
    ON CONFLICT (user_id) DO NOTHING;
  ELSIF user_role = 'teacher' THEN
    INSERT INTO public.teachers (user_id, employee_id, als_center_id, specialization)
    VALUES (
      NEW.id::text, 
      NULLIF(NEW.raw_user_meta_data->>'employee_id', ''),
      NULLIF(NEW.raw_user_meta_data->>'als_center_id', ''),
      'General' -- Satisfaction for NOT NULL constraint
    )
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;
