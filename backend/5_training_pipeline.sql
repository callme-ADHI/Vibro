-- =====================================================
-- VIBRO — Training Pipeline Schema + Storage
-- =====================================================
-- Creates user_training_status table for real-time
-- training lifecycle tracking, and the trained_models
-- storage bucket with RLS policies.
-- Run this in Supabase SQL Editor.
-- Safe to re-run (uses IF NOT EXISTS / DROP IF EXISTS).
-- =====================================================

-- =====================================================
-- 1. USER_TRAINING_STATUS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS user_training_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'NOT_STARTED'
        CHECK (status IN (
            'NOT_STARTED',
            'DOWNLOADING_AUDIO',
            'TRAINING',
            'UPLOADING_MODEL',
            'COMPLETED',
            'FAILED'
        )),
    progress_percentage INTEGER NOT NULL DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    model_version INTEGER,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_training_name UNIQUE (user_id, trained_name_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_training_status_user_id ON user_training_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_training_status_name_id ON user_training_status(trained_name_id);
CREATE INDEX IF NOT EXISTS idx_user_training_status_status ON user_training_status(status);

-- Auto-update timestamp trigger (safe: drops first)
DROP TRIGGER IF EXISTS update_user_training_status_updated_at ON user_training_status;
CREATE TRIGGER update_user_training_status_updated_at
    BEFORE UPDATE ON user_training_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE user_training_status IS 'Real-time training lifecycle tracking per name';

-- =====================================================
-- 2. ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE user_training_status ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first (safe to re-run)
DROP POLICY IF EXISTS "Users can view own training status" ON user_training_status;
DROP POLICY IF EXISTS "Service role can insert training status" ON user_training_status;
DROP POLICY IF EXISTS "Service role can update training status" ON user_training_status;
DROP POLICY IF EXISTS "Users can delete own training status" ON user_training_status;
DROP POLICY IF EXISTS "Admins can view all training statuses" ON user_training_status;

CREATE POLICY "Users can view own training status"
    ON user_training_status FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert training status"
    ON user_training_status FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Service role can update training status"
    ON user_training_status FOR UPDATE
    USING (true);

CREATE POLICY "Users can delete own training status"
    ON user_training_status FOR DELETE
    USING (auth.uid() = user_id);

-- =====================================================
-- 3. ENABLE REALTIME FOR TRAINING STATUS
-- =====================================================

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_training_status;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- =====================================================
-- 4. TRAINED_MODELS STORAGE BUCKET
-- =====================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'trained_models',
    'trained_models',
    false,
    5242880,
    ARRAY['application/octet-stream']
)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies first (safe to re-run)
DROP POLICY IF EXISTS "Users can read own models" ON storage.objects;
DROP POLICY IF EXISTS "Service role can upload models" ON storage.objects;
DROP POLICY IF EXISTS "Service role can update models" ON storage.objects;

CREATE POLICY "Users can read own models"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'trained_models'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Service role can upload models"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'trained_models'
    );

CREATE POLICY "Service role can update models"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'trained_models'
    );
