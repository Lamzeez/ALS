-- ==========================================
-- PROFILE UPDATES MIGRATION
-- Adds: approval_status, onboarding_completed, employee_id
-- ==========================================

-- 1. ADD COLUMNS TO PROFILES
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'approved' CHECK (approval_status IN ('pending', 'approved', 'rejected'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT TRUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS employee_id TEXT;

-- 2. UPDATE EXISTING TEACHERS TO PENDING (Optional, if you want manual approval for all current teachers)
-- UPDATE profiles SET approval_status = 'pending' WHERE role = 'teacher';

-- 3. ENSURE NEW TEACHERS ARE PENDING BY DEFAULT (Via Trigger or Application Logic)
-- For now, the application will handle the logic, but we can set a column default if needed.
-- But the CHECK constraint and DEFAULT handle basic SQL safety.
