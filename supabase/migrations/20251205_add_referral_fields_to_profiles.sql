-- Migration: Add referral program fields to profiles table
-- Run this in your Supabase SQL editor or via migrations
--
-- Referral Program Rules:
-- - Each user has a unique referral_code for their shareable link
-- - When a referred user subscribes to Pro within 90 days, referrer gets 1 free month
-- - Cap: 6 free months per referrer per calendar year
-- - Anti-gaming: same stripe_customer_id = no reward

-- ============================================================================
-- ADD REFERRAL COLUMNS TO PROFILES
-- ============================================================================

-- Unique referral code for sharing (e.g., "SL-ABC123")
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;

-- Who referred this user (stores the referrer's referral_code)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referred_by TEXT;

-- When this user was referred (signup timestamp via referral link)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referred_at TIMESTAMPTZ;

-- Whether this referred user has already generated a reward for their referrer
-- (ensures only one reward per referred user, ever)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_reward_granted BOOLEAN NOT NULL DEFAULT FALSE;

-- Count of free months earned by this user as a referrer (lifetime total)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_free_months_earned INTEGER NOT NULL DEFAULT 0;

-- Count of free months earned this calendar year (for cap enforcement)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_free_months_this_year INTEGER NOT NULL DEFAULT 0;

-- The year for which referral_free_months_this_year applies
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_year INTEGER;

-- Date until which this user has free Pro time from referrals
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_free_until TIMESTAMPTZ;

-- ============================================================================
-- INDEX FOR REFERRAL CODE LOOKUPS
-- ============================================================================

CREATE INDEX IF NOT EXISTS profiles_referral_code_idx ON public.profiles(referral_code);
CREATE INDEX IF NOT EXISTS profiles_referred_by_idx ON public.profiles(referred_by);

-- ============================================================================
-- FUNCTION: Generate unique referral code
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excluding confusing chars (0,O,1,I)
  result TEXT := 'SL-';
  i INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: Ensure referral code exists for a profile
-- ============================================================================

CREATE OR REPLACE FUNCTION ensure_referral_code()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate referral code if not set
  IF NEW.referral_code IS NULL THEN
    LOOP
      NEW.referral_code := generate_referral_code();
      -- Check if code already exists
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE referral_code = NEW.referral_code AND id != NEW.id
      );
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: Auto-generate referral code on insert/update
-- ============================================================================

DROP TRIGGER IF EXISTS ensure_referral_code_trigger ON public.profiles;

CREATE TRIGGER ensure_referral_code_trigger
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION ensure_referral_code();

-- ============================================================================
-- BACKFILL: Generate referral codes for existing profiles
-- ============================================================================

-- This updates existing profiles that don't have a referral code
DO $$
DECLARE
  profile_record RECORD;
  new_code TEXT;
BEGIN
  FOR profile_record IN SELECT id FROM public.profiles WHERE referral_code IS NULL LOOP
    LOOP
      new_code := generate_referral_code();
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = new_code);
    END LOOP;
    UPDATE public.profiles SET referral_code = new_code WHERE id = profile_record.id;
  END LOOP;
END $$;

-- ============================================================================
-- OPTIONAL: Referral events log table for tracking/debugging
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.referral_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'signup', 'subscription', 'reward_granted', 'reward_denied'
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for querying referral events
CREATE INDEX IF NOT EXISTS referral_events_referrer_idx ON public.referral_events(referrer_id);
CREATE INDEX IF NOT EXISTS referral_events_referred_idx ON public.referral_events(referred_id);

-- RLS for referral_events (users can only see their own events as referrer)
ALTER TABLE public.referral_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own referral events"
  ON public.referral_events FOR SELECT
  USING (auth.uid() = referrer_id);

-- Service role can insert (for webhook)
CREATE POLICY "Service role can insert referral events"
  ON public.referral_events FOR INSERT
  WITH CHECK (TRUE);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON COLUMN public.profiles.referral_code IS 'Unique code for this user''s referral link (e.g., SL-ABC123)';
COMMENT ON COLUMN public.profiles.referred_by IS 'Referral code of the user who referred this account';
COMMENT ON COLUMN public.profiles.referred_at IS 'Timestamp when this user signed up via referral link';
COMMENT ON COLUMN public.profiles.referral_reward_granted IS 'Whether this referred user has generated a reward for their referrer';
COMMENT ON COLUMN public.profiles.referral_free_months_earned IS 'Total free months earned as a referrer (lifetime)';
COMMENT ON COLUMN public.profiles.referral_free_months_this_year IS 'Free months earned this calendar year (for 6/year cap)';
COMMENT ON COLUMN public.profiles.referral_year IS 'Calendar year for referral_free_months_this_year';
COMMENT ON COLUMN public.profiles.referral_free_until IS 'Date until which user has free Pro from referral rewards';

COMMENT ON TABLE public.referral_events IS 'Log of referral program events for tracking and debugging';
