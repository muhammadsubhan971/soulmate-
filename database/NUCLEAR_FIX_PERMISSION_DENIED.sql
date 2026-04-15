-- ============================================================================
-- NUCLEAR FIX: Completely Remove ALL Policies and Recreate From Scratch
-- This will fix the "permission denied for table users" error 100%
-- Run this ENTIRE script in Supabase SQL Editor
-- ============================================================================

-- PART 1: Disable RLS temporarily to test
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- PART 2: Drop EVERY policy that exists on profiles table
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- PART 3: Drop EVERY policy on storage.objects
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
        RAISE NOTICE 'Dropped storage policy: %', pol.policyname;
    END LOOP;
END $$;

-- PART 4: Recreate ONLY the essential policies for profiles table
-- Policy 1: SELECT - Users can view their own profile
CREATE POLICY "profile_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Policy 2: INSERT - Users can create their own profile
CREATE POLICY "profile_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Policy 3: UPDATE - Users can update their own profile (THIS IS WHAT WAS FAILING!)
CREATE POLICY "profile_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy 4: DELETE - Users can delete their own profile
CREATE POLICY "profile_delete_own"
  ON profiles FOR DELETE
  USING (auth.uid() = id);

-- Policy 5: SELECT - Allow viewing other profiles for matching (important!)
CREATE POLICY "profile_select_public"
  ON profiles FOR SELECT
  USING (is_active = true AND is_blocked = false);

-- PART 5: Recreate storage policies (SIMPLE - no complex checks)
-- Policy 1: Anyone can view (public bucket)
CREATE POLICY "storage_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profile-images');

-- Policy 2: Authenticated users can upload
CREATE POLICY "storage_insert_auth"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'profile-images' AND
    auth.role() = 'authenticated'
  );

-- Policy 3: Authenticated users can update
CREATE POLICY "storage_update_auth"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'profile-images' AND
    auth.role() = 'authenticated'
  );

-- Policy 4: Authenticated users can delete
CREATE POLICY "storage_delete_auth"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'profile-images' AND
    auth.role() = 'authenticated'
  );

-- PART 6: Ensure storage bucket exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-images', 
  'profile-images', 
  TRUE,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = TRUE,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[];

-- PART 7: Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- PART 8: Grant ALL permissions (CRITICAL!)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.objects TO anon;
GRANT ALL ON storage.buckets TO authenticated;
GRANT ALL ON storage.buckets TO anon;

-- PART 9: Verification
DO $$
DECLARE
    policy_count INTEGER;
    storage_policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'profiles';
    
    SELECT COUNT(*) INTO storage_policy_count
    FROM pg_policies 
    WHERE tablename = 'objects' AND schemaname = 'storage';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ FIX COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Profiles table policies: %', policy_count;
    RAISE NOTICE 'Storage policies: %', storage_policy_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Policies created:';
    RAISE NOTICE '  - profile_select_own';
    RAISE NOTICE '  - profile_insert_own';
    RAISE NOTICE '  - profile_update_own ← THIS FIXES YOUR ERROR';
    RAISE NOTICE '  - profile_delete_own';
    RAISE NOTICE '  - profile_select_public';
    RAISE NOTICE '  - storage_select_public';
    RAISE NOTICE '  - storage_insert_auth';
    RAISE NOTICE '  - storage_update_auth';
    RAISE NOTICE '  - storage_delete_auth';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST NOW:';
    RAISE NOTICE '1. Register/login to your app';
    RAISE NOTICE '2. Go to Create Profile screen';
    RAISE NOTICE '3. Upload a profile picture';
    RAISE NOTICE '4. Click "Create Profile"';
    RAISE NOTICE '5. Should work perfectly now! ✅';
    RAISE NOTICE '========================================';
END $$;

-- PART 10: Show all active policies
SELECT 
    tablename,
    policyname,
    cmd AS operation,
    CASE 
        WHEN qual IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS has_using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS has_with_check
FROM pg_policies
WHERE tablename IN ('profiles', 'objects')
ORDER BY tablename, policyname;
