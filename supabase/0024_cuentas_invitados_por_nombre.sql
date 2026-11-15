-- 0024 (PROPUESTA, solo DEV): agregar personas por nombre antes de que acepten.
-- Una persona "invitada" es un usuario cascarón (sin email ni clave, no puede iniciar sesión) con lugar en el grupo.
-- Al aceptar su link personal, su cuenta real queda VINCULADA (cuentas.guests.claimed_by). El historial no se modifica:
-- balances y listados traducen el id del invitado al de la cuenta real al leer.
create table cuentas.guests(
 group_id uuid not null references cuentas.groups(id),
 guest_id uuid not null references auth.users(id),
 name text not null check (length(trim(name)) between 1 and 40),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 claimed_by uuid references auth.users(id),
 claimed_at timestamptz,
 primary key (group_id, guest_id),
 unique (guest_id)
);
create unique index guests_one_claim_per_group on cuentas.guests(group_id, claimed_by) where claimed_by is not null;
alter table cuentas.guests enable row level security;
alter table cuentas.invites add column for_guest uuid references auth.users(id);

create function cuentas.eff(p_group uuid, p_user uuid) returns uuid
 language sql stable security definer set search_path to '' as $$
 select coalesce((select g.claimed_by from cuentas.guests g where g.group_id=p_group and g.guest_id=p_user and g.claimed_by is not null), p_user) $$;

-- balances: el invitado ya vinculado suma a su cuenta real
create or replace function cuentas.balances_raw(p_group uuid)
 returns table(user_id uuid, currency text, balance_minor bigint)
 language sql stable security definer set search_path to '' as $function$
 with e as (select m.id,m.currency as cur,m.amount_minor,m.from_user from cuentas.movements m
   where m.group_id=p_group and m.kind='expense' and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void')),
 p as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='payment' and exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')
     and not exists(select 1 from cuentas.movements x where x.ref_id=m.id and x.kind='payment_reversal')),
 k as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='compensation'
     and not exists(select 1 from cuentas.movements x where x.ref_id=m.id and x.kind='compensation_reversal')),
 l as (
  select e.from_user as u, e.cur, e.amount_minor as a from e
  union all select s.user_id, e.cur, -s.share_minor from cuentas.movement_shares s join e on e.id=s.movement_id
  union all select p.from_user, p.cur, p.amount_minor from p
  union all select p.to_user, p.cur, -p.amount_minor from p
  union all select k.from_user, k.cur, k.amount_minor from k
  union all select k.to_user, k.cur, -k.amount_minor from k)
 select cuentas.eff(p_group,l.u), l.cur, sum(l.a)::bigint from l group by cuentas.eff(p_group,l.u), l.cur $function$;

-- listado de movimientos: ids traducidos a la cuenta real
create or replace function public.cuentas_movements_list(p_group uuid)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',m.id,'kind',m.kind,'currency',m.currency,'amount_minor',m.amount_minor,'from_user',cuentas.eff(p_group,m.from_user),'to_user',cuentas.eff(p_group,m.to_user),
   'description',m.description,'occurred_on',m.occurred_on,'ref_id',m.ref_id,'created_by',m.created_by,'created_at',m.created_at,
   'voided',exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void'),
   'reversed',exists(select 1 from cuentas.movements v2 where v2.ref_id=m.id and v2.kind in ('payment_reversal','compensation_reversal')),'confirmed',exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation'),
   'shares',(select coalesce(jsonb_object_agg(x.u,x.s),'{}'::jsonb) from (select cuentas.eff(p_group,s.user_id) u, sum(s.share_minor) s from cuentas.movement_shares s where s.movement_id=m.id group by 1) x)
  ) order by m.created_at, m.id) from cuentas.movements m where m.group_id=p_group),'[]'::jsonb);
end $function$;

-- grupo: oculta invitados ya vinculados y marca a los que todavía no aceptaron
create or replace function public.cuentas_group_get(p_group uuid)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return (select jsonb_build_object('id',g.id,'name',g.name,'reference_currency',g.reference_currency,'status',g.status,
   'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'status',m.status,'display_name',p.display_name,
        'guest',exists(select 1 from cuentas.guests gu where gu.group_id=m.group_id and gu.guest_id=m.user_id)) order by m.joined_at),'[]'::jsonb)
     from cuentas.members m left join core.planazo_profiles p on p.user_id=m.user_id
     where m.group_id=g.id and not exists(select 1 from cuentas.guests gu where gu.group_id=m.group_id and gu.guest_id=m.user_id and gu.claimed_by is not null)))
  from cuentas.groups g where g.id=p_group);
end $function$;

create function public.cuentas_guest_add(p_group uuid, p_name text) returns uuid
 language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_id uuid:=gen_random_uuid(); v_name text:=trim(coalesce(p_name,''));
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id
   where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 if length(v_name) not between 1 and 40 then raise exception 'Poné un nombre (hasta 40 letras)'; end if;
 if exists(select 1 from cuentas.guests gu join cuentas.members m on m.group_id=gu.group_id and m.user_id=gu.guest_id
   where gu.group_id=p_group and gu.claimed_by is null and lower(gu.name)=lower(v_name)) then raise exception 'Ya agregaste a alguien con ese nombre'; end if;
 insert into auth.users(id,instance_id,aud,role,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
 values(v_id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','{}'::jsonb,jsonb_build_object('guest',true),now(),now());
 insert into core.planazo_profiles(user_id,display_name) values(v_id,v_name);
 insert into cuentas.guests(group_id,guest_id,name,created_by) values(p_group,v_id,v_name,v_user);
 insert into cuentas.members(group_id,user_id,role) values(p_group,v_id,'member');
 perform cuentas.log(p_group,v_user,'guest_added',jsonb_build_object('guest',v_id));
 return v_id;
end $function$;

create function public.cuentas_guest_invite_create(p_group uuid, p_guest uuid, p_hours integer default 168) returns text
 language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_token text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id
   where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.guests where group_id=p_group and guest_id=p_guest and claimed_by is null) then raise exception 'Esa persona ya aceptó o no existe'; end if;
 if p_hours not between 1 and 720 then raise exception 'Parámetros inválidos'; end if;
 update cuentas.invites set revoked_at=now() where group_id=p_group and for_guest=p_guest and revoked_at is null;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into cuentas.invites(group_id,token_hash,created_by,expires_at,max_uses,for_guest)
 values(p_group,encode(extensions.digest(v_token,'sha256'),'hex'),v_user,now()+make_interval(hours=>p_hours),1,p_guest);
 perform cuentas.log(p_group,v_user,'guest_invite_created',jsonb_build_object('guest',p_guest));
 return v_token;
end $function$;

create function public.cuentas_guest_remove(p_group uuid, p_guest uuid) returns void
 language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not cuentas.can(p_group,v_user,'invite') then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.guests where group_id=p_group and guest_id=p_guest and claimed_by is null) then raise exception 'Esa persona ya aceptó o no existe'; end if;
 if exists(select 1 from cuentas.movement_shares where user_id=p_guest) or exists(select 1 from cuentas.movements where group_id=p_group and (from_user=p_guest or to_user=p_guest)) then
  raise exception 'Ya tiene gastos en el grupo: no se puede quitar'; end if;
 update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=p_guest;
 update cuentas.invites set revoked_at=now() where group_id=p_group and for_guest=p_guest and revoked_at is null;
 perform cuentas.log(p_group,v_user,'guest_removed',jsonb_build_object('guest',p_guest));
end $function$;

-- aceptar: si el link es personal, vincula la cuenta con el lugar del invitado
create or replace function public.cuentas_invite_accept(p_token text) returns uuid
 language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_inv cuentas.invites%rowtype; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión para aceptar'; end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception 'Invitación inválida'; end if;
 select * into v_inv from cuentas.invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or v_inv.revoked_at is not null or v_inv.expires_at<=now() or v_inv.uses>=v_inv.max_uses then
  raise exception 'Invitación vencida o inválida'; end if;
 select status into v_status from cuentas.groups where id=v_inv.group_id;
 if v_status='archived' then raise exception 'Invitación vencida o inválida'; end if;
 if v_inv.for_guest is not null then
  if exists(select 1 from cuentas.guests where group_id=v_inv.group_id and claimed_by=v_user) then raise exception 'Tu cuenta ya está vinculada a otra persona de este grupo'; end if;
  if exists(select 1 from cuentas.guests where guest_id=v_inv.for_guest and claimed_by is not null) then raise exception 'Invitación vencida o inválida'; end if;
  insert into cuentas.members(group_id,user_id,role) values(v_inv.group_id,v_user,'member')
   on conflict (group_id,user_id) do update set status='active', left_at=null;
  update cuentas.guests set claimed_by=v_user, claimed_at=now() where guest_id=v_inv.for_guest;
  update cuentas.members set status='former', left_at=now() where group_id=v_inv.group_id and user_id=v_inv.for_guest;
  update cuentas.invites set uses=uses+1 where id=v_inv.id;
  perform cuentas.log(v_inv.group_id,v_user,'guest_claimed',jsonb_build_object('guest',v_inv.for_guest));
  return v_inv.group_id;
 end if;
 if cuentas.is_active_member(v_inv.group_id,v_user) then return v_inv.group_id; end if;
 if exists(select 1 from cuentas.members where group_id=v_inv.group_id and user_id=v_user and status='former' and left_at>v_inv.created_at) then raise exception 'Invitación vencida o inválida'; end if;
 insert into cuentas.members(group_id,user_id,role) values(v_inv.group_id,v_user,'member')
 on conflict (group_id,user_id) do update set status='active', left_at=null, role='member';
 update cuentas.invites set uses=uses+1 where id=v_inv.id;
 perform cuentas.log(v_inv.group_id,v_user,'member_joined','{}'::jsonb);
 return v_inv.group_id;
end $function$;

create or replace function public.cuentas_invite_preview(p_token text) returns jsonb
 language plpgsql stable security definer set search_path to '' as $function$
declare v_inv cuentas.invites%rowtype; g cuentas.groups%rowtype;
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('valid',false); end if;
 select * into v_inv from cuentas.invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 if not found or v_inv.revoked_at is not null or v_inv.expires_at<=now() or v_inv.uses>=v_inv.max_uses then return jsonb_build_object('valid',false); end if;
 select * into g from cuentas.groups where id=v_inv.group_id;
 if g.status='archived' then return jsonb_build_object('valid',false); end if;
 return jsonb_build_object('valid',true,'group_id',g.id,'name',g.name,
   'invited_by',(select p.display_name from core.planazo_profiles p where p.user_id=v_inv.created_by),
   'members',(select count(*) from cuentas.members m where m.group_id=g.id and m.status='active'),
   'already_member',cuentas.is_active_member(g.id,auth.uid()),
   'guest_name',(select gu.name from cuentas.guests gu where gu.guest_id=v_inv.for_guest));
end $function$;

-- pagos: no se registran pagos hacia alguien que todavía no aceptó (nadie podría confirmarlos)
create or replace function public.cuentas_payment_add(p_group uuid, p_currency text, p_amount_minor bigint, p_to uuid, p_description text, p_occurred_on date, p_key text)
 returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_status text; v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not exists(select 1 from cuentas.members mm where mm.group_id=p_group and mm.user_id=v_user) then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='payment' and amount_minor=p_amount_minor and currency=p_currency and to_user=p_to) then raise exception 'La clave de idempotencia ya se usó con otros datos'; end if;
  return v_id; end if;
 if v_status='archived' then raise exception 'El grupo está archivado'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;
 if p_to is null or p_to=v_user or not cuentas.is_active_member(p_group,p_to) then raise exception 'Destinatario inválido'; end if;
 if exists(select 1 from cuentas.guests where group_id=p_group and guest_id=p_to and claimed_by is null) then raise exception 'Esa persona todavía no aceptó la invitación: no se pueden registrar pagos hacia ella'; end if;
 if p_amount_minor > greatest(0, -coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=v_user and b.currency=p_currency),0))
   - coalesce((select sum(m.amount_minor) from cuentas.movements m where m.group_id=p_group and m.kind='payment' and m.from_user=v_user and m.currency=p_currency and not exists(select 1 from cuentas.movements c where c.ref_id=m.id)),0)
 then raise exception 'El pago supera lo que debés: no se admite crédito a favor'; end if;
 if p_amount_minor > greatest(0, coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=p_to and b.currency=p_currency),0))
 then raise exception 'El pago supera lo que esa persona tiene a favor'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,occurred_on,created_by,idempotency_key)
 values(p_group,'payment',p_currency,p_amount_minor,v_user,p_to,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key) returning id into v_id;
 perform cuentas.log(p_group,v_user,'payment_added',jsonb_build_object('movement',v_id));
 return v_id;
end $function$;

revoke all on function public.cuentas_guest_add(uuid,text), public.cuentas_guest_invite_create(uuid,uuid,integer), public.cuentas_guest_remove(uuid,uuid) from public, anon;
grant execute on function public.cuentas_guest_add(uuid,text), public.cuentas_guest_invite_create(uuid,uuid,integer), public.cuentas_guest_remove(uuid,uuid) to authenticated;
revoke all on function cuentas.eff(uuid,uuid) from public, anon, authenticated;
