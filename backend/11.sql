-- =====================================================
-- 11. SCHEMA FIXES - CONNECTION & IDENTITY CORRECTIONS
-- =====================================================
-- Run this AFTER 10.sql has been applied.
-- Fixes the user_connections FK type and adds missing
-- role constraint, RLS policies for profiles, and a
-- UNIQUE constraint to prevent duplicate connections.
-- =====================================================

-- 1. Fix role constraint to allow 'connected' user type
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
    CHECK (role IN ('user', 'deaf', 'connected', 'admin', 'super_admin'));

-- 2. Drop the old user_connections table (had wrong FK type on connected_user_id)
--    and recreate with correct schema.
DROP TABLE IF EXISTS user_connections CASCADE;

CREATE TABLE user_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    connected_user_id TEXT NOT NULL,          -- stores UCxxxx / CCxxxx text ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE(user_id, connected_user_id)        -- prevent duplicate connections
);

CREATE INDEX IF NOT EXISTS idx_user_connections_user_id ON user_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_connections_connected_id ON user_connections(connected_user_id);

-- 3. RLS for user_connections (drop old policies first, then recreate)
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own connections" ON user_connections;
DROP POLICY IF EXISTS "Users can create their own connections" ON user_connections;
DROP POLICY IF EXISTS "Users can delete their own connections" ON user_connections;

CREATE POLICY "Users can view their own connections"
    ON user_connections FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own connections"
    ON user_connections FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own connections"
    ON user_connections FOR DELETE
    USING (auth.uid() = user_id);

-- 4. RLS for profiles (safe to add if not already present)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

CREATE POLICY "Users can read own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);
