begin;
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,email text not null unique,full_name text,status text not null default 'active' check(status in('invited','active','inactive')),is_owner boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
-- MED3DRUK already has public.profiles. CREATE TABLE IF NOT EXISTS does not add
-- missing columns to an existing table, so extend it idempotently for central RBAC.
alter table public.profiles
  add column if not exists status text not null default 'active',
  add column if not exists is_owner boolean not null default false;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_status_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_status_check
      check (status in ('invited', 'active', 'inactive'));
  end if;
end
$$;
create table if not exists public.projects(id uuid primary key default gen_random_uuid(),key text not null unique,name text not null,active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.permissions(id uuid primary key default gen_random_uuid(),key text not null unique,description text,project_key text,created_at timestamptz not null default now());
create table if not exists public.roles(id uuid primary key default gen_random_uuid(),key text not null unique,name text not null,is_system boolean not null default false,created_at timestamptz not null default now());
create table if not exists public.role_permissions(role_id uuid not null references public.roles(id) on delete cascade,permission_id uuid not null references public.permissions(id) on delete cascade,primary key(role_id,permission_id));
create table if not exists public.project_memberships(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),project_id uuid not null references public.projects(id),role_id uuid not null references public.roles(id),active boolean not null default true,created_at timestamptz not null default now(),unique(user_id,project_id));
create table if not exists public.invitations(id uuid primary key default gen_random_uuid(),email text not null,invited_by uuid references public.profiles(id),token_hash text not null unique,status text not null default 'pending',expires_at timestamptz not null,created_at timestamptz not null default now());
create table if not exists public.audit_logs(id bigint generated always as identity primary key,actor_id uuid references public.profiles(id),project_key text,action text not null,entity_type text,entity_id text,metadata jsonb not null default '{}',correlation_id uuid not null default gen_random_uuid(),created_at timestamptz not null default now());
create table if not exists public.notification_outbox(id uuid primary key default gen_random_uuid(),audit_log_id bigint not null references public.audit_logs(id),recipient text not null,subject text not null,body text not null,status text not null default 'pending' check(status in('pending','sent','failed')),attempts integer not null default 0,last_error text,sent_at timestamptz,created_at timestamptz not null default now());
create index if not exists notification_outbox_delivery_idx on public.notification_outbox(status,created_at);
create index if not exists audit_logs_filter_idx on public.audit_logs(project_key,action,entity_type,created_at desc);
insert into public.projects(key,name) values('med3druk','MED3DRUK'),('calculator','Калькулятор') on conflict(key) do update set name=excluded.name;
insert into public.roles(key,name,is_system) values('owner','Власник',true),('co_owner','Співвласник',true),('manager','Менеджер',true),('production','Виробництво',true),('viewer','Перегляд',true) on conflict(key) do update set name=excluded.name;
insert into public.permissions(key,project_key) select p,case when p like 'med3druk.%' then 'med3druk' when p like 'calculator.%' then 'calculator' else null end from unnest(array[
'team.read','team.manage','roles.read','roles.manage','audit.read','projects.read','settings.manage','med3druk.dashboard.read','med3druk.orders.read','med3druk.orders.manage','med3druk.products.read','med3druk.products.manage','med3druk.clients.read','med3druk.clients.manage','med3druk.centers.read','med3druk.centers.manage','med3druk.partners.read','med3druk.partners.manage','med3druk.models.read','med3druk.models.manage','med3druk.deliveries.read','med3druk.deliveries.manage','med3druk.documents.read','med3druk.documents.manage','med3druk.analytics.read','med3druk.settings.manage','calculator.dashboard.read','calculator.orders.read','calculator.orders.manage','calculator.order_files.download','calculator.quotes.read','calculator.users.read','calculator.uploads.read','calculator.uploads.download','calculator.email_verifications.read','calculator.analytics.read','calculator.settings.manage']::text[])p on conflict(key) do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.key='owner' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.key='co_owner' and p.key not in('roles.manage','team.manage','calculator.email_verifications.read') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.key='manager' and (p.key='projects.read' or ((p.key like 'med3druk.%' or p.key like 'calculator.%') and p.key like '%.read' and p.key<>'calculator.email_verifications.read') or p.key in('med3druk.orders.manage','med3druk.products.manage','med3druk.clients.manage','med3druk.centers.manage','med3druk.partners.manage','med3druk.deliveries.manage','med3druk.documents.manage','calculator.orders.manage','calculator.order_files.download','calculator.uploads.download')) on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.key='production' and p.key in('projects.read','med3druk.dashboard.read','med3druk.orders.read','med3druk.orders.manage','med3druk.models.read','med3druk.deliveries.read','med3druk.deliveries.manage','calculator.dashboard.read','calculator.orders.read','calculator.orders.manage','calculator.order_files.download') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.key='viewer' and (p.key='projects.read' or ((p.key like 'med3druk.%' or p.key like 'calculator.%') and p.key like '%.read' and p.key<>'calculator.email_verifications.read')) on conflict do nothing;
create or replace view public.effective_user_permissions with(security_invoker=true) as select distinct m.user_id,p.key permission_key from public.project_memberships m join public.role_permissions rp on rp.role_id=m.role_id join public.permissions p on p.id=rp.permission_id where m.active union select pr.id,p.key from public.profiles pr cross join public.permissions p where pr.is_owner and pr.status='active';
alter table public.profiles enable row level security;alter table public.projects enable row level security;alter table public.permissions enable row level security;alter table public.roles enable row level security;alter table public.role_permissions enable row level security;alter table public.project_memberships enable row level security;alter table public.invitations enable row level security;alter table public.audit_logs enable row level security;
alter table public.notification_outbox enable row level security;
drop policy if exists profile_self_read on public.profiles;create policy profile_self_read on public.profiles for select to authenticated using(id=auth.uid());
drop policy if exists reference_authenticated_read on public.projects;create policy reference_authenticated_read on public.projects for select to authenticated using(true);
drop policy if exists permissions_authenticated_read on public.permissions;create policy permissions_authenticated_read on public.permissions for select to authenticated using(true);
drop policy if exists roles_authenticated_read on public.roles;create policy roles_authenticated_read on public.roles for select to authenticated using(true);
drop policy if exists own_membership_read on public.project_memberships;create policy own_membership_read on public.project_memberships for select to authenticated using(user_id=auth.uid());
revoke insert,update,delete on public.audit_logs from anon,authenticated;revoke insert,update,delete on public.role_permissions,public.project_memberships,public.roles,public.permissions from anon,authenticated;
revoke all on public.notification_outbox from anon,authenticated;
create or replace function public.record_admin_change_and_enqueue(p_actor_id uuid,p_project_key text,p_action text,p_entity_type text,p_entity_id text,p_summary text,p_metadata jsonb default '{}') returns uuid[] language plpgsql security definer set search_path=public as $$declare audit_id bigint;ids uuid[];begin insert into audit_logs(actor_id,project_key,action,entity_type,entity_id,metadata)values(p_actor_id,p_project_key,p_action,p_entity_type,p_entity_id,p_metadata)returning id into audit_id;with queued as(insert into notification_outbox(audit_log_id,recipient,subject,body)select audit_id,'ukr3druk@gmail.com','Зміна в UKR3DRUK Admin',p_summary||E'\n\nПроєкт: '||p_project_key||E'\nДія: '||p_action||E'\nЧас: '||now()::text returning id)select coalesce(array_agg(id),'{}')into ids from queued;return ids;end$$;
revoke all on function public.record_admin_change_and_enqueue(uuid,text,text,text,text,text,jsonb) from public,anon,authenticated;
create or replace function public.prevent_last_owner() returns trigger language plpgsql security definer set search_path=public as $$begin if old.is_owner and old.status='active' and (not new.is_owner or new.status<>'active') and (select count(*) from profiles where is_owner and status='active' and id<>old.id)=0 then raise exception 'Cannot deactivate the last active owner';end if;return new;end$$;
drop trigger if exists protect_last_owner on public.profiles;create trigger protect_last_owner before update on public.profiles for each row execute function public.prevent_last_owner();
create or replace function public.sync_owner_emails(owner_emails text[]) returns integer language plpgsql security definer set search_path=public as $$declare changed integer:=0;r record;begin for r in update profiles set is_owner=true,updated_at=now() where lower(email)=any(owner_emails) and not is_owner returning id loop changed:=changed+1;insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(null,'owner.access_bootstrapped','profile',r.id::text,jsonb_build_object('source','OWNER_EMAILS'));end loop;return changed;end$$;
revoke all on function public.sync_owner_emails(text[]) from public,anon,authenticated;
commit;
