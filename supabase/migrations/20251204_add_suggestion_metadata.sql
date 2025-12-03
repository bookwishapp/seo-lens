-- supabase/migrations/20251204_add_suggestion_metadata.sql
-- Add impact and effort columns to suggestions table for smarter prioritization

-- Add impact column (what area does this suggestion affect)
ALTER TABLE public.suggestions
  ADD COLUMN IF NOT EXISTS impact text;

-- Add effort column (how much work to fix)
ALTER TABLE public.suggestions
  ADD COLUMN IF NOT EXISTS effort text;

-- Add comment for documentation
COMMENT ON COLUMN public.suggestions.impact IS 'Impact area: visibility, click_through, technical, trust, essentials';
COMMENT ON COLUMN public.suggestions.effort IS 'Effort to fix: quick_win, moderate, deep_change';

-- Backfill existing suggestions with impact and effort based on suggestion_type
UPDATE public.suggestions
SET
  impact = CASE suggestion_type
    WHEN 'missing_or_short_title' THEN 'visibility'
    WHEN 'title_too_long' THEN 'visibility'
    WHEN 'missing_meta_description' THEN 'click_through'
    WHEN 'short_meta_description' THEN 'click_through'
    WHEN 'long_meta_description' THEN 'click_through'
    WHEN 'canonical_points_elsewhere' THEN 'technical'
    WHEN 'invalid_canonical' THEN 'technical'
    WHEN 'missing_h1' THEN 'essentials'
    WHEN 'noindex_set' THEN 'visibility'
    WHEN 'page_error_status' THEN 'technical'
    ELSE 'technical'
  END,
  effort = CASE suggestion_type
    WHEN 'missing_or_short_title' THEN 'quick_win'
    WHEN 'title_too_long' THEN 'quick_win'
    WHEN 'missing_meta_description' THEN 'quick_win'
    WHEN 'short_meta_description' THEN 'quick_win'
    WHEN 'long_meta_description' THEN 'quick_win'
    WHEN 'canonical_points_elsewhere' THEN 'moderate'
    WHEN 'invalid_canonical' THEN 'moderate'
    WHEN 'missing_h1' THEN 'quick_win'
    WHEN 'noindex_set' THEN 'moderate'
    WHEN 'page_error_status' THEN 'deep_change'
    ELSE 'moderate'
  END
WHERE impact IS NULL OR effort IS NULL;
