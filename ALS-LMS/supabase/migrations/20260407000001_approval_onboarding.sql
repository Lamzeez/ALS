-- ============================================================
-- Migration: Teacher Approval + Onboarding Flags
-- ============================================================

-- 1. Add approval_status to profiles
--    Existing users: default 'approved' (they're already in)
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'approved'
        CHECK (approval_status IN ('pending', 'approved', 'rejected'));

-- 2. Add onboarding_completed to profiles
--    Existing users: default TRUE (they are already set up)
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT true;

-- 3. Update the handle_new_user trigger so that brand-new sign-ups
--    (including Google OAuth auto-creates) start with onboarding_completed = false.
--    Email/password registrations then flip it to true in the same update call.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, avatar_url, onboarding_completed)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New User'),
        NEW.email,
        NEW.raw_user_meta_data->>'avatar_url',
        false   -- require onboarding for all new sign-ups
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RLS: Admins may update approval_status for teachers
--    (The existing "Users can update own profile" policy remains so users
--     can still update their own name/avatar/lrn etc.)
CREATE POLICY "Admins can update approval status"
    ON public.profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.role::text IN ('school_admin', 'dev_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.role::text IN ('school_admin', 'dev_admin')
        )
    );

-- 5. Index for fast pending-teacher queries in Admin UI
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status
    ON public.profiles (role, approval_status)
    WHERE role = 'teacher';
