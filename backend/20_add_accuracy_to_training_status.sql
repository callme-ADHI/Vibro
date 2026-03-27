-- =====================================================
-- 20. ADD ACCURACY METRIC TO TRAINING STATUS
-- =====================================================
-- Adds accuracy_metric column to user_training_status
-- for real-time display in the user app.
-- =====================================================

ALTER TABLE user_training_status 
ADD COLUMN IF NOT EXISTS accuracy_metric FLOAT;

COMMENT ON COLUMN user_training_status.accuracy_metric IS 'Final validation accuracy of the trained model (0.0 - 1.0)';
