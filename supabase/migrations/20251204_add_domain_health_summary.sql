-- supabase/migrations/20251204_add_domain_health_summary.sql
-- Add health score and summary fields to domains table

ALTER TABLE public.domains
  ADD COLUMN IF NOT EXISTS health_score integer,
  ADD COLUMN IF NOT EXISTS total_pages_scanned integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_missing_title integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_missing_meta integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_missing_h1 integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_2xx integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_4xx integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pages_5xx integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_scan_at timestamptz;

-- Add comments for documentation
COMMENT ON COLUMN public.domains.health_score IS 'SEO health score 0-100, computed after each scan';
COMMENT ON COLUMN public.domains.total_pages_scanned IS 'Total number of pages scanned';
COMMENT ON COLUMN public.domains.pages_missing_title IS 'Pages missing or with short title';
COMMENT ON COLUMN public.domains.pages_missing_meta IS 'Pages missing meta description';
COMMENT ON COLUMN public.domains.pages_missing_h1 IS 'Pages missing H1 heading';
COMMENT ON COLUMN public.domains.pages_2xx IS 'Pages with 2xx status code';
COMMENT ON COLUMN public.domains.pages_4xx IS 'Pages with 4xx status code';
COMMENT ON COLUMN public.domains.pages_5xx IS 'Pages with 5xx status code';
COMMENT ON COLUMN public.domains.last_scan_at IS 'Timestamp of last completed scan';

-- Create a function to compute health score (can be used in triggers or called directly)
CREATE OR REPLACE FUNCTION compute_domain_health_score(
  p_total integer,
  p_missing_title integer,
  p_missing_meta integer,
  p_missing_h1 integer,
  p_4xx integer,
  p_5xx integer
) RETURNS integer AS $$
DECLARE
  score integer := 100;
  title_penalty numeric;
  meta_penalty numeric;
  h1_penalty numeric;
  four_xx_penalty numeric;
  five_xx_penalty numeric;
BEGIN
  -- Guard against division by zero
  IF p_total = 0 THEN
    RETURN 100;
  END IF;

  -- Calculate penalties based on ratios (capped at max penalty)
  title_penalty := LEAST(30, 30.0 * p_missing_title / p_total);
  meta_penalty := LEAST(20, 20.0 * p_missing_meta / p_total);
  h1_penalty := LEAST(20, 20.0 * p_missing_h1 / p_total);
  four_xx_penalty := LEAST(20, 20.0 * p_4xx / p_total);
  five_xx_penalty := LEAST(10, 10.0 * p_5xx / p_total);

  -- Compute final score
  score := 100 - ROUND(title_penalty + meta_penalty + h1_penalty + four_xx_penalty + five_xx_penalty);

  -- Clamp to 0-100
  RETURN GREATEST(0, LEAST(100, score));
END;
$$ LANGUAGE plpgsql IMMUTABLE;
