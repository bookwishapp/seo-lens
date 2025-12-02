-- Create site_pages table for storing page scan results
create table if not exists site_pages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id uuid not null references domains(id) on delete cascade,
  url text not null,
  http_status int,
  title text,
  meta_description text,
  canonical_url text,
  robots_directive text,
  h1 text,
  content_hash text,
  first_seen_at timestamptz default now(),
  last_scanned_at timestamptz default now(),
  constraint site_pages_domain_url_unique unique (domain_id, url)
);

-- Create suggestions table for SEO recommendations
create table if not exists suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id uuid references domains(id) on delete cascade,
  page_id uuid references site_pages(id) on delete cascade,
  suggestion_type text not null,
  title text not null,
  description text,
  severity text default 'medium',
  status text default 'open',
  created_at timestamptz default now(),
  resolved_at timestamptz
);

-- Enable RLS on both tables
alter table site_pages enable row level security;
alter table suggestions enable row level security;

-- RLS policies for site_pages
create policy "site_pages_select_own" on site_pages
  for select using (user_id = auth.uid());

create policy "site_pages_insert_own" on site_pages
  for insert with check (user_id = auth.uid());

create policy "site_pages_update_own" on site_pages
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "site_pages_delete_own" on site_pages
  for delete using (user_id = auth.uid());

-- RLS policies for suggestions
create policy "suggestions_select_own" on suggestions
  for select using (user_id = auth.uid());

create policy "suggestions_insert_own" on suggestions
  for insert with check (user_id = auth.uid());

create policy "suggestions_update_own" on suggestions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "suggestions_delete_own" on suggestions
  for delete using (user_id = auth.uid());

-- Create indexes for better query performance
create index if not exists site_pages_domain_id_idx on site_pages(domain_id);
create index if not exists site_pages_user_id_idx on site_pages(user_id);
create index if not exists suggestions_domain_id_idx on suggestions(domain_id);
create index if not exists suggestions_page_id_idx on suggestions(page_id);
create index if not exists suggestions_user_id_idx on suggestions(user_id);
create index if not exists suggestions_status_idx on suggestions(status);
