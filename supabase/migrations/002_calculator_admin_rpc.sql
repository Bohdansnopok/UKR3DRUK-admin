-- Виконати в Supabase проєкту КАЛЬКУЛЯТОРА, не в central admin.
begin;
alter table public.order_status_history add column if not exists central_actor_id uuid;
alter table public.order_status_history add column if not exists actor_email text;
create or replace function public.admin_update_print_order(p_order_id uuid,p_status public.order_status,p_admin_note text,p_central_actor_id uuid,p_actor_email text) returns void language plpgsql security definer set search_path=public as $$declare previous public.order_status;begin select status into previous from print_orders where id=p_order_id for update;if not found then raise exception 'Order not found';end if;update print_orders set status=p_status,admin_note=coalesce(p_admin_note,''),updated_at=now() where id=p_order_id;insert into order_status_history(order_id,from_status,to_status,changed_by,note,central_actor_id,actor_email)values(p_order_id,previous,p_status,null,coalesce(p_admin_note,''),p_central_actor_id,p_actor_email);end$$;
revoke all on function public.admin_update_print_order(uuid,public.order_status,text,uuid,text) from public,anon,authenticated;
commit;
