-- =====================================================
-- 13. SCHEMA - RELATIONS, MODEL ASSIGNMENTS & ALERTS
-- =====================================================

-- 1. Add relation_label to user_relationships (deaf's alias for connected person)
ALTER TABLE user_relationships ADD COLUMN IF NOT EXISTS relation_label TEXT;

-- 2. Junction table: which trained_names are assigned to each relation
CREATE TABLE IF NOT EXISTS relation_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relation_id UUID NOT NULL REFERENCES user_relationships(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE(relation_id, trained_name_id)
);

CREATE INDEX IF NOT EXISTS idx_relation_models_relation ON relation_models(relation_id);
CREATE INDEX IF NOT EXISTS idx_relation_models_name ON relation_models(trained_name_id);

-- 3. Relation alerts — sent from connected user to deaf user
--    (separate from detection_history; these are REMOTE triggers)
CREATE TABLE IF NOT EXISTS relation_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deaf_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    connected_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    relation_label TEXT NOT NULL,
    model_name TEXT NOT NULL,
    confidence FLOAT DEFAULT 0.0,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_relation_alerts_deaf ON relation_alerts(deaf_user_id);
CREATE INDEX IF NOT EXISTS idx_relation_alerts_connected ON relation_alerts(connected_user_id);

-- 4. RLS
ALTER TABLE relation_models ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage relation_models for their relations"
    ON relation_models FOR ALL
    USING (
        relation_id IN (
            SELECT id FROM user_relationships
            WHERE deaf_user_id = auth.uid() OR connected_user_id = auth.uid()
        )
    );

ALTER TABLE relation_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deaf user can read their own alerts"
    ON relation_alerts FOR SELECT
    USING (auth.uid() = deaf_user_id OR auth.uid() = connected_user_id);

CREATE POLICY "Connected user can insert alerts"
    ON relation_alerts FOR INSERT
    WITH CHECK (auth.uid() = connected_user_id);

CREATE POLICY "Deaf user can update read status"
    ON relation_alerts FOR UPDATE
    USING (auth.uid() = deaf_user_id);
