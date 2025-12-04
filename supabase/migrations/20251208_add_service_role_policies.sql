-- Add service role bypass policies for edge functions
-- This ensures edge functions using service role key can perform operations

-- Policy for site_pages - allow service role to manage all rows
create policy "service_role_site_pages_all" on site_pages
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Policy for suggestions - allow service role to manage all rows
create policy "service_role_suggestions_all" on suggestions
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Policy for uptime_checks - allow service role to manage all rows
create policy "service_role_uptime_checks_all" on uptime_checks
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Policy for domains - allow service role to update (for health score, uptime status)
create policy "service_role_domains_all" on domains
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
