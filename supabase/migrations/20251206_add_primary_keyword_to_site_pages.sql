-- supabase/migrations/20251206_add_primary_keyword_to_site_pages.sql
-- Add primary keyword field to site_pages for keyword alignment checks

alter table public.site_pages
  add column if not exists primary_keyword text;

-- Add comment for documentation
comment on column public.site_pages.primary_keyword is 'User-defined primary keyword/phrase for this page. Used to check keyword presence in title, meta, and H1.';
