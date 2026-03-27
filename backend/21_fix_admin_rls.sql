-- =====================================================
-- 21. FIX ADMIN RLS POLICIES
-- =====================================================
-- Ensure admins can view and manage all training-related
-- tables across the whole system.
-- =====================================================

-- 1. user_training_status
DROP POLICY IF EXISTS "Admins can view all training statuses" ON user_training_status;
CREATE POLICY "Admins can view all training statuses"
    ON user_training_status FOR SELECT
    USING (is_admin());

DROP POLICY IF EXISTS "Admins can update all training statuses" ON user_training_status;
CREATE POLICY "Admins can update all training statuses"
    ON user_training_status FOR UPDATE
    USING (is_admin());

-- 2. audio_submissions
DROP POLICY IF EXISTS "Admins can view all submissions" ON audio_submissions;
CREATE POLICY "Admins can view all submissions"
    ON audio_submissions FOR SELECT
    USING (is_admin());

DROP POLICY IF EXISTS "Admins can update all submissions" ON audio_submissions;
CREATE POLICY "Admins can update all submissions"
    ON audio_submissions FOR UPDATE
    USING (is_admin());

-- 3. trained_names
DROP POLICY IF EXISTS "Admins can view all trained names" ON trained_names;
CREATE POLICY "Admins can view all trained names"
    ON trained_names FOR SELECT
    USING (is_admin());

-- 4. training_queue
DROP POLICY IF EXISTS "Admins can manage training queue" ON training_queue;
CREATE POLICY "Admins can manage training queue"
    ON training_queue FOR ALL
    USING (is_admin());

-- 5. trained_models
DROP POLICY IF EXISTS "Admins can view all models" ON trained_models;
CREATE POLICY "Admins can view all models"
    ON trained_models FOR SELECT
    USING (is_admin());

DROP POLICY IF EXISTS "Admins can manage all models" ON trained_models;
CREATE POLICY "Admins can manage all models"
    ON trained_models FOR INSERT
    WITH CHECK (is_admin());

COMMENT ON POLICY "Admins can view all training statuses" ON user_training_status IS 'Allow admins to monitor progress of all users';
