-- Migration: Add DELETE policies for user_onboarding and meal_reminder_settings
-- These were missing, which would prevent account deletion from cleaning up these tables.
-- Apply via Supabase Dashboard SQL Editor or CLI

-- ============================================================================
-- DELETE policy for user_onboarding table
-- ============================================================================
-- Allows users to delete their own onboarding progress record during account deletion
CREATE POLICY "Users can delete own onboarding"
    ON user_onboarding FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- DELETE policy for meal_reminder_settings table
-- ============================================================================
-- Allows users to delete their own meal reminder settings during account deletion
CREATE POLICY "Users can delete own reminder settings"
    ON meal_reminder_settings FOR DELETE
    USING (auth.uid() = user_id);

-- Note: meal_windows already has a DELETE policy from the original migration
-- "Users can delete own meal windows" ON meal_windows FOR DELETE USING (auth.uid() = user_id);
