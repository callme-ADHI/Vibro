-- =====================================================
-- 10. SCHEMA UPDATE - USER CONNECTIONS & IDENTITY
-- =====================================================

-- 1. PROFILES IDENTITY UPDATE
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_id TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'deaf';

-- 2. USER CONNECTIONS TABLE
CREATE TABLE IF NOT EXISTS user_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    connected_user_id TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_connections_user_id ON user_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_connections_connected_id ON user_connections(connected_user_id);

-- Optional RLS
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own connections"
    ON user_connections FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own connections"
    ON user_connections FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own connections"
    ON user_connections FOR DELETE
    USING (auth.uid() = user_id);
