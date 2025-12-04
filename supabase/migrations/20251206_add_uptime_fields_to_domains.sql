-- supabase/migrations/20251206_add_uptime_fields_to_domains.sql
-- Add uptime monitoring fields to domains table

alter table public.domains
  add column if not exists uptime_enabled boolean not null default false,
  add column if not exists uptime_check_interval_minutes integer not null default 10,
  add column if not exists last_uptime_status text,
  add column if not exists last_uptime_checked_at timestamptz,
  add column if not exists last_response_time_ms integer,
  add column if not exists uptime_24h_percent numeric,
  add column if not exists uptime_7d_percent numeric;

-- Add comment for documentation
comment on column public.domains.uptime_enabled is 'Whether uptime monitoring is enabled for this domain';
comment on column public.domains.uptime_check_interval_minutes is 'Check interval: 5, 10, or 30 minutes';
comment on column public.domains.last_uptime_status is 'Last check result: up or down';
comment on column public.domains.last_uptime_checked_at is 'Timestamp of last uptime check';
comment on column public.domains.last_response_time_ms is 'Response time in milliseconds from last check';
comment on column public.domains.uptime_24h_percent is 'Uptime percentage over last 24 hours (0-100)';
comment on column public.domains.uptime_7d_percent is 'Uptime percentage over last 7 days (0-100)';
