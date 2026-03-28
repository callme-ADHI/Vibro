-- =====================================================
-- 24. FIX PROFILES ROLE OVERRIDE MERGE CONFLICT
-- =====================================================
-- Migration 22 accidentally restricted the roles back
-- to user/admin/super_admin, erasing the deaf/connected
-- roles from migration 11. This migration restores all
-- valid roles so that app signup functions properly.
-- =====================================================

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Standardize roles just in case any were corrupted or missed
UPDATE profiles SET role = 'super_admin' WHERE role IN ('superadmin', 'super-admin', 'SUPER_ADMIN');
UPDATE profiles SET role = 'admin' WHERE role IN ('ADMIN', 'administrator');
-- We DO NOT force other roles to 'user' here, as that would erase 'deaf'/'connected'.

-- Add the combined new strict constraint
ALTER TABLE profiles
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('user', 'deaf', 'connected', 'admin', 'super_admin'));

-- Update the comments/roles documentation
COMMENT ON TABLE profiles IS 'Extended user identity and role management (roles: user, deaf, connected, admin, super_admin)';
