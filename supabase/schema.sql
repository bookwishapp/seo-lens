-- SEO Lens Database Schema
-- Run this in your Supabase SQL editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- PROFILES TABLE
-- ============================================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  display_name TEXT,
  primary_domain_id UUID
);

-- RLS for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- DOMAINS TABLE
-- ============================================================================
CREATE TABLE domains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  domain_name TEXT NOT NULL,
  label TEXT,
  project_tag TEXT,
  registrar_name TEXT,
  expiry_date DATE,
  notes TEXT,
  preferred_url TEXT,                    -- Target URL for redirect plan
  preferred_redirect_provider TEXT,      -- Provider managing redirects (cloudflare, netlify, vercel, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, domain_name)
);

-- Index for faster queries
CREATE INDEX domains_user_id_idx ON domains(user_id);
CREATE INDEX domains_project_tag_idx ON domains(project_tag);

-- RLS for domains
ALTER TABLE domains ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own domains"
  ON domains FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own domains"
  ON domains FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own domains"
  ON domains FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own domains"
  ON domains FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- DOMAIN_STATUS TABLE
-- ============================================================================
CREATE TABLE domain_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_id UUID NOT NULL REFERENCES domains (id) ON DELETE CASCADE,
  resolved_ip TEXT,
  final_url TEXT,
  final_status_code INTEGER,
  redirect_chain JSONB,
  last_checked_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(domain_id)
);

-- Index for faster queries
CREATE INDEX domain_status_domain_id_idx ON domain_status(domain_id);

-- RLS for domain_status
ALTER TABLE domain_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view domain_status for own domains"
  ON domain_status FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = domain_status.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert domain_status for own domains"
  ON domain_status FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = domain_status.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update domain_status for own domains"
  ON domain_status FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = domain_status.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete domain_status for own domains"
  ON domain_status FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = domain_status.domain_id
      AND domains.user_id = auth.uid()
    )
  );

-- ============================================================================
-- SITE_PAGES TABLE
-- ============================================================================
CREATE TABLE site_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  domain_id UUID NOT NULL REFERENCES domains (id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  http_status INTEGER,
  title TEXT,
  meta_description TEXT,
  canonical_url TEXT,
  robots_directive TEXT,
  h1 TEXT,
  content_hash TEXT,
  first_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  last_scanned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(domain_id, url)
);

-- Index for faster queries
CREATE INDEX site_pages_domain_id_idx ON site_pages(domain_id);

-- RLS for site_pages
ALTER TABLE site_pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view site_pages for own domains"
  ON site_pages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = site_pages.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert site_pages for own domains"
  ON site_pages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = site_pages.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update site_pages for own domains"
  ON site_pages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = site_pages.domain_id
      AND domains.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete site_pages for own domains"
  ON site_pages FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM domains
      WHERE domains.id = site_pages.domain_id
      AND domains.user_id = auth.uid()
    )
  );

-- ============================================================================
-- SUGGESTIONS TABLE
-- ============================================================================
CREATE TABLE suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  domain_id UUID REFERENCES domains (id) ON DELETE CASCADE,
  page_id UUID REFERENCES site_pages (id) ON DELETE CASCADE,
  suggestion_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high')),
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'ignored')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  resolved_at TIMESTAMPTZ
);

-- Index for faster queries
CREATE INDEX suggestions_user_id_idx ON suggestions(user_id);
CREATE INDEX suggestions_domain_id_idx ON suggestions(domain_id);
CREATE INDEX suggestions_status_idx ON suggestions(status);
CREATE INDEX suggestions_severity_idx ON suggestions(severity);

-- RLS for suggestions
ALTER TABLE suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own suggestions"
  ON suggestions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own suggestions"
  ON suggestions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own suggestions"
  ON suggestions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own suggestions"
  ON suggestions FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- JOBS TABLE (for future background workers)
-- ============================================================================
CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  job_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
  run_after TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  attempts INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for faster queries
CREATE INDEX jobs_user_id_idx ON jobs(user_id);
CREATE INDEX jobs_status_idx ON jobs(status);
CREATE INDEX jobs_run_after_idx ON jobs(run_after);

-- RLS for jobs
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own jobs"
  ON jobs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own jobs"
  ON jobs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own jobs"
  ON jobs FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for domains table
CREATE TRIGGER update_domains_updated_at
  BEFORE UPDATE ON domains
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for jobs table
CREATE TRIGGER update_jobs_updated_at
  BEFORE UPDATE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
