-- Migration: Add Personalization Onboarding Columns
-- Apply via Supabase Dashboard SQL Editor: https://supabase.com/dashboard/project/koceuxthtxqvlofijlpr/sql
--
-- PURPOSE:
-- Add columns to support the new personalization onboarding flow:
-- 1. Track user's primary nutrition goal (weight loss, health, muscle)
-- 2. Track user's diet type preference (balanced, low-carb, vegan/vegetarian)
-- 3. Track when personalization onboarding was completed

-- ============================================================================
-- PART 1: Add Goal and Diet Type Columns to Profiles
-- ============================================================================

-- Primary goal: 'weight_loss', 'health_optimization', 'muscle_building'
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS primary_goal TEXT;

-- Diet type: 'balanced', 'low_carb', 'vegan_vegetarian'
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS diet_type TEXT;

-- ============================================================================
-- PART 2: Add Personalization Completion Tracking to User Onboarding
-- ============================================================================

-- Tracks when the user completed the full personalization flow
ALTER TABLE user_onboarding
ADD COLUMN IF NOT EXISTS personalization_completed_at TIMESTAMPTZ;

-- ============================================================================
-- VERIFICATION QUERY (run after migration to confirm success):
-- ============================================================================
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
--   AND column_name IN ('primary_goal', 'diet_type');
--
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'user_onboarding'
--   AND column_name = 'personalization_completed_at';
