-- 0060 (Cuentas): avisos automáticos dentro de la app. Decidido por Pau el 22/11/2026:
-- pago a confirmar (esencial), pago confirmado o anulado, gasto nuevo donde participa (resumen agrupado por grupo),
-- gasto repetido cargado solo, gasto anulado o editado, cierre/reapertura/archivo del grupo;
-- cada persona puede apagar por tipo los que no son esenciales (todo activado por defecto).
create table if not exists cuentas.notif_prefs(
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check (kind in ('expense_new','recurring_added','expense_voided','expense_edited','payment_confirmed','payment_cancelled','group_status')),
 enabled boolean not null default true,
 updated_at timestamptz not null default now(),
 primary key(user_id,kind));
alter table cuentas.notif_prefs enable row level security;
revoke all on cuentas.notif_prefs from public, anon, authenticated;

create or replace function cuentas.notify_pref(p_user uuid, p_kind text, p_group uuid, p_ref uuid, p_data jsonb, p_essential boolean, p_group_it boolean default false)
returns void language plpgsql security definer set search_path to '' as $$
declare v_id uuid; v_data jsonb:=coalesce(p_data,'{}'::jsonb);
begin
 if p_user is null then return; end if;
 if not p_essential and exists(select 1 from cuentas.notif_prefs where user_id=p_user and kind=p_kind and not enabled) then return; end if;
 if p_group_it then
  update core.notifications set data=jsonb_set(coalesce(data,'{}'::jsonb),'{count}',to_jsonb(coalesce((data->>'count')::int,1)+1)), created_at=now(), ref_id=p_ref
   where id=(select id from core.notifications where user_id=p_user and kind=p_kind and group_id=p_group and read_at is null order by created_at desc limit 1)
   returning id into v_id;
  if v_id is not null then return; end if;
  v_data:=v_data||'{"count":1}'::jsonb;
 end if;
 perform core.notify(p_user,'cuentas',p_kind,p_group,p_ref,v_data,p_essential);
end $$;
revoke all on function cuentas.notify_pref(uuid,text,uuid,uuid,jsonb,boolean,boolean) from public, anon, authenticated;

create or replace function cuentas.t_notify_movement() returns trigger language plpgsql security definer set search_path to '' as $$
declare r record; o cuentas.movements%rowtype; v_actor uuid:=new.created_by;
begin
 if new.kind='payment' then
  if new.to_user is distinct from v_actor then
   perform cuentas.notify_pref(new.to_user,'payment_to_confirm',new.group_id,new.id,jsonb_build_object('amount_minor',new.amount_minor,'currency',new.currency),true);
  end if;
 elsif new.kind in ('payment_confirmation','payment_reversal') then
  select * into o from cuentas.movements where id=new.ref_id and kind='payment';
  if found then
   if new.kind='payment_confirmation' then
    if o.from_user is distinct from v_actor then perform cuentas.notify_pref(o.from_user,'payment_confirmed',o.group_id,o.id,jsonb_build_object('amount_minor',o.amount_minor,'currency',o.currency),false); end if;
   else
    for r in select u from (values (o.from_user),(o.to_user)) v(u) where u is not null and u is distinct from v_actor loop
     perform cuentas.notify_pref(r.u,'payment_cancelled',o.group_id,o.id,jsonb_build_object('amount_minor',o.amount_minor,'currency',o.currency),false);
    end loop;
   end if;
  end if;
 elsif new.kind='void' then
  select * into o from cuentas.movements where id=new.ref_id and kind='expense';
  if found then
   for r in select user_id u from cuentas.movement_shares where movement_id=o.id and user_id is distinct from v_actor loop
    perform cuentas.notify_pref(r.u,case when new.description='Editado' then 'expense_edited' else 'expense_voided' end,o.group_id,o.id,jsonb_build_object('description',o.description,'amount_minor',o.amount_minor,'currency',o.currency),false);
   end loop;
  end if;
 end if;
 return null;
end $$;
revoke all on function cuentas.t_notify_movement() from public, anon, authenticated;
create or replace trigger movements_notify after insert on cuentas.movements for each row execute function cuentas.t_notify_movement();

create or replace function cuentas.t_notify_share() returns trigger language plpgsql security definer set search_path to '' as $$
declare m cuentas.movements%rowtype;
begin
 select * into m from cuentas.movements where id=new.movement_id;
 if not found or m.kind<>'expense' or new.user_id is not distinct from m.created_by then return null; end if;
 -- una edición ya avisa como «gasto editado»: no se suma como gasto nuevo
 if exists(select 1 from cuentas.movements v where v.kind='void' and v.description='Editado' and v.group_id=m.group_id and v.created_by=m.created_by and v.created_at=now()) then return null; end if;
 perform cuentas.notify_pref(new.user_id,case when m.idempotency_key like 'rec-%' then 'recurring_added' else 'expense_new' end,m.group_id,m.id,
  jsonb_build_object('description',m.description,'amount_minor',m.amount_minor,'currency',m.currency),false,true);
 return null;
end $$;
revoke all on function cuentas.t_notify_share() from public, anon, authenticated;
create or replace trigger shares_notify after insert on cuentas.movement_shares for each row execute function cuentas.t_notify_share();

create or replace function cuentas.t_notify_group_status() returns trigger language plpgsql security definer set search_path to '' as $$
declare r record; v_actor uuid:=auth.uid();
begin
 if (old.status,new.status) in (('open','closed'),('closed','open'),('closed','archived')) and new.deleted_at is null then
  for r in select user_id u from cuentas.members where group_id=new.id and status='active' and user_id is distinct from v_actor loop
   perform cuentas.notify_pref(r.u,'group_status',new.id,new.id,jsonb_build_object('status',new.status,'was',old.status),false);
  end loop;
 end if;
 return null;
end $$;
revoke all on function cuentas.t_notify_group_status() from public, anon, authenticated;
create or replace trigger groups_status_notify2 after update of status on cuentas.groups for each row execute function cuentas.t_notify_group_status();

create or replace function public.cuentas_notif_prefs_get() returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 return (select jsonb_agg(jsonb_build_object('kind',k.kind,'enabled',coalesce(p.enabled,true),'essential',k.essential) order by k.ord)
  from (values (1,'payment_to_confirm',true),(2,'payment_confirmed',false),(3,'payment_cancelled',false),(4,'expense_new',false),(5,'recurring_added',false),(6,'expense_voided',false),(7,'expense_edited',false),(8,'group_status',false)) k(ord,kind,essential)
  left join cuentas.notif_prefs p on p.user_id=auth.uid() and p.kind=k.kind);
end $$;
revoke all on function public.cuentas_notif_prefs_get() from public, anon;
grant execute on function public.cuentas_notif_prefs_get() to authenticated;

create or replace function public.cuentas_notif_pref_set(p_kind text, p_enabled boolean) returns void language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 if p_kind='payment_to_confirm' then raise exception 'Ese aviso es esencial y no se puede apagar' using detail='CUE_AVISO_ESENCIAL'; end if;
 if p_kind not in ('expense_new','recurring_added','expense_voided','expense_edited','payment_confirmed','payment_cancelled','group_status') or p_enabled is null then raise exception 'Aviso inválido' using detail='CUE_AVISO_INVALIDO'; end if;
 insert into cuentas.notif_prefs(user_id,kind,enabled) values(auth.uid(),p_kind,p_enabled) on conflict (user_id,kind) do update set enabled=excluded.enabled, updated_at=now();
end $$;
revoke all on function public.cuentas_notif_pref_set(text,boolean) from public, anon;
grant execute on function public.cuentas_notif_pref_set(text,boolean) to authenticated;
