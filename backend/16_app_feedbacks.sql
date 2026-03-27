-- Migration 11: Add app_feedbacks table
-- (Note: The super_admin role is already created in 9.sql)

-- Create app_feedbacks table
CREATE TABLE IF NOT EXISTS app_feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'ignored')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Index for feedbacks
CREATE INDEX IF NOT EXISTS idx_app_feedbacks_status ON app_feedbacks(status);
CREATE INDEX IF NOT EXISTS idx_app_feedbacks_created_at ON app_feedbacks(created_at DESC);

-- Trigger for updated_at
CREATE TRIGGER update_app_feedbacks_updated_at
    BEFORE UPDATE ON app_feedbacks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies for app_feedbacks
ALTER TABLE app_feedbacks ENABLE ROW LEVEL SECURITY;

-- Users can insert their own feedbacks
CREATE POLICY "Users can insert own feedbacks"
    ON app_feedbacks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Only superadmins can view feedbacks
CREATE POLICY "Superadmins can view all feedbacks"
    ON app_feedbacks FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'
    );

-- Only superadmins can update feedbacks
CREATE POLICY "Superadmins can update feedbacks"
    ON app_feedbacks FOR UPDATE
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'super_admin'
    );

-- Fix is_admin function to include super_admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role IN ('admin', 'super_admin')
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

