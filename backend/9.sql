-- =====================================================
-- 9. SCHEMA UPDATE - ADDING NEW FEATURES & ATTRIBUTES
-- =====================================================
-- This script integrates new features: User Relationships, 
-- Alerts, Preferences, Patterns, Feedback, and updates
-- existing tables with missing fields.
-- =====================================================

-- 1. PROFILES UPGRADES
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('user', 'deaf', 'connected', 'admin', 'super_admin'));

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS preferred_language TEXT,
ADD COLUMN IF NOT EXISTS dob DATE;

-- 2. USER_RELATIONSHIPS (NEW TABLE)
CREATE TABLE IF NOT EXISTS user_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deaf_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    connected_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    relation_type TEXT,
    model_id UUID REFERENCES trained_models(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_user_relationships_deaf ON user_relationships(deaf_user_id);
CREATE INDEX IF NOT EXISTS idx_user_relationships_connected ON user_relationships(connected_user_id);

-- 3. SUBSCRIPTIONS UPGRADES
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS plan_type TEXT,
ADD COLUMN IF NOT EXISTS usage_limit INTEGER,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

-- 4. TRAINED_NAMES UPGRADES
ALTER TABLE trained_names 
ADD COLUMN IF NOT EXISTS model_id UUID REFERENCES trained_models(id) ON DELETE SET NULL;

-- 5. AUDIO_SUBMISSIONS UPGRADES
ALTER TABLE audio_submissions 
ADD COLUMN IF NOT EXISTS label TEXT,
ADD COLUMN IF NOT EXISTS file_path TEXT;

-- 6. TRAINING_QUEUE UPGRADES
ALTER TABLE training_queue 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS model_id UUID REFERENCES trained_models(id) ON DELETE SET NULL;

-- 7. MODELS (trained_models) UPGRADES
ALTER TABLE trained_models 
ADD COLUMN IF NOT EXISTS model_type TEXT DEFAULT 'personal',
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ready',
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS trained_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 8. LOCATIONS UPGRADES
ALTER TABLE locations 
ADD COLUMN IF NOT EXISTS model_id UUID REFERENCES trained_models(id) ON DELETE SET NULL;

-- 9. DEVICE_REGISTRY UPGRADES
ALTER TABLE device_registry 
ADD COLUMN IF NOT EXISTS device_type TEXT,
ADD COLUMN IF NOT EXISTS device_id_external TEXT,
ADD COLUMN IF NOT EXISTS connection_status TEXT DEFAULT 'offline';

-- 10. DETECTION_HISTORY UPGRADES
ALTER TABLE detection_history 
ADD COLUMN IF NOT EXISTS device_id UUID REFERENCES device_registry(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_correct BOOLEAN,
ADD COLUMN IF NOT EXISTS model_id UUID REFERENCES trained_models(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS detected_label TEXT,
ADD COLUMN IF NOT EXISTS confidence_score FLOAT;

-- 11. ALERTS (NEW TABLE)
CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES detection_history(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    alert_type TEXT,
    delivered BOOLEAN DEFAULT false,
    response_time INTERVAL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_alerts_user_id ON alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_alerts_event_id ON alerts(event_id);

-- 12. USER_PREFERENCES (NEW TABLE)
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sound_type TEXT,
    sensitivity_level FLOAT,
    priority_level INTEGER,
    alert_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

-- 13. VIBRATION_PATTERNS (NEW TABLE)
CREATE TABLE IF NOT EXISTS vibration_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    pattern_name TEXT,
    pattern_data JSONB,
    linked_sound_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_vibration_patterns_user_id ON vibration_patterns(user_id);

-- 14. FEEDBACK (NEW TABLE)
CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES detection_history(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    was_correct BOOLEAN,
    corrected_label TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_event_id ON feedback(event_id);
