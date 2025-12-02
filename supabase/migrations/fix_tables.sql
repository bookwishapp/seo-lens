-- First, check if tables exist and drop them to recreate with correct schema
DROP TABLE IF EXISTS suggestions CASCADE;
DROP TABLE IF EXISTS site_pages CASCADE;

-- Create site_pages table
CREATE TABLE site_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  domain_id uuid NOT NULL REFERENCES domains(id) ON DELETE CASCADE,
  url text NOT NULL,
  http_status int,
  title text,
  meta_description text,
  canonical_url text,
  robots_directive text,
  h1 text,
  content_hash text,
  first_seen_at timestamptz DEFAULT now(),
  last_scanned_at timestamptz DEFAULT now(),
  CONSTRAINT site_pages_domain_url_unique UNIQUE (domain_id, url)
);

-- Create suggestions table
CREATE TABLE suggestions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  domain_id uuid REFERENCES domains(id) ON DELETE CASCADE,
  page_id uuid REFERENCES site_pages(id) ON DELETE CASCADE,
  suggestion_type text NOT NULL,
  title text NOT NULL,
  description text,
  severity text DEFAULT 'medium',
  status text DEFAULT 'open',
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

-- Enable RLS
ALTER TABLE site_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE suggestions ENABLE ROW LEVEL SECURITY;

-- RLS policies for site_pages
CREATE POLICY "site_pages_select_own" ON site_pages
  FOR SELECT USING (user_id = auth.uid());

-- RLS policies for suggestions
CREATE POLICY "suggestions_select_own" ON suggestions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "suggestions_update_own" ON suggestions
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
