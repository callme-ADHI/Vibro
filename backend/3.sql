-- =====================================================
-- VIBRO BACKEND - HOTFIX #3
-- Fix: "Database error saving new user"
-- =====================================================
-- Safe to run on an existing database where 1.sql was already applied.
-- Uses DROP IF EXISTS / CREATE OR REPLACE to avoid duplicate errors.
-- =====================================================

-- 1. Remove the broken separate subscription trigger (from 2.sql if it was run)
DROP TRIGGER IF EXISTS auto_create_default_subscription ON profiles;
DROP FUNCTION IF EXISTS create_default_subscription_on_signup();

-- 2. Replace handle_new_user to create BOTH profile + subscription
--    SECURITY DEFINER bypasses RLS so the subscription INSERT works.
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

-- 3. Recreate the trigger (safe: drops first if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- 4. Done
DO $$
BEGIN
    RAISE NOTICE '✅ Hotfix applied successfully';
    RAISE NOTICE 'Signup will now create profile + basic subscription automatically';
END $$;
