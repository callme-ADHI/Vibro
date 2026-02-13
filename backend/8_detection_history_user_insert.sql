-- Allow users to insert their own detection history (from app)
-- Run this in Supabase SQL Editor if the app cannot save detections

CREATE POLICY "Users can insert own detection history"
    ON detection_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);
