-- =====================================================
-- 15. FIX RLS - Training Status, Detection History
--     + relation_models cross-user access
-- =====================================================

-- 1. Allow users to read their own training status
ALTER TABLE user_training_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own training status" ON user_training_status;
CREATE POLICY "Users can read own training status"
    ON user_training_status FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert training status" ON user_training_status;
CREATE POLICY "Users can insert training status"
    ON user_training_status FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update training status" ON user_training_status;
CREATE POLICY "Users can update training status"
    ON user_training_status FOR UPDATE
    USING (auth.uid() = user_id);

-- 2. Allow users to read their own detection_history
ALTER TABLE detection_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own detections" ON detection_history;
CREATE POLICY "Users can read own detections"
    ON detection_history FOR SELECT
    USING (auth.uid() = user_id);

-- 3. Allow connected users to read trained_names of their deaf users
--    (so assigned model names show correctly)
DROP POLICY IF EXISTS "Connected users can read linked deaf trained_names" ON trained_names;
CREATE POLICY "Connected users can read linked deaf trained_names"
    ON trained_names FOR SELECT
    USING (
        auth.uid() = user_id
        OR
        auth.uid() IN (
            SELECT connected_user_id FROM user_relationships
            WHERE deaf_user_id = trained_names.user_id
        )
    );

-- 4. Allow connected users to read relation_models where they are the caregiver
DROP POLICY IF EXISTS "Users can read their relation_models" ON relation_models;
CREATE POLICY "Users can read their relation_models"
    ON relation_models FOR SELECT
    USING (
        relation_id IN (
            SELECT id FROM user_relationships
            WHERE deaf_user_id = auth.uid() OR connected_user_id = auth.uid()
        )
    );

-- 5. Allow connected users to read user_relationships they're part of
ALTER TABLE user_relationships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own relationships" ON user_relationships;
CREATE POLICY "Users can read own relationships"
    ON user_relationships FOR SELECT
    USING (auth.uid() = deaf_user_id OR auth.uid() = connected_user_id);

DROP POLICY IF EXISTS "Deaf users can insert relationships" ON user_relationships;
CREATE POLICY "Deaf users can insert relationships"
    ON user_relationships FOR INSERT
    WITH CHECK (auth.uid() = deaf_user_id);

DROP POLICY IF EXISTS "Deaf users can update relationships" ON user_relationships;
CREATE POLICY "Deaf users can update relationships"
    ON user_relationships FOR UPDATE
    USING (auth.uid() = deaf_user_id);
