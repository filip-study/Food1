-- Migration: Create meal reminder tables and onboarding tracking
-- Apply via Supabase Dashboard SQL Editor or CLI

-- ============================================================================
-- PART 1: User Onboarding Tracking (General System)
-- ============================================================================

-- Tracks which onboarding steps each user has completed
-- New onboarding steps can be added as columns - existing users will have NULL (not completed)
CREATE TABLE IF NOT EXISTS user_onboarding (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Onboarding steps (NULL = not completed, timestamp = when completed)
    welcome_completed_at TIMESTAMPTZ,           -- Initial welcome/tutorial
    meal_reminders_completed_at TIMESTAMPTZ,    -- Live Activity setup
    profile_setup_completed_at TIMESTAMPTZ,     -- Profile demographics (future)

    -- Metadata
    app_version_first_seen TEXT,                -- First app version user saw
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE user_onboarding ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own onboarding"
    ON user_onboarding FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own onboarding"
    ON user_onboarding FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own onboarding"
    ON user_onboarding FOR UPDATE
    USING (auth.uid() = user_id);

-- Auto-create onboarding row when user signs up
CREATE OR REPLACE FUNCTION create_user_onboarding()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_onboarding (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create (if profiles trigger exists, this adds to it)
DROP TRIGGER IF EXISTS on_auth_user_created_onboarding ON auth.users;
CREATE TRIGGER on_auth_user_created_onboarding
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_user_onboarding();

-- ============================================================================
-- PART 2: Meal Reminder Live Activity Tables
-- ============================================================================

-- Meal windows configuration (1-6 per user)
-- Stores user's meal time preferences with optional AI-learned adjustments
CREATE TABLE IF NOT EXISTS meal_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,                    -- "Breakfast", "Lunch", or custom name
    target_time TIME NOT NULL,             -- User's set time (e.g., 12:00)
    learned_time TIME,                     -- AI-adjusted based on actual meal patterns
    is_enabled BOOLEAN DEFAULT true,       -- Toggle individual windows
    sort_order INTEGER NOT NULL,           -- For ordering in UI
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Reminder settings (singleton per user)
-- Global preferences for the Live Activity feature
CREATE TABLE IF NOT EXISTS meal_reminder_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,           -- Master toggle for feature
    lead_time_minutes INTEGER DEFAULT 45,      -- Show activity X minutes before meal
    auto_dismiss_minutes INTEGER DEFAULT 120,  -- Auto-dismiss X minutes after meal time
    use_learning BOOLEAN DEFAULT true,         -- Whether to adjust times based on patterns
    onboarding_completed BOOLEAN DEFAULT false, -- Whether user completed setup
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE meal_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_reminder_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for meal_windows
CREATE POLICY "Users can view own meal windows"
    ON meal_windows FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own meal windows"
    ON meal_windows FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own meal windows"
    ON meal_windows FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own meal windows"
    ON meal_windows FOR DELETE
    USING (auth.uid() = user_id);

-- RLS Policies for meal_reminder_settings
CREATE POLICY "Users can view own reminder settings"
    ON meal_reminder_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reminder settings"
    ON meal_reminder_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reminder settings"
    ON meal_reminder_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_meal_windows_user_id ON meal_windows(user_id);
CREATE INDEX IF NOT EXISTS idx_meal_windows_sort ON meal_windows(user_id, sort_order);
