# Manual Steps Remaining - DO THESE NOW

## ✅ What I Already Did For You

1. ✅ Created `SupabaseConfig.xcconfig` with your credentials
2. ✅ Updated `Info.plist` with Supabase keys
3. ✅ Updated `.gitignore` to protect your secrets

## 🔴 What You Need To Do (20 minutes total)

---

## STEP 1: Run Database Migration in Supabase (5 minutes)

### Instructions:
1. Go to https://supabase.com/dashboard/project/koceuxthtxqvlofijlpr
2. Click **SQL Editor** in the left sidebar
3. Click **New query** button
4. Copy the ENTIRE SQL script below and paste it into the editor
5. Click **Run** (or press Cmd+Enter)
6. Wait for "Success. No rows returned" message

### SQL Script to Copy:

```sql
-- ============================================================================
-- Food1 Database Schema
-- Version: 1.0
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- Profiles Table
-- ============================================================================
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE,
  full_name TEXT,
  age INTEGER CHECK (age >= 13 AND age <= 120),
  weight_kg DECIMAL(5,2) CHECK (weight_kg > 0 AND weight_kg < 500),
  height_cm DECIMAL(5,2) CHECK (height_cm > 0 AND height_cm < 300),
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
  activity_level TEXT CHECK (activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active')),
  weight_unit TEXT DEFAULT 'kg' CHECK (weight_unit IN ('kg', 'lbs')),
  height_unit TEXT DEFAULT 'cm' CHECK (height_unit IN ('cm', 'ft')),
  nutrition_unit TEXT DEFAULT 'metric' CHECK (nutrition_unit IN ('metric', 'imperial')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Subscription Status Table
-- ============================================================================
CREATE TABLE subscription_status (
  user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
  trial_start_date TIMESTAMPTZ DEFAULT NOW(),
  trial_end_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  subscription_type TEXT DEFAULT 'trial' CHECK (subscription_type IN ('trial', 'active', 'expired', 'cancelled')),
  subscription_expires_at TIMESTAMPTZ,
  last_payment_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_subscription_status_updated_at BEFORE UPDATE ON subscription_status
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Meals Table
-- ============================================================================
CREATE TABLE meals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  local_id UUID,
  meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  timestamp TIMESTAMPTZ NOT NULL,
  photo_thumbnail_url TEXT,
  cartoon_image_url TEXT,
  notes TEXT,
  total_calories INTEGER CHECK (total_calories >= 0),
  total_protein_g DECIMAL(7,2) CHECK (total_protein_g >= 0),
  total_carbs_g DECIMAL(7,2) CHECK (total_carbs_g >= 0),
  total_fat_g DECIMAL(7,2) CHECK (total_fat_g >= 0),
  sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  last_synced_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_meals_user_id ON meals(user_id);
CREATE INDEX idx_meals_timestamp ON meals(timestamp DESC);
CREATE INDEX idx_meals_local_id ON meals(local_id);
CREATE INDEX idx_meals_deleted_at ON meals(deleted_at) WHERE deleted_at IS NULL;

CREATE TRIGGER update_meals_updated_at BEFORE UPDATE ON meals
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Meal Ingredients Table
-- ============================================================================
CREATE TABLE meal_ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meal_id UUID REFERENCES meals(id) ON DELETE CASCADE NOT NULL,
  local_id UUID,
  name TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
  unit TEXT NOT NULL,
  calories INTEGER CHECK (calories >= 0),
  protein_g DECIMAL(7,2) CHECK (protein_g >= 0),
  carbs_g DECIMAL(7,2) CHECK (carbs_g >= 0),
  fat_g DECIMAL(7,2) CHECK (fat_g >= 0),
  fiber_g DECIMAL(7,2) CHECK (fiber_g >= 0),
  sugar_g DECIMAL(7,2) CHECK (sugar_g >= 0),
  saturated_fat_g DECIMAL(7,2) CHECK (saturated_fat_g >= 0),
  sodium_mg DECIMAL(7,2) CHECK (sodium_mg >= 0),
  usda_fdc_id INTEGER,
  usda_description TEXT,
  enrichment_attempted BOOLEAN DEFAULT FALSE,
  enrichment_method TEXT CHECK (enrichment_method IN ('fuzzy_match', 'llm_reranking', 'manual', 'none')),
  micronutrients_json JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_meal_ingredients_meal_id ON meal_ingredients(meal_id);
CREATE INDEX idx_meal_ingredients_local_id ON meal_ingredients(local_id);

CREATE TRIGGER update_meal_ingredients_updated_at BEFORE UPDATE ON meal_ingredients
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Sync Queue Table
-- ============================================================================
CREATE TABLE sync_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  operation_type TEXT NOT NULL CHECK (operation_type IN ('create_meal', 'update_meal', 'delete_meal', 'upload_photo')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('meal', 'ingredient', 'profile')),
  entity_id UUID NOT NULL,
  payload JSONB NOT NULL,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  priority INTEGER DEFAULT 0 CHECK (priority >= 0 AND priority <= 10),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_attempted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_sync_queue_user_id ON sync_queue(user_id);
CREATE INDEX idx_sync_queue_status ON sync_queue(status) WHERE status IN ('pending', 'processing');
CREATE INDEX idx_sync_queue_priority ON sync_queue(priority DESC, created_at ASC);

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
  ON profiles FOR DELETE
  USING (auth.uid() = id);

-- Subscription Status Policies
CREATE POLICY "Users can view own subscription"
  ON subscription_status FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own subscription"
  ON subscription_status FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own subscription"
  ON subscription_status FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own subscription"
  ON subscription_status FOR DELETE
  USING (auth.uid() = user_id);

-- Meals Policies
CREATE POLICY "Users can view own meals"
  ON meals FOR SELECT
  USING (auth.uid() = user_id AND deleted_at IS NULL);

CREATE POLICY "Users can insert own meals"
  ON meals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own meals"
  ON meals FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own meals"
  ON meals FOR DELETE
  USING (auth.uid() = user_id);

-- Meal Ingredients Policies
CREATE POLICY "Users can view own meal ingredients"
  ON meal_ingredients FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_ingredients.meal_id
      AND meals.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own meal ingredients"
  ON meal_ingredients FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_ingredients.meal_id
      AND meals.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own meal ingredients"
  ON meal_ingredients FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_ingredients.meal_id
      AND meals.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own meal ingredients"
  ON meal_ingredients FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM meals
      WHERE meals.id = meal_ingredients.meal_id
      AND meals.user_id = auth.uid()
    )
  );

-- Sync Queue Policies
CREATE POLICY "Users can view own sync queue"
  ON sync_queue FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sync queue"
  ON sync_queue FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync queue"
  ON sync_queue FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sync queue"
  ON sync_queue FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- Functions & Triggers
-- ============================================================================

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, created_at)
  VALUES (NEW.id, NEW.email, NOW());

  INSERT INTO public.subscription_status (user_id, trial_start_date, trial_end_date)
  VALUES (NEW.id, NOW(), NOW() + INTERVAL '7 days');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- Storage Buckets
-- ============================================================================

-- Create meal photos bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('meal-photos', 'meal-photos', false)
ON CONFLICT DO NOTHING;

-- Storage policies for meal photos
CREATE POLICY "Users can upload own meal photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'meal-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own meal photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'meal-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own meal photos"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'meal-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own meal photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'meal-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

### Verify It Worked:
1. Go to **Database** → **Tables** in Supabase dashboard
2. You should see 5 tables: `profiles`, `subscription_status`, `meals`, `meal_ingredients`, `sync_queue`
3. Go to **Storage** - you should see `meal-photos` bucket

---

## STEP 2: Configure Apple Sign In (10 minutes)

### A. Enable Sign In with Apple in Apple Developer

1. Go to https://developer.apple.com/account
2. Click **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → Find `com.filipolszak.Food1`
4. Click **Edit**
5. Check **"Sign In with Apple"** capability
6. Click **Save**

### B. Create Service ID

1. Still in Identifiers, click **+** button
2. Select **Services IDs** → Click **Continue**
3. Fill in:
   - **Description**: `Food1 Apple Sign In`
   - **Identifier**: `com.filipolszak.Food1.signin`
4. Click **Continue** → **Register**

### C. Configure Service ID for Web Auth

1. Click on your new Service ID `com.filipolszak.Food1.signin`
2. Check **"Sign In with Apple"**
3. Click **Configure** next to it
4. Add these values:
   - **Domains and Subdomains**: `koceuxthtxqvlofijlpr.supabase.co`
   - **Return URLs**: `https://koceuxthtxqvlofijlpr.supabase.co/auth/v1/callback`
5. Click **Save**
6. Click **Continue** → **Save**

### D. Create Sign In with Apple Key

1. Go to **Keys** in Apple Developer
2. Click **+** button
3. Fill in:
   - **Key Name**: `Food1 Apple Sign In Key`
   - Check **"Sign In with Apple"**
   - Click **Configure**
   - Select primary App ID: `com.filipolszak.Food1`
   - Click **Save**
4. Click **Continue** → **Register**
5. **DOWNLOAD THE .p8 KEY FILE** (you can only download once!)
6. **Copy the Key ID** (looks like `ABC123XYZ`)
7. **Copy your Team ID** (top right corner or in Membership section)

### E. Add to Supabase

1. Go to https://supabase.com/dashboard/project/koceuxthtxqvlofijlpr
2. Go to **Authentication** → **Providers**
3. Find **Apple** and click it
4. Toggle **"Enable Sign in with Apple"** to ON
5. Fill in:
   - **Services ID**: `com.filipolszak.Food1.signin`
   - **Team ID**: [Your Team ID from step D.7]
   - **Key ID**: [Key ID from step D.6]
   - **Private Key**: Open the `.p8` file in TextEdit, copy ALL contents including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines
6. Click **Save**

---

## STEP 3: Enable Email Authentication (2 minutes)

1. Still in **Authentication** → **Providers**
2. Click **Email**
3. Toggle **"Enable Email provider"** to ON
4. Settings:
   - **Enable email confirmations**: Toggle OFF (for faster testing)
   - **Secure email change**: Toggle ON
5. Click **Save**

---

## STEP 4: Add Supabase Swift SDK to Xcode (3 minutes)

### Instructions:
1. Open `Food1.xcodeproj` in Xcode
2. Go to **File** → **Add Package Dependencies...**
3. In the search bar, paste: `https://github.com/supabase/supabase-swift`
4. Click **Add Package**
5. **Version**: Select "Up to Next Major Version" with `2.0.0`
6. **Add to Target**: Make sure `Food1` is checked
7. Products to add (should be auto-selected):
   - ✅ Supabase
   - ✅ Auth
   - ✅ PostgREST
   - ✅ Storage
   - ✅ Realtime
8. Click **Add Package**
9. Wait for package to download and integrate (~1 minute)

### Verify It Worked:
Build the project (Cmd+B) - should succeed with no errors about missing Supabase module.

---

## STEP 5: Configure Xcode to Use xcconfig (2 minutes)

### Instructions:
1. In Xcode, click on the **Food1** project (blue icon at top)
2. Make sure you're on the **Food1** PROJECT (not target)
3. Go to **Info** tab
4. Look for **Configurations** section
5. For **Debug** configuration:
   - Click the dropdown under "Food1" column
   - Select **SupabaseConfig**
6. For **Release** configuration:
   - Click the dropdown under "Food1" column
   - Select **SupabaseConfig**
7. Build the project (Cmd+B) to verify

### Verify It Worked:
```bash
xcodebuild -showBuildSettings | grep SUPABASE
```

Should show:
```
SUPABASE_URL = https://koceuxthtxqvlofijlpr.supabase.co
SUPABASE_ANON_KEY = eyJhbGci...
```

---

## ✅ YOU'RE DONE!

Once you've completed all 5 steps above, tell me:

**"Setup complete, continue implementation"**

And I'll immediately start implementing:
- ✨ SupabaseClient.swift
- ✨ AuthenticationService.swift
- ✨ SessionManager.swift
- ✨ OnboardingView.swift
- ✨ All the authentication and sync code

---

## ❓ Problems?

**SQL fails with "already exists"**:
- Some objects might already exist, that's okay! The script uses `IF NOT EXISTS` where possible.

**Apple Sign In key download fails**:
- You can only download once. If you lost it, delete the key and create a new one.

**Xcode can't find SupabaseConfig.xcconfig**:
- Right-click Food1 folder → **Add Files to "Food1"** → Select the xcconfig file
- Make sure "Add to targets" is UNCHECKED

**Package installation fails**:
- Clean build folder: Shift+Cmd+K
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode
