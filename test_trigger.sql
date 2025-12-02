-- Test if we can manually insert a profile
-- This simulates what the trigger should do
DO $$
DECLARE
  test_uuid UUID := gen_random_uuid();
BEGIN
  -- Try to insert a test profile
  INSERT INTO public.profiles (id, display_name)
  VALUES (test_uuid, 'test_user');

  -- Clean up
  DELETE FROM public.profiles WHERE id = test_uuid;

  RAISE NOTICE 'Profile insert test PASSED';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Profile insert test FAILED: %', SQLERRM;
END $$;
