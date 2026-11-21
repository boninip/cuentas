-- 0051 · Cuentas: topes configurables (50 invitados por grupo, 100 grupos por persona)
--        y propuesta obsoleta (stale) cuando el objetivo ya fue anulado o revertido.
-- Aprobado por Pau el 19/11 (topes) y plan de cierre B5 (obsoleta). Reversa: 0051_REVERSA.sql
create table if not exists cuentas.config(
  key text primary key,
  int_value integer not null check (int_value > 0),
  updated_at timestamptz not null default now());
alter table cuentas.config enable row level security;
revoke all on cuentas.config from anon, authenticated;
insert into cuentas.config(key,int_value) values ('max_guests_per_group',50),('max_groups_per_user',100) on conflict (key) do nothing;

create or replace function cuentas.cfg_int(p_key text, p_default integer)
returns integer language sql stable security definer set search_path to '' as
$$ select coalesce((select int_value from cuentas.config where key=p_key), p_default) $$;
revoke all on function cuentas.cfg_int(text,integer) from public, anon, authenticated;

create or replace function cuentas.check_group_cap(p_user uuid)
returns void language plpgsql security definer set search_path to '' as $f$
begin
 if (select count(*) from cuentas.members m join cuentas.groups g on g.id=m.group_id
     where m.user_id=p_user and m.status='active' and g.status<>'archived') >= cuentas.cfg_int('max_groups_per_user',100) then
  raise exception 'Llegaste al máximo de grupos activos' using detail='CUE_TOPE_GRUPOS'; end if;
end $f$;
revoke all on function cuentas.check_group_cap(uuid) from public, anon, authenticated;

create or replace function public.cuentas_group_create(p_name text, p_currency text default 'ARS')
returns uuid language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 120 then raise exception 'Nombre inválido' using detail='CUE_NOMBRE_INVALIDO'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Moneda inválida' using detail='CUE_MONEDA_INVALIDA'; end if;
 perform cuentas.check_group_cap(v_user);
 insert into cuentas.groups(name,reference_currency,created_by) values(trim(p_name),p_currency,v_user) returning id into v_id;
 insert into cuentas.members(group_id,user_id,role) values(v_id,v_user,'admin');
 perform cuentas.log(v_id,v_user,'group_created',jsonb_build_object('name',trim(p_name)));
 return v_id;
end $f$;

create or replace function public.cuentas_guest_add(p_group uuid, p_name text)
returns uuid language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); v_id uuid:=gen_random_uuid(); v_name text:=trim(coalesce(p_name,''));
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id
   where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 if length(v_name) not between 1 and 40 then raise exception 'Poné un nombre (hasta 40 letras)' using detail='CUE_NOMBRE_INVALIDO'; end if;
 if exists(select 1 from cuentas.guests gu join cuentas.members m on m.group_id=gu.group_id and m.user_id=gu.guest_id
   where gu.group_id=p_group and gu.claimed_by is null and lower(gu.name)=lower(v_name)) then raise exception 'Ya agregaste a alguien con ese nombre' using detail='CUE_INVITADO_DUPLICADO'; end if;
 if (select count(*) from cuentas.guests where group_id=p_group and claimed_by is null) >= cuentas.cfg_int('max_guests_per_group',50) then
  raise exception 'El grupo llegó al máximo de invitados sin cuenta' using detail='CUE_TOPE_INVITADOS'; end if;
 insert into auth.users(id,instance_id,aud,role,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(v_id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','{}'::jsonb,jsonb_build_object('guest',true),now(),now());
 insert into core.pinto_profiles(user_id,display_name) values(v_id,v_name);
 insert into cuentas.guests(group_id,guest_id,name,created_by) values(p_group,v_id,v_name,v_user);
 insert into cuentas.members(group_id,user_id,role) values(p_group,v_id,'member');
 perform cuentas.log(p_group,v_user,'guest_added',jsonb_build_object('guest',v_id));
 return v_id;
end $f$;

create or replace function public.cuentas_invite_accept(p_token text)
returns uuid language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); v_inv cuentas.invites%rowtype; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión para aceptar' using detail='CUE_SIN_SESION'; end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception 'Invitación inválida' using detail='CUE_INVITACION_INVALIDA'; end if;
 select * into v_inv from cuentas.invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or v_inv.revoked_at is not null or v_inv.expires_at<=now() or v_inv.uses>=v_inv.max_uses then
  raise exception 'Invitación vencida o inválida' using detail='CUE_INVITACION_INVALIDA'; end if;
 select status into v_status from cuentas.groups where id=v_inv.group_id;
 if v_status='archived' then raise exception 'Invitación vencida o inválida' using detail='CUE_INVITACION_INVALIDA'; end if;
 if v_inv.for_guest is not null then
  if exists(select 1 from cuentas.guests where group_id=v_inv.group_id and claimed_by=v_user) then raise exception 'Tu cuenta ya está vinculada a otra persona de este grupo' using detail='CUE_YA_VINCULADO_INVITADO'; end if;
  if exists(select 1 from cuentas.guests where guest_id=v_inv.for_guest and claimed_by is not null) then raise exception 'Invitación vencida o inválida' using detail='CUE_INVITACION_INVALIDA'; end if;
  if not cuentas.is_active_member(v_inv.group_id,v_user) then perform cuentas.check_group_cap(v_user); end if;
  insert into cuentas.members(group_id,user_id,role) values(v_inv.group_id,v_user,'member')
   on conflict (group_id,user_id) do update set status='active', left_at=null;
  update cuentas.guests set claimed_by=v_user, claimed_at=now() where guest_id=v_inv.for_guest;
  update cuentas.members set status='former', left_at=now() where group_id=v_inv.group_id and user_id=v_inv.for_guest;
  update cuentas.invites set uses=uses+1 where id=v_inv.id;
  perform cuentas.log(v_inv.group_id,v_user,'guest_claimed',jsonb_build_object('guest',v_inv.for_guest));
  return v_inv.group_id;
 end if;
 if cuentas.is_active_member(v_inv.group_id,v_user) then return v_inv.group_id; end if;
 if exists(select 1 from cuentas.members where group_id=v_inv.group_id and user_id=v_user and status='former' and left_at>v_inv.created_at) then raise exception 'Invitación vencida o inválida' using detail='CUE_INVITACION_INVALIDA'; end if;
 perform cuentas.check_group_cap(v_user);
 insert into cuentas.members(group_id,user_id,role) values(v_inv.group_id,v_user,'member')
 on conflict (group_id,user_id) do update set status='active', left_at=null, role='member';
 update cuentas.invites set uses=uses+1 where id=v_inv.id;
 perform cuentas.log(v_inv.group_id,v_user,'member_joined','{}'::jsonb);
 return v_inv.group_id;
end $f$;

-- Propuesta obsoleta: si el objetivo ya fue anulado o revertido, no se intenta de nuevo (antes: error crudo por el índice único).
create or replace function cuentas.apply_proposal(p_id uuid)
returns text language plpgsql security definer set search_path to '' as $f$
declare pr cuentas.proposals%rowtype; t cuentas.movements%rowtype; acc cuentas.shared_accounts%rowtype; v_ok boolean:=true;
begin
 select * into pr from cuentas.proposals where id=p_id;
 if pr.kind in ('void_expense','reverse_payment','reverse_compensation') then select * into t from cuentas.movements where id=pr.target_id; end if;
 if pr.kind='void_expense' then
  if exists(select 1 from cuentas.movements where ref_id=t.id and kind='void') then v_ok:=false; end if;
  if v_ok then
   insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,ref_id,created_by,idempotency_key)
   values(t.group_id,'void',t.currency,t.amount_minor,t.from_user,left(pr.reason,300),t.id,pr.created_by,'void:'||t.id);
  end if;
 elsif pr.kind='reverse_payment' then
  if exists(select 1 from cuentas.movements where ref_id=t.id and kind in ('void','payment_reversal')) then v_ok:=false; end if;
  if v_ok then
   insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,ref_id,created_by,idempotency_key)
   values(t.group_id,'payment_reversal',t.currency,t.amount_minor,t.from_user,t.to_user,left(pr.reason,300),t.id,pr.created_by,'reverse:'||t.id);
  end if;
 elsif pr.kind='compensation' then
  select * into acc from cuentas.shared_accounts where id=pr.account_id;
  if acc.status<>'active' or not cuentas.is_active_member(pr.group_id,pr.debtor) or not cuentas.is_active_member(pr.group_id,pr.creditor)
     or cuentas.debt_avail(pr.group_id,pr.debtor,pr.currency)<pr.amount_minor
     or cuentas.credit_avail(pr.group_id,pr.creditor,pr.currency)<pr.amount_minor then v_ok:=false; end if;
  if v_ok then
   insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,created_by,idempotency_key)
   values(pr.group_id,'compensation',pr.currency,pr.amount_minor,pr.debtor,pr.creditor,left(pr.reason,300),pr.created_by,'compensation:'||p_id);
  end if;
 else
  if exists(select 1 from cuentas.movements where ref_id=t.id and kind='compensation_reversal') or cuentas.comp_has_dependents(t.id) then v_ok:=false; end if;
  if v_ok then
   insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,ref_id,created_by,idempotency_key)
   values(t.group_id,'compensation_reversal',t.currency,t.amount_minor,t.from_user,t.to_user,left(pr.reason,300),t.id,pr.created_by,'reverse-comp:'||t.id);
  end if;
 end if;
 if not v_ok then
  update cuentas.proposals set status='stale', resolved_at=now() where id=p_id;
  perform cuentas.log(pr.group_id,pr.created_by,'proposal_stale',jsonb_build_object('proposal',p_id,'kind',pr.kind));
  return 'stale';
 end if;
 update cuentas.proposals set status='approved', resolved_at=now() where id=p_id;
 perform cuentas.log(pr.group_id,pr.created_by,'proposal_applied',jsonb_build_object('proposal',p_id,'kind',pr.kind,'target',pr.target_id));
 return 'approved';
end $f$;
