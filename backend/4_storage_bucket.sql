-- =====================================================
-- VIBRO — Storage Bucket Setup for Audio Submissions
-- =====================================================
-- Run this in Supabase SQL Editor to create the
-- audio_submissions storage bucket with RLS policies.
-- =====================================================

-- 1. Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'audio_submissions',
  'audio_submissions',
  false,                          -- Private bucket
  524288,                         -- 512KB max per file
  ARRAY['audio/wav', 'audio/wave', 'audio/x-wav']
)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS Policy: Users can upload their own audio
CREATE POLICY "Users can upload own audio"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'audio_submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. RLS Policy: Users can read their own audio
CREATE POLICY "Users can read own audio"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'audio_submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. RLS Policy: Users can update their own audio
CREATE POLICY "Users can update own audio"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'audio_submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. RLS Policy: Users can delete their own audio
CREATE POLICY "Users can delete own audio"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'audio_submissions'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
