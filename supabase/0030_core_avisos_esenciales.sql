-- 0030 · PROPUESTA (DEV). Avisos esenciales (A5, aprobado por Pau el 15/11) y canal app + correo.
-- Esenciales (no se pueden apagar): propuesta que requiere tu consentimiento, propuesta invalidada,
-- delegación o revocación de coadmin que te afecta, y pedido de cuenta compartida.
-- El correo NO se envía desde la base: queda en cola (email_status='pending') hasta que haya SMTP propio
-- y una función de envío autorizada por Pau. No contiene claves.
create table if not exists core.notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 domain text not null check (domain in ('cuentas','juntada','escapada','core')),
 kind text not null check (length(kind)<=60),
 group_id uuid,
 ref_id uuid,
 data jsonb not null default '{}'::jsonb,
 essential boolean not null default false,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 email_status text not null default 'skipped' check (email_status in ('pending','sent','failed','skipped')),
 email_at timestamptz
);
create index if not exists notifications_user_idx on core.notifications(user_id, created_at desc);
create index if not exists notifications_email_idx on core.notifications(email_status) where email_status='pending';
alter table core.notifications enable row level security;

create or replace function core.notify(p_user uuid,p_domain text,p_kind text,p_group uuid,p_ref uuid,p_data jsonb,p_essential boolean)
returns void language sql security definer set search_path='' as
$$ insert into core.notifications(user_id,domain,kind,group_id,ref_id,data,essential,email_status)
   values(p_user,p_domain,p_kind,p_group,p_ref,coalesce(p_data,'{}'::jsonb),p_essential,case when p_essential then 'pending' else 'skipped' end) $$;

create or replace function cuentas.t_notify_required() returns trigger language plpgsql security definer set search_path='' as
$$ declare p cuentas.proposals%rowtype; begin
 select * into p from cuentas.proposals where id=new.proposal_id;
 if found and p.created_by is distinct from new.user_id then
  perform core.notify(new.user_id,'cuentas','proposal_consent',p.group_id,p.id,jsonb_build_object('kind',p.kind),true); end if;
 return null; end $$;
drop trigger if exists proposal_required_notify on cuentas.proposal_required;
create trigger proposal_required_notify after insert on cuentas.proposal_required for each row execute function cuentas.t_notify_required();

create or replace function cuentas.t_notify_proposal_status() returns trigger language plpgsql security definer set search_path='' as
$$ declare r record; begin
 if old.status='open' and new.status in ('invalidated','stale','cancelled') then
  for r in select user_id from cuentas.proposal_required where proposal_id=new.id loop
   if new.status='cancelled' and r.user_id=new.created_by then continue; end if;
   perform core.notify(r.user_id,'cuentas',case when new.status='cancelled' then 'proposal_cancelled' else 'proposal_invalidated' end,new.group_id,new.id,jsonb_build_object('kind',new.kind),new.status<>'cancelled');
  end loop; end if;
 return null; end $$;
drop trigger if exists proposals_status_notify on cuentas.proposals;
create trigger proposals_status_notify after update of status on cuentas.proposals for each row execute function cuentas.t_notify_proposal_status();

create or replace function cuentas.t_notify_delegation() returns trigger language plpgsql security definer set search_path='' as
$$ begin
 if tg_op='INSERT' then
  perform core.notify(new.delegate_id,'cuentas','delegation_granted',new.group_id,new.id,jsonb_build_object('scopes',to_jsonb(new.scopes)),true);
 elsif old.revoked_at is null and new.revoked_at is not null then
  perform core.notify(new.delegate_id,'cuentas','delegation_revoked',new.group_id,new.id,'{}'::jsonb,true);
 end if; return null; end $$;
drop trigger if exists delegations_notify on cuentas.delegations;
create trigger delegations_notify after insert or update of revoked_at on cuentas.delegations for each row execute function cuentas.t_notify_delegation();

create or replace function cuentas.t_notify_pair() returns trigger language plpgsql security definer set search_path='' as
$$ declare o uuid; begin
 if new.status='pending' then
  o:=case when new.member_a=new.requested_by then new.member_b else new.member_a end;
  perform core.notify(o,'cuentas','pair_request',new.group_id,new.id,'{}'::jsonb,true); end if;
 return null; end $$;
drop trigger if exists shared_accounts_notify on cuentas.shared_accounts;
create trigger shared_accounts_notify after insert on cuentas.shared_accounts for each row execute function cuentas.t_notify_pair();

create or replace function public.core_notifications_list(p_limit int default 30)
returns jsonb language plpgsql stable security definer set search_path='' as
$$ begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
  select n.id,n.domain,n.kind,n.group_id,n.data,n.essential,n.created_at,n.read_at,g.name as group_name
  from core.notifications n left join cuentas.groups g on g.id=n.group_id
  where n.user_id=auth.uid() order by n.created_at desc limit greatest(1,least(coalesce(p_limit,30),100))) x),'[]'::jsonb);
end $$;

create or replace function public.core_notifications_read(p_id uuid default null)
returns int language plpgsql security definer set search_path='' as
$$ declare n int; begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 update core.notifications set read_at=now() where user_id=auth.uid() and read_at is null and (p_id is null or id=p_id);
 get diagnostics n=row_count; return n; end $$;

revoke all on function public.core_notifications_list(int) from public, anon;
revoke all on function public.core_notifications_read(uuid) from public, anon;
grant execute on function public.core_notifications_list(int) to authenticated;
grant execute on function public.core_notifications_read(uuid) to authenticated;
