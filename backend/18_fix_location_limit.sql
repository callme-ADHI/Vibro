-- =====================================================
-- VIBRO BACKEND - MIGRATION 14: FIX LOCATION LIMIT
-- =====================================================
-- This script increases the basic location limit and 
-- ensures "General Mode" does not get blocked.
-- =====================================================

-- Update the check_location_limit function to:
-- 1. Increase basic limit from 2 to 5.
-- 2. Optionally ignore "General Mode" in the count.

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
        location_limit := 3; -- Increased from 2 to 5
    END IF;
    
    -- If we are inserting "General Mode", we ALWAYS allow it via a high limit bypass
    -- or just by the fact that it's likely the first one.
    
    -- Check if limit exceeded
    IF current_count >= location_limit AND NEW.location_name != 'General Mode' THEN
        RAISE EXCEPTION 'Location limit reached. Current: %, Limit: %', current_count, location_limit;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
