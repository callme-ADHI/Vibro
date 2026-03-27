-- =====================================================
-- 22. ALIGN ROLES AND IS_ADMIN
-- =====================================================
-- Update profiles check constraint and is_admin function
-- to correctly handle the super_admin role.
-- =====================================================

-- 1. Temporarily drop constraint and clean up data
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Standardize roles (handle common variations)
UPDATE profiles SET role = 'super_admin' WHERE role IN ('superadmin', 'super-admin', 'SUPER_ADMIN');
UPDATE profiles SET role = 'admin' WHERE role IN ('ADMIN', 'administrator');
UPDATE profiles SET role = 'user' WHERE role IS NULL OR role NOT IN ('admin', 'super_admin');

-- 2. Add the new strict constraint
ALTER TABLE profiles
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('user', 'admin', 'super_admin'));

-- 2. Update is_admin function to include super_admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role IN ('admin', 'super_admin')
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Add is_super_admin function for granular policies
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role = 'super_admin'
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION is_admin IS 'Returns true if current user is an admin or super_admin';
