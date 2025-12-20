-- Add DELETE policy for profiles table
CREATE POLICY "Users can delete own profile"
  ON profiles FOR DELETE
  USING (auth.uid() = id);

-- Add DELETE policy for subscription_status table  
CREATE POLICY "Users can delete own subscription"
  ON subscription_status FOR DELETE
  USING (auth.uid() = user_id);
