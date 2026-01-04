-- Migration: Add Google Auth Support and Multi-Provider Tracking
-- Apply via Supabase Dashboard SQL Editor or CLI
--
-- PURPOSE:
-- 1. Track which auth provider user originally signed up with
-- 2. Enable account linking analytics
-- 3. Support for Google Sign-In alongside Apple and Email
--
-- NOTE: Supabase auth.users handles identity management automatically.
-- This migration adds optional tracking fields for analytics/support.

-- ============================================================================
-- PART 1: Add Primary Auth Provider Tracking to Profiles
-- ============================================================================

-- Add column to track initial sign-up provider (for analytics)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS primary_auth_provider TEXT;

-- Add column to track all linked providers (denormalized for quick access)
-- Stored as comma-separated: "apple,google,email"
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS linked_providers TEXT;

-- ============================================================================
-- PART 2: Update handle_new_user Trigger for Provider Tracking
-- ============================================================================

-- Drop existing trigger first (if exists)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create improved function that captures auth provider
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    initial_provider TEXT;
BEGIN
    -- Extract the initial provider from the new user's identity
    -- For OAuth users (Apple/Google), provider is in identities array
    -- For email users, we check if identities is empty or null
    SELECT
        COALESCE(
            (SELECT identity->>'provider'
             FROM jsonb_array_elements(NEW.raw_user_meta_data->'identities') AS identity
             LIMIT 1),
            CASE
                WHEN NEW.raw_app_meta_data->>'provider' IS NOT NULL
                THEN NEW.raw_app_meta_data->>'provider'
                ELSE 'email'
            END
        )
    INTO initial_provider;

    -- Insert profile with provider tracking
    INSERT INTO public.profiles (
        id,
        email,
        primary_auth_provider,
        linked_providers,
        weight_unit,
        height_unit,
        nutrition_unit,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.email,
        initial_provider,
        initial_provider,  -- Initially same as primary
        'kg',              -- Default weight unit
        'cm',              -- Default height unit
        'metric',          -- Default nutrition unit
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        -- If profile exists (rare edge case), just update the provider info
        primary_auth_provider = COALESCE(profiles.primary_auth_provider, EXCLUDED.primary_auth_provider),
        updated_at = now();

    -- Also create subscription_status row (existing behavior)
    INSERT INTO public.subscription_status (
        user_id,
        subscription_type,
        trial_start_date,
        trial_end_date,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        'trial',
        now(),
        now() + INTERVAL '7 days',
        now(),
        now()
    )
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- PART 3: Function to Update Linked Providers (called when linking accounts)
-- ============================================================================

-- Function to update linked_providers when a new identity is added
-- Called from app after successful account linking
CREATE OR REPLACE FUNCTION update_linked_providers(user_uuid UUID, new_provider TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE profiles
    SET
        linked_providers = CASE
            WHEN linked_providers IS NULL OR linked_providers = ''
            THEN new_provider
            WHEN linked_providers NOT LIKE '%' || new_provider || '%'
            THEN linked_providers || ',' || new_provider
            ELSE linked_providers
        END,
        updated_at = now()
    WHERE id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 4: Index for Provider Queries (Optional Analytics)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_profiles_primary_provider
ON profiles(primary_auth_provider);

-- ============================================================================
-- USAGE NOTES:
-- ============================================================================
--
-- 1. Enable Google provider in Supabase Dashboard:
--    Authentication → Providers → Google → Enable
--
-- 2. Configure Google provider settings:
--    - Add iOS Client ID
--    - Enable "Skip nonce check" (CRITICAL for iOS!)
--    - Add redirect URL: com.filipolszak.food1://auth/callback
--
-- 3. Enable auto-linking in Supabase Dashboard:
--    Authentication → Settings → "Automatically link users with the same email"
--
-- 4. The iOS app will call update_linked_providers() after successful linking
--
