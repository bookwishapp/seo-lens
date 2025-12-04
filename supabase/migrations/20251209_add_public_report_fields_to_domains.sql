-- Add public report fields to domains table
-- Enables sharing read-only reports via unique token

alter table public.domains
  add column if not exists public_report_enabled boolean not null default false,
  add column if not exists public_report_token text;

-- Enforce uniqueness on public_report_token
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'domains_public_report_token_key'
  ) then
    alter table public.domains
      add constraint domains_public_report_token_key unique (public_report_token);
  end if;
end $$;

-- Create index for faster token lookups
create index if not exists idx_domains_public_report_token
  on public.domains(public_report_token)
  where public_report_token is not null;
