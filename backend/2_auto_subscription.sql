-- VIBRO BACKEND - FIX: REBUILD handle_new_user TRIGGER
-- =====================================================
-- Run this in Supabase SQL Editor to fix the signup error:
-- "Database error saving new user"
-- 
-- ROOT CAUSE: The subscription trigger lacked SECURITY DEFINER,
-- so RLS blocked the subscription INSERT during signup.
--
-- FIX: This script replaces handle_new_user() with a version
-- that creates BOTH the profile AND default subscription
-- in one SECURITY DEFINER function (bypasses RLS).
-- =====================================================

-- Drop the old separate subscription trigger if it exists
DROP TRIGGER IF EXISTS auto_create_default_subscription ON profiles;
DROP FUNCTION IF EXISTS create_default_subscription_on_signup();

-- Replace the handle_new_user function
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

-- Recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✓ handle_new_user() rebuilt with SECURITY DEFINER';
    RAISE NOTICE '✓ Profile + Subscription created atomically on signup';
    RAISE NOTICE '✓ Old separate subscription trigger removed';
    RAISE NOTICE '';
    RAISE NOTICE 'New users will automatically receive:';
    RAISE NOTICE '  - Profile (role: user)';
    RAISE NOTICE '  - Subscription (tier: basic, 3 models, 2 locations, 1 year)';
END $$;
