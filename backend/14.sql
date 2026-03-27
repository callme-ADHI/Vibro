-- =====================================================
-- 14. FIX RLS - Allow profile lookup for user search
-- =====================================================
-- The previous "Users can read own profile" policy blocked
-- cross-user searches (e.g. searching by UCxxxx / CCxxxx).
-- We need all authenticated users to be able to read
-- any profile's public fields so the connection search works.
-- =====================================================

-- Drop the restrictive read policy on profiles
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;

-- Allow any authenticated user to read profiles (for user search)
CREATE POLICY "Authenticated users can read profiles"
    ON profiles FOR SELECT
    USING (auth.uid() IS NOT NULL);
