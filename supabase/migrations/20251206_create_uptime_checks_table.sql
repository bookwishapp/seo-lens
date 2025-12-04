-- supabase/migrations/20251206_create_uptime_checks_table.sql
-- Create uptime_checks table for storing raw uptime check history

create table if not exists public.uptime_checks (
  id uuid primary key default gen_random_uuid(),
  domain_id uuid not null references public.domains(id) on delete cascade,
  checked_at timestamptz not null default now(),
  status text not null check (status in ('up', 'down')),
  http_status integer,
  response_time_ms integer,
  error_message text
);

-- Create index for efficient queries by domain and time
create index if not exists idx_uptime_checks_domain_id on public.uptime_checks(domain_id);
create index if not exists idx_uptime_checks_checked_at on public.uptime_checks(checked_at desc);
create index if not exists idx_uptime_checks_domain_checked on public.uptime_checks(domain_id, checked_at desc);

-- Enable RLS
alter table public.uptime_checks enable row level security;

-- Policy: Users can only read uptime checks for their own domains
create policy "Users can read their uptime checks"
on public.uptime_checks
for select
using (
  exists (
    select 1
    from public.domains d
    where d.id = uptime_checks.domain_id
      and d.user_id = auth.uid()
  )
);

-- Policy: Only service role can insert (via edge functions)
-- No insert policy for anon/authenticated = inserts only via service role

-- Add comment for documentation
comment on table public.uptime_checks is 'Stores raw uptime check results for each domain';
comment on column public.uptime_checks.status is 'Check result: up or down';
comment on column public.uptime_checks.http_status is 'HTTP status code returned (e.g., 200, 500)';
comment on column public.uptime_checks.response_time_ms is 'Response time in milliseconds';
comment on column public.uptime_checks.error_message is 'Error message if check failed (timeout, DNS failure, etc.)';
