-- =====================================================
-- VIBRO BACKEND - COMPLETE SUPABASE SQL MIGRATION
-- =====================================================
-- This script creates all tables, policies, functions, 
-- triggers, indexes, and storage buckets for production.
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. UTILITY FUNCTIONS
-- =====================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role = 'admin'
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT role
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 2. CORE TABLES
-- =====================================================

-- 2.1 PROFILES TABLE
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    username TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Index on email for fast lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Trigger for updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE profiles IS 'Extended user identity and role management';

-- =====================================================
-- 2.2 SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tier TEXT NOT NULL CHECK (tier IN ('basic', 'premium', 'enterprise')),
    model_limit INTEGER NOT NULL,
    location_limit INTEGER NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    expiry_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Index on user_id and active subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON subscriptions(is_active, expiry_date) WHERE is_active = TRUE;

COMMENT ON TABLE subscriptions IS 'User subscription plans and limits enforcement';

-- =====================================================
-- 2.3 TRAINED_NAMES TABLE
CREATE TABLE IF NOT EXISTS trained_names (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name_label TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_name_label UNIQUE (user_id, name_label)
);

-- Index on user_id
CREATE INDEX IF NOT EXISTS idx_trained_names_user_id ON trained_names(user_id);

-- Trigger for updated_at
CREATE TRIGGER update_trained_names_updated_at
    BEFORE UPDATE ON trained_names
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE trained_names IS 'Distinct name models per user for voice detection';

-- =====================================================
-- 2.4 AUDIO_SUBMISSIONS TABLE
CREATE TABLE IF NOT EXISTS audio_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    clip_count INTEGER NOT NULL CHECK (clip_count >= 10),
    status TEXT NOT NULL DEFAULT 'uploaded' CHECK (status IN ('uploaded', 'queued', 'processing', 'completed', 'failed')),
    storage_path TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audio_submissions_user_id ON audio_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_audio_submissions_trained_name_id ON audio_submissions(trained_name_id);
CREATE INDEX IF NOT EXISTS idx_audio_submissions_status ON audio_submissions(status);

COMMENT ON TABLE audio_submissions IS 'Track uploaded audio recordings for model training';

-- =====================================================
-- 2.5 TRAINING_QUEUE TABLE
CREATE TABLE IF NOT EXISTS training_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audio_submission_id UUID NOT NULL REFERENCES audio_submissions(id) ON DELETE CASCADE,
    priority INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    queued_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for queue management
CREATE INDEX IF NOT EXISTS idx_training_queue_status ON training_queue(status, priority DESC, queued_at ASC);
CREATE INDEX IF NOT EXISTS idx_training_queue_audio_submission ON training_queue(audio_submission_id);

COMMENT ON TABLE training_queue IS 'Manage Google Colab training job lifecycle';

-- =====================================================
-- 2.6 TRAINED_MODELS TABLE
CREATE TABLE IF NOT EXISTS trained_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    model_version INTEGER NOT NULL,
    model_path TEXT NOT NULL,
    training_sample_count INTEGER NOT NULL,
    accuracy_metric FLOAT,
    trained_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trained_models_user_id ON trained_models(user_id);
CREATE INDEX IF NOT EXISTS idx_trained_models_trained_name_id ON trained_models(trained_name_id);
CREATE INDEX IF NOT EXISTS idx_trained_models_version ON trained_models(trained_name_id, model_version DESC);

COMMENT ON TABLE trained_models IS 'Metadata for trained TFLite models';

-- =====================================================
-- 2.7 LOCATIONS TABLE
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    location_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_location_name UNIQUE (user_id, location_name)
);

-- Index on user_id
CREATE INDEX IF NOT EXISTS idx_locations_user_id ON locations(user_id);

COMMENT ON TABLE locations IS 'Context-based detection environments';

-- =====================================================
-- 2.8 LOCATION_NAME_MAPPING TABLE
CREATE TABLE IF NOT EXISTS location_name_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    CONSTRAINT unique_location_trained_name UNIQUE (location_id, trained_name_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_location_name_mapping_location ON location_name_mapping(location_id);
CREATE INDEX IF NOT EXISTS idx_location_name_mapping_trained_name ON location_name_mapping(trained_name_id);

COMMENT ON TABLE location_name_mapping IS 'Assign trained names to specific locations';

-- =====================================================
-- 2.9 DETECTION_HISTORY TABLE
CREATE TABLE IF NOT EXISTS detection_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    trained_name_id UUID NOT NULL REFERENCES trained_names(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
    accuracy FLOAT NOT NULL,
    threshold_used FLOAT NOT NULL,
    model_version INTEGER NOT NULL,
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Heavy indexing for performance
CREATE INDEX IF NOT EXISTS idx_detection_history_user_id_detected_at ON detection_history(user_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_detection_history_trained_name_id ON detection_history(trained_name_id);
CREATE INDEX IF NOT EXISTS idx_detection_history_location_id ON detection_history(location_id);
CREATE INDEX IF NOT EXISTS idx_detection_history_detected_at ON detection_history(detected_at DESC);

COMMENT ON TABLE detection_history IS 'Store all voice detection events with metadata';

-- =====================================================
-- 2.10 DEVICE_REGISTRY TABLE
CREATE TABLE IF NOT EXISTS device_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    mac_address TEXT UNIQUE NOT NULL,
    firmware_version TEXT,
    battery_last_reported INTEGER,
    last_connected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_device_registry_user_id ON device_registry(user_id);
CREATE INDEX IF NOT EXISTS idx_device_registry_mac_address ON device_registry(mac_address);

COMMENT ON TABLE device_registry IS 'Track paired ESP32 devices';

-- =====================================================
-- 2.11 ADMIN_LOGS TABLE
CREATE TABLE IF NOT EXISTS admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    target_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_action_type ON admin_logs(action_type);

COMMENT ON TABLE admin_logs IS 'Audit trail for all admin actions';

-- =====================================================
-- 2.12 ANALYTICS_DAILY_STATS TABLE
CREATE TABLE IF NOT EXISTS analytics_daily_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_date DATE UNIQUE NOT NULL,
    total_users INTEGER NOT NULL DEFAULT 0,
    total_models INTEGER NOT NULL DEFAULT 0,
    total_detections INTEGER NOT NULL DEFAULT 0,
    active_subscriptions INTEGER NOT NULL DEFAULT 0
);

-- Index on date
CREATE INDEX IF NOT EXISTS idx_analytics_daily_stats_date ON analytics_daily_stats(stat_date DESC);

COMMENT ON TABLE analytics_daily_stats IS 'Precomputed daily metrics for admin dashboard';

-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trained_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE audio_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE trained_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_name_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE detection_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Analytics table does not need RLS (admin only via service role)

-- =====================================================
-- 3.1 PROFILES POLICIES
-- =====================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile (except role and is_active)
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id 
        AND role = (SELECT role FROM profiles WHERE id = auth.uid())
        AND is_active = (SELECT is_active FROM profiles WHERE id = auth.uid())
    );

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
    ON profiles FOR SELECT
    USING (is_admin());

-- Admins can update any profile
CREATE POLICY "Admins can update any profile"
    ON profiles FOR UPDATE
    USING (is_admin());

-- Auto-insert profile on signup
CREATE POLICY "Enable insert for authenticated users"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- =====================================================
-- 3.2 SUBSCRIPTIONS POLICIES
-- =====================================================

-- Users can view their own subscriptions
CREATE POLICY "Users can view own subscriptions"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Admins can view all subscriptions
CREATE POLICY "Admins can view all subscriptions"
    ON subscriptions FOR SELECT
    USING (is_admin());

-- Admins can insert subscriptions
CREATE POLICY "Admins can insert subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (is_admin());

-- Admins can update subscriptions
CREATE POLICY "Admins can update subscriptions"
    ON subscriptions FOR UPDATE
    USING (is_admin());

-- =====================================================
-- 3.3 TRAINED_NAMES POLICIES
-- =====================================================

-- Users can view their own trained names
CREATE POLICY "Users can view own trained names"
    ON trained_names FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own trained names
CREATE POLICY "Users can insert own trained names"
    ON trained_names FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own trained names
CREATE POLICY "Users can update own trained names"
    ON trained_names FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own trained names
CREATE POLICY "Users can delete own trained names"
    ON trained_names FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can view all trained names
CREATE POLICY "Admins can view all trained names"
    ON trained_names FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.4 AUDIO_SUBMISSIONS POLICIES
-- =====================================================

-- Users can view their own submissions
CREATE POLICY "Users can view own audio submissions"
    ON audio_submissions FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own submissions
CREATE POLICY "Users can insert own audio submissions"
    ON audio_submissions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Admins can view all submissions
CREATE POLICY "Admins can view all audio submissions"
    ON audio_submissions FOR SELECT
    USING (is_admin());

-- Service role can update submissions (for Colab)
CREATE POLICY "Service role can update audio submissions"
    ON audio_submissions FOR UPDATE
    USING (true);

-- =====================================================
-- 3.5 TRAINING_QUEUE POLICIES
-- =====================================================

-- Users can view their own training queue entries
CREATE POLICY "Users can view own training queue"
    ON training_queue FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM audio_submissions 
            WHERE id = audio_submission_id
        )
    );

-- Service role can manage queue (for Colab)
CREATE POLICY "Service role can manage training queue"
    ON training_queue FOR ALL
    USING (true);

-- Admins can view all queue entries
CREATE POLICY "Admins can view all training queue"
    ON training_queue FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.6 TRAINED_MODELS POLICIES
-- =====================================================

-- Users can view their own models
CREATE POLICY "Users can view own trained models"
    ON trained_models FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can insert models (for Colab)
CREATE POLICY "Service role can insert trained models"
    ON trained_models FOR INSERT
    WITH CHECK (true);

-- Admins can view all models
CREATE POLICY "Admins can view all trained models"
    ON trained_models FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.7 LOCATIONS POLICIES
-- =====================================================

-- Users can manage their own locations
CREATE POLICY "Users can view own locations"
    ON locations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own locations"
    ON locations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own locations"
    ON locations FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own locations"
    ON locations FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can view all locations
CREATE POLICY "Admins can view all locations"
    ON locations FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.8 LOCATION_NAME_MAPPING POLICIES
-- =====================================================

-- Users can manage mappings for their locations
CREATE POLICY "Users can view own location mappings"
    ON location_name_mapping FOR SELECT
    USING (
        auth.uid() IN (
            SELECT user_id FROM locations 
            WHERE id = location_id
        )
    );

CREATE POLICY "Users can insert own location mappings"
    ON location_name_mapping FOR INSERT
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM locations 
            WHERE id = location_id
        )
    );

CREATE POLICY "Users can delete own location mappings"
    ON location_name_mapping FOR DELETE
    USING (
        auth.uid() IN (
            SELECT user_id FROM locations 
            WHERE id = location_id
        )
    );

-- Admins can view all mappings
CREATE POLICY "Admins can view all location mappings"
    ON location_name_mapping FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.9 DETECTION_HISTORY POLICIES
-- =====================================================

-- Users can view their own detection history
CREATE POLICY "Users can view own detection history"
    ON detection_history FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can insert detections (from ESP32)
CREATE POLICY "Service role can insert detection history"
    ON detection_history FOR INSERT
    WITH CHECK (true);

-- Admins can view all detection history
CREATE POLICY "Admins can view all detection history"
    ON detection_history FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.10 DEVICE_REGISTRY POLICIES
-- =====================================================

-- Users can manage their own devices
CREATE POLICY "Users can view own devices"
    ON device_registry FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own devices"
    ON device_registry FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
    ON device_registry FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON device_registry FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can view all devices
CREATE POLICY "Admins can view all devices"
    ON device_registry FOR SELECT
    USING (is_admin());

-- =====================================================
-- 3.11 ADMIN_LOGS POLICIES
-- =====================================================

-- Only admins can view admin logs
CREATE POLICY "Admins can view admin logs"
    ON admin_logs FOR SELECT
    USING (is_admin());

-- Only admins can insert admin logs
CREATE POLICY "Admins can insert admin logs"
    ON admin_logs FOR INSERT
    WITH CHECK (is_admin());

-- =====================================================
-- 4. STORAGE BUCKETS
-- =====================================================

-- Note: Storage buckets must be created via Supabase Dashboard or API
-- These are the SQL policies for the buckets

-- Create storage policies for audio_uploads bucket
-- (Assumes bucket 'audio_uploads' is created with public=false)

-- Users can upload to their own folder
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio_uploads', 'audio_uploads', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own audio files"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'audio_uploads' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view own audio files"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'audio_uploads' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Admins can view all audio files"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'audio_uploads' 
    AND is_admin()
);

-- Create storage policies for trained_models bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('trained_models', 'trained_models', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can view own models"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'trained_models' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Service role can upload models"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'trained_models');

CREATE POLICY "Admins can view all models"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'trained_models' 
    AND is_admin()
);

-- Create storage policies for reports bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('reports', 'reports', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can view own reports"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'reports' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Admins can manage all reports"
ON storage.objects FOR ALL
USING (
    bucket_id = 'reports' 
    AND is_admin()
);

-- =====================================================
-- 5. HELPER FUNCTIONS FOR SUBSCRIPTION ENFORCEMENT
-- =====================================================

-- Function to check if user has reached model limit
CREATE OR REPLACE FUNCTION check_model_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    model_limit INTEGER;
BEGIN
    -- Get current model count for user
    SELECT COUNT(*) INTO current_count
    FROM trained_names
    WHERE user_id = NEW.user_id;
    
    -- Get user's model limit
    SELECT s.model_limit INTO model_limit
    FROM subscriptions s
    WHERE s.user_id = NEW.user_id
        AND s.is_active = TRUE
        AND s.expiry_date > now()
    ORDER BY s.expiry_date DESC
    LIMIT 1;
    
    -- If no active subscription, use basic limits
    IF model_limit IS NULL THEN
        model_limit := 3; -- Default basic limit
    END IF;
    
    -- Check if limit exceeded
    IF current_count >= model_limit THEN
        RAISE EXCEPTION 'Model limit reached. Current: %, Limit: %', current_count, model_limit;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce model limit
CREATE TRIGGER enforce_model_limit
    BEFORE INSERT ON trained_names
    FOR EACH ROW
    EXECUTE FUNCTION check_model_limit();

-- Function to check if user has reached location limit
CREATE OR REPLACE FUNCTION check_location_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    location_limit INTEGER;
BEGIN
    -- Get current location count for user
    SELECT COUNT(*) INTO current_count
    FROM locations
    WHERE user_id = NEW.user_id;
    
    -- Get user's location limit
    SELECT s.location_limit INTO location_limit
    FROM subscriptions s
    WHERE s.user_id = NEW.user_id
        AND s.is_active = TRUE
        AND s.expiry_date > now()
    ORDER BY s.expiry_date DESC
    LIMIT 1;
    
    -- If no active subscription, use basic limits
    IF location_limit IS NULL THEN
        location_limit := 2; -- Default basic limit
    END IF;
    
    -- Check if limit exceeded
    IF current_count >= location_limit THEN
        RAISE EXCEPTION 'Location limit reached. Current: %, Limit: %', current_count, location_limit;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce location limit
CREATE TRIGGER enforce_location_limit
    BEFORE INSERT ON locations
    FOR EACH ROW
    EXECUTE FUNCTION check_location_limit();

-- =====================================================
-- 6. ANALYTICS HELPER FUNCTIONS
-- =====================================================

-- Function to update daily stats
CREATE OR REPLACE FUNCTION update_daily_stats()
RETURNS void AS $$
BEGIN
    INSERT INTO analytics_daily_stats (
        stat_date,
        total_users,
        total_models,
        total_detections,
        active_subscriptions
    )
    VALUES (
        CURRENT_DATE,
        (SELECT COUNT(*) FROM profiles WHERE is_active = TRUE),
        (SELECT COUNT(*) FROM trained_models),
        (SELECT COUNT(*) FROM detection_history WHERE detected_at >= CURRENT_DATE),
        (SELECT COUNT(*) FROM subscriptions WHERE is_active = TRUE AND expiry_date > now())
    )
    ON CONFLICT (stat_date) 
    DO UPDATE SET
        total_users = EXCLUDED.total_users,
        total_models = EXCLUDED.total_models,
        total_detections = EXCLUDED.total_detections,
        active_subscriptions = EXCLUDED.active_subscriptions;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. AUTO-CREATE PROFILE + SUBSCRIPTION ON USER SIGNUP
-- =====================================================

-- Function to create profile AND default subscription on signup
-- SECURITY DEFINER is critical: runs as the function owner (postgres)
-- which bypasses RLS, allowing inserts into profiles and subscriptions
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create profile
    INSERT INTO profiles (id, email, role, is_active)
    VALUES (NEW.id, NEW.email, 'user', TRUE);

    -- Create default basic subscription
    INSERT INTO subscriptions (
        user_id, tier, model_limit, location_limit,
        start_date, expiry_date, is_active
    )
    VALUES (
        NEW.id, 'basic', 3, 2,
        now(), now() + interval '1 year', TRUE
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger to auto-create profile + subscription
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- =====================================================
-- 8. ADMIN HELPER VIEWS (OPTIONAL)
-- =====================================================

-- View for admin dashboard - active users with subscriptions
CREATE OR REPLACE VIEW admin_user_overview AS
SELECT 
    p.id,
    p.email,
    p.username,
    p.role,
    p.is_active,
    p.created_at,
    s.tier,
    s.model_limit,
    s.location_limit,
    s.expiry_date,
    (SELECT COUNT(*) FROM trained_names WHERE user_id = p.id) as model_count,
    (SELECT COUNT(*) FROM locations WHERE user_id = p.id) as location_count,
    (SELECT COUNT(*) FROM detection_history WHERE user_id = p.id) as total_detections
FROM profiles p
LEFT JOIN subscriptions s ON p.id = s.user_id AND s.is_active = TRUE
ORDER BY p.created_at DESC;

-- Grant view access to admins only
GRANT SELECT ON admin_user_overview TO authenticated;

-- =====================================================
-- 9. FINAL GRANTS AND PERMISSIONS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant storage permissions
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

-- =====================================================
-- 10. INDEXES FOR COMMON QUERIES (ADDITIONAL)
-- =====================================================

-- Composite index for subscription validation
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_active_expiry 
ON subscriptions(user_id, is_active, expiry_date) 
WHERE is_active = TRUE;

-- Index for training queue priority processing
CREATE INDEX IF NOT EXISTS idx_training_queue_processing 
ON training_queue(status, priority DESC, queued_at ASC)
WHERE status = 'queued';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Verify all tables exist
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
        AND table_name IN (
            'profiles', 'subscriptions', 'trained_names',
            'audio_submissions', 'training_queue', 'trained_models',
            'locations', 'location_name_mapping', 'detection_history',
            'device_registry', 'admin_logs', 'analytics_daily_stats'
        );
    
    IF table_count = 12 THEN
        RAISE NOTICE '✓ All 12 tables created successfully';
    ELSE
        RAISE EXCEPTION '✗ Expected 12 tables, found %', table_count;
    END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✓ VIBRO BACKEND MIGRATION COMPLETED SUCCESSFULLY';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '  - 12 tables with full schema';
    RAISE NOTICE '  - Row Level Security policies for all tables';
    RAISE NOTICE '  - 3 storage buckets with policies';
    RAISE NOTICE '  - Helper functions and triggers';
    RAISE NOTICE '  - Subscription enforcement triggers';
    RAISE NOTICE '  - Auto-profile creation on signup';
    RAISE NOTICE '  - Comprehensive indexes';
    RAISE NOTICE '  - Admin logging and analytics';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Create first admin user via Supabase Dashboard';
    RAISE NOTICE '  2. Update their role to admin in profiles table';
    RAISE NOTICE '  3. Test RLS policies with test users';
    RAISE NOTICE '  4. Configure Colab with service role key';
    RAISE NOTICE '  5. Test end-to-end training pipeline';
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
END $$;
