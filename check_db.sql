-- Check if function exists
SELECT
  routine_name,
  routine_type,
  routine_schema
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';

-- Check if trigger exists
SELECT
  trigger_name,
  event_object_schema,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
