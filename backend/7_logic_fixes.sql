-- 7_logic_fixes.sql
-- Implements "One Name/User = One Model" logic and cascading deletes

-- 1. Ensure trained_models cascades when trained_names is deleted
--    (We might need to drop existing constraint if it lacks cascade)

DO $$ 
BEGIN
  -- Try to drop the FK if it exists to recreate it with CASCADE
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'trained_models_trained_name_id_fkey') THEN
    ALTER TABLE trained_models DROP CONSTRAINT trained_models_trained_name_id_fkey;
  END IF;
END $$;

ALTER TABLE trained_models
  ADD CONSTRAINT trained_models_trained_name_id_fkey
  FOREIGN KEY (trained_name_id)
  REFERENCES trained_names(id)
  ON DELETE CASCADE;


-- 2. Trigger to delete MODEL when a NAME is deleted
--    If a user deletes a name, their current multi-class model is invalid.
--    Be aggressive: delete the model record.

CREATE OR REPLACE FUNCTION handle_name_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete the trained model record for this user
  -- (The actual file in storage will be orphaned, handled by script/cron)
  DELETE FROM trained_models WHERE user_id = OLD.user_id;
  
  -- Reset training status
  DELETE FROM user_training_status WHERE user_id = OLD.user_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_name_deleted ON trained_names;
CREATE TRIGGER on_name_deleted
  AFTER DELETE ON trained_names
  FOR EACH ROW
  EXECUTE FUNCTION handle_name_deletion();


-- 3. Ensure audio submissions cascade (usually redundant but safe)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'audio_submissions_trained_name_id_fkey') THEN
    ALTER TABLE audio_submissions DROP CONSTRAINT audio_submissions_trained_name_id_fkey;
  END IF;
END $$;

ALTER TABLE audio_submissions
  ADD CONSTRAINT audio_submissions_trained_name_id_fkey
  FOREIGN KEY (trained_name_id)
  REFERENCES trained_names(id)
  ON DELETE CASCADE;

-- 4. Constraint: One active model record per user (optional, but good for hygiene)
--    We can't easily enforce "one row total" without partial indexes, 
--    but the training script now manages this.
