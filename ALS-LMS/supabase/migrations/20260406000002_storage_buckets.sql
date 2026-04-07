-- ============================================================
-- STORAGE BUCKETS & POLICIES
-- Sets up core buckets for lessons media and profile photos
-- ============================================================

-- 1. Create Buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('lessons-media', 'lessons-media', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('profile-avatars', 'profile-avatars', true) ON CONFLICT (id) DO NOTHING;

-- 2. ENROLLMENT HELPER (to check if user is enrolled in a course)
CREATE OR REPLACE FUNCTION public.is_student_enrolled(course_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.course_enrollments 
        WHERE student_id = auth.uid() 
        AND course_id = course_uuid
        AND status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. LESSONS-MEDIA POLICIES

-- Allow Teachers to upload files to their courses
CREATE POLICY "Teachers can upload media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'lessons-media' 
    AND (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role IN ('teacher', 'dev_admin', 'school_admin')
        )
    )
);

-- Allow everyone authenticated to view lessons-media (public bucket, but tracked)
CREATE POLICY "Anyone can view lessons media"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'lessons-media');

-- Allow Teachers/Admins to update or delete media
CREATE POLICY "Admins can update or delete media"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'lessons-media'
    AND (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role IN ('teacher', 'dev_admin', 'school_admin')
        )
    )
);

-- 4. PROFILE-AVATARS POLICIES

-- Users can upload their own avatar
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Everyone can view avatars
CREATE POLICY "Anyone can view avatars"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'profile-avatars');

-- Users can update or delete their own avatar
CREATE POLICY "Users can update or delete own avatar"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'profile-avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
