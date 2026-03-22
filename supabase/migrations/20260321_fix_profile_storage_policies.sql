-- Fix profile pictures storage policies to allow users to update and delete their own pictures.
-- Note: In this development setup, we allow all authenticated users (even with anon key) 
-- to manage the profile-pictures bucket because the app uses Firebase for primary Auth.

-- 1. Ensure the bucket exists
INSERT INTO storage.buckets (id, name, public) 
VALUES ('profile-pictures', 'profile-pictures', true) 
ON CONFLICT DO NOTHING;

-- 2. Drop existing restrictive policies if they exist
DO $$
BEGIN
    EXECUTE 'DROP POLICY IF EXISTS profile_pictures_owner_insert ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS profile_pictures_owner_update ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS profile_pictures_owner_delete ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS profile_pictures_public_select ON storage.objects';
END$$;

-- 3. Create permissive policies for development
-- (Allows any authenticated/anon user to manage objects in this specific bucket)

CREATE POLICY profile_pictures_permissive_insert ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'profile-pictures');

CREATE POLICY profile_pictures_permissive_update ON storage.objects FOR UPDATE
USING (bucket_id = 'profile-pictures')
WITH CHECK (bucket_id = 'profile-pictures');

CREATE POLICY profile_pictures_permissive_delete ON storage.objects FOR DELETE
USING (bucket_id = 'profile-pictures');

CREATE POLICY profile_pictures_permissive_select ON storage.objects FOR SELECT
USING (bucket_id = 'profile-pictures');
