-- =====================================================
-- 23. ADD MISSING UPDATED_AT COLUMNS
-- =====================================================
-- Adds updated_at columns to tables that were missing them
-- to avoid 400 errors during updates and improve tracking.
-- =====================================================

-- 1. audio_submissions
ALTER TABLE audio_submissions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- 2. training_queue
ALTER TABLE training_queue ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- 3. trained_models
ALTER TABLE trained_models ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

COMMENT ON COLUMN training_queue.updated_at IS 'Last modification timestamp';
