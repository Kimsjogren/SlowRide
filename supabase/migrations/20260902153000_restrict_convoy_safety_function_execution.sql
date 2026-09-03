-- This SECURITY DEFINER function is invoked only by its delete trigger.
-- It must not be callable through the public RPC API.
revoke execute on function public.cleanup_convoy_safety_rows() from public;
revoke execute on function public.cleanup_convoy_safety_rows() from anon, authenticated;