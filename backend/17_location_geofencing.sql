-- =====================================================
-- VIBRO BACKEND - MIGRATION 13: LOCATION GEOFENCING
-- =====================================================
-- This script adds coordinate and radius support to 
-- the locations table to enable geofencing features.
-- =====================================================

-- Add latitude, longitude, and radius to locations table
ALTER TABLE locations
ADD COLUMN IF NOT EXISTS latitude FLOAT8,
ADD COLUMN IF NOT EXISTS longitude FLOAT8,
ADD COLUMN IF NOT EXISTS radius FLOAT8 DEFAULT 100.0;

-- Optional: Update description
COMMENT ON COLUMN locations.latitude IS 'GPS Latitude of the geofence center';
COMMENT ON COLUMN locations.longitude IS 'GPS Longitude of the geofence center';
COMMENT ON COLUMN locations.radius IS 'Radius in meters for the geofence trigger';
