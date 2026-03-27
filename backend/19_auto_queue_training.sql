-- =====================================================
-- 19. AUTO-QUEUE TRAINING ON AUDIO SUBMISSION
-- =====================================================
-- Automatically creates a training_queue entry and
-- initializes user_training_status when new audio
-- samples are uploaded.
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_audio_submission()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Insert into training_queue
    INSERT INTO training_queue (audio_submission_id, status, priority)
    VALUES (NEW.id, 'queued', 0);

    -- 2. Initialize or Update user_training_status
    INSERT INTO user_training_status (user_id, trained_name_id, status, progress_percentage)
    VALUES (NEW.user_id, NEW.trained_name_id, 'NOT_STARTED', 0)
    ON CONFLICT (user_id, trained_name_id) 
    DO UPDATE SET 
        status = 'NOT_STARTED',
        progress_percentage = 0,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-queue
DROP TRIGGER IF EXISTS on_audio_submission_created ON audio_submissions;
CREATE TRIGGER on_audio_submission_created
    AFTER INSERT ON audio_submissions
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_audio_submission();

COMMENT ON FUNCTION handle_new_audio_submission IS 'Automatically initiates training pipeline when audio clips are uploaded';
