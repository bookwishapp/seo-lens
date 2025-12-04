-- Add scope column to distinguish page-level vs domain-level suggestions
-- page_id already exists in the table

alter table public.suggestions
  add column if not exists scope text;

-- Set scope based on existing data
-- If page_id is set, it's a page-level suggestion
update public.suggestions
set scope = case
  when page_id is not null then 'page'
  else 'domain'
end
where scope is null;

-- Add check constraint for valid scope values
alter table public.suggestions
  add constraint suggestions_scope_check
  check (scope in ('page', 'domain') or scope is null);

-- Create index for filtering by scope
create index if not exists idx_suggestions_scope on public.suggestions(scope);

-- Create index for filtering suggestions by page
create index if not exists idx_suggestions_page_id on public.suggestions(page_id);

comment on column public.suggestions.scope is 'Scope of the suggestion: page (specific to a site_page) or domain (applies to the whole domain)';
