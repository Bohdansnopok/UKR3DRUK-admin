-- Застосувати в Central Admin Supabase: тільки owner-email може запрошувати команду.
begin;
delete from public.role_permissions where role_id=(select id from public.roles where key='co_owner') and permission_id=(select id from public.permissions where key='team.manage');
commit;
