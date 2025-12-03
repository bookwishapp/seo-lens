-- Migration: Add redirect preferences to domains table
-- Date: 2024-12-02
-- Description: Adds preferred_url and preferred_redirect_provider columns for Guided Redirect Fix feature

-- Add preferred_url column (the URL where user wants domain to resolve)
ALTER TABLE domains
ADD COLUMN IF NOT EXISTS preferred_url TEXT;

-- Add preferred_redirect_provider column (where they manage redirects: cloudflare, netlify, vercel, namecheap, other)
ALTER TABLE domains
ADD COLUMN IF NOT EXISTS preferred_redirect_provider TEXT;

-- Add comment for clarity
COMMENT ON COLUMN domains.preferred_url IS 'The URL where the user wants this domain to ultimately redirect/resolve to';
COMMENT ON COLUMN domains.preferred_redirect_provider IS 'The service where the user manages redirects (cloudflare, netlify, vercel, namecheap, other)';

-- Note: Existing RLS policies on domains table automatically cover these new columns
-- since they use auth.uid() = user_id which applies to all columns in the row.
