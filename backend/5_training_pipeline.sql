-- =====================================================
-- VIBRO — Training Pipeline Schema + Storage
-- =====================================================
-- Creates user_training_status table for real-time
-- training lifecycle tracking, and the trained_models
-- storage bucket with RLS policies.
-- Run this in Supabase SQL Editor.
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

-- Auto-update timestamp trigger
CREATE TRIGGER update_user_training_status_updated_at
    BEFORE UPDATE ON user_training_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE user_training_status IS 'Real-time training lifecycle tracking per name';

-- =====================================================
-- 2. ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE user_training_status ENABLE ROW LEVEL SECURITY;

-- Users can read their own training status
CREATE POLICY "Users can view own training status"
    ON user_training_status FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can insert training status (from Colab)
CREATE POLICY "Service role can insert training status"
    ON user_training_status FOR INSERT
    WITH CHECK (true);

-- Service role can update training status (from Colab)
CREATE POLICY "Service role can update training status"
    ON user_training_status FOR UPDATE
    USING (true);

-- Users can delete their own training status
CREATE POLICY "Users can delete own training status"
    ON user_training_status FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can view all training statuses
CREATE POLICY "Admins can view all training statuses"
    ON user_training_status FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3. ENABLE REALTIME FOR TRAINING STATUS
-- =====================================================

ALTER PUBLICATION supabase_realtime ADD TABLE user_training_status;

-- =====================================================
-- 4. TRAINED_MODELS STORAGE BUCKET
-- =====================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'trained_models',
    'trained_models',
    false,
    5242880,                      -- 5MB max per model file
    ARRAY['application/octet-stream']
)
ON CONFLICT (id) DO NOTHING;

-- Users can read their own models
CREATE POLICY "Users can read own models"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'trained_models'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Service role uploads models (Colab uses service role key)
CREATE POLICY "Service role can upload models"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'trained_models'
    );

-- Service role can update/overwrite models
CREATE POLICY "Service role can update models"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'trained_models'
    );
