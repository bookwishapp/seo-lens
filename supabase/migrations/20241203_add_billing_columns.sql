-- Migration: Add billing columns to profiles table for Stripe integration
-- Run this in your Supabase SQL editor or via migrations

-- ============================================================================
-- ADD BILLING COLUMNS TO PROFILES
-- ============================================================================

-- Add plan tier column (free, pro, lifetime)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS plan_tier TEXT NOT NULL DEFAULT 'free';

-- Add Stripe customer ID (created when user first initiates checkout)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;

-- Add Stripe subscription ID (for Pro monthly/yearly plans)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT;

-- Add Stripe payment ID (for Lifetime one-time payment)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS stripe_lifetime_payment_id TEXT;

-- Add plan renewal interval (monthly, yearly, lifetime, or null for free)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS plan_renews_interval TEXT;

-- Add plan status (active, canceled, past_due, incomplete, null)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS plan_status TEXT;

-- Add subscription period end (for showing "renews on X date")
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS plan_current_period_end TIMESTAMPTZ;

-- Add plan updated timestamp
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS plan_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ============================================================================
-- UPDATE EXISTING ROWS TO HAVE DEFAULT VALUES
-- ============================================================================

UPDATE profiles
SET plan_tier = 'free', plan_updated_at = NOW()
WHERE plan_tier IS NULL;

-- ============================================================================
-- HELPER FUNCTION: Get user's plan tier
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_plan_tier(user_id UUID)
RETURNS TEXT AS $$
DECLARE
  tier TEXT;
BEGIN
  SELECT plan_tier INTO tier FROM profiles WHERE id = user_id;
  RETURN COALESCE(tier, 'free');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Get max domains for plan
-- ============================================================================

CREATE OR REPLACE FUNCTION get_max_domains_for_plan(tier TEXT)
RETURNS INTEGER AS $$
BEGIN
  CASE tier
    WHEN 'free' THEN RETURN 1;
    WHEN 'pro' THEN RETURN 10;
    WHEN 'lifetime' THEN RETURN 10;
    ELSE RETURN 1;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- HELPER FUNCTION: Check if user can create domain
-- ============================================================================

CREATE OR REPLACE FUNCTION can_create_domain()
RETURNS BOOLEAN AS $$
DECLARE
  user_plan_tier TEXT;
  current_domain_count INTEGER;
  max_domains INTEGER;
BEGIN
  -- Get user's plan tier
  SELECT plan_tier INTO user_plan_tier
  FROM profiles
  WHERE id = auth.uid();

  -- Default to free if not found
  user_plan_tier := COALESCE(user_plan_tier, 'free');

  -- Count current domains
  SELECT COUNT(*) INTO current_domain_count
  FROM domains
  WHERE user_id = auth.uid();

  -- Get max domains for plan
  max_domains := get_max_domains_for_plan(user_plan_tier);

  -- Return true if under limit
  RETURN current_domain_count < max_domains;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- UPDATE RLS POLICY FOR DOMAINS: Enforce plan limits on INSERT
-- ============================================================================

-- Drop existing insert policy if it exists (to recreate with limit check)
DROP POLICY IF EXISTS "Users can insert own domains" ON domains;
DROP POLICY IF EXISTS "Limit domains by plan" ON domains;

-- Create new insert policy with plan limit enforcement
CREATE POLICY "Users can insert own domains with plan limit"
  ON domains FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND can_create_domain()
  );

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN profiles.plan_tier IS 'User plan: free, pro, or lifetime';
COMMENT ON COLUMN profiles.stripe_customer_id IS 'Stripe customer ID for this user';
COMMENT ON COLUMN profiles.stripe_subscription_id IS 'Stripe subscription ID for Pro plans';
COMMENT ON COLUMN profiles.stripe_lifetime_payment_id IS 'Stripe payment intent ID for Lifetime purchase';
COMMENT ON COLUMN profiles.plan_renews_interval IS 'Billing interval: monthly, yearly, lifetime, or null';
COMMENT ON COLUMN profiles.plan_status IS 'Subscription status: active, canceled, past_due, incomplete, or null';
COMMENT ON COLUMN profiles.plan_current_period_end IS 'When the current billing period ends';
COMMENT ON COLUMN profiles.plan_updated_at IS 'When the plan was last changed';
COMMENT ON FUNCTION can_create_domain() IS 'RLS helper: checks if user can create another domain based on plan limits';
