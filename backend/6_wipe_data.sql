-- 6_wipe_data.sql
-- Wipes all audio, models, and training status to start fresh

-- 1. Truncate tables (cascade to delete dependent rows)
TRUNCATE TABLE public.user_training_status CASCADE;
TRUNCATE TABLE public.trained_models CASCADE;
TRUNCATE TABLE public.audio_submissions CASCADE;
TRUNCATE TABLE public.trained_names CASCADE;

-- 2. Delete files from storage buckets (using storage.objects)
DELETE FROM storage.objects WHERE bucket_id IN ('audio_submissions', 'trained_models');

-- 3. Reset sequences if needed (optional)
-- ALTER SEQUENCE ... RESTART WITH 1;
