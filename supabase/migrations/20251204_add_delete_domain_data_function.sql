-- Create a function to delete all site_pages and suggestions for a domain
-- This function runs with SECURITY DEFINER (admin privileges) to bypass RLS
create or replace function delete_domain_scan_data(p_domain_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_pages int;
  deleted_suggestions int;
begin
  -- Delete suggestions first (they reference site_pages)
  delete from suggestions where domain_id = p_domain_id;
  get diagnostics deleted_suggestions = row_count;

  -- Delete site_pages
  delete from site_pages where domain_id = p_domain_id;
  get diagnostics deleted_pages = row_count;

  return json_build_object(
    'deleted_pages', deleted_pages,
    'deleted_suggestions', deleted_suggestions
  );
end;
$$;

-- Grant execute to authenticated users and service role
grant execute on function delete_domain_scan_data(uuid) to authenticated;
grant execute on function delete_domain_scan_data(uuid) to service_role;
