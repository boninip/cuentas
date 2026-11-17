-- 0007: base de Cuentas (DEV). Construida con las opciones RECOMENDADAS de "Cuentas · Definiciones clave propuestas";
-- esas definiciones siguen pendientes de aprobacion de Pau. Libro mayor de solo altas, acceso solo por funciones.

create table cuentas.groups(
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(trim(name)) between 1 and 120),
 reference_currency text not null default 'ARS' check (reference_currency ~ '^[A-Z]{3}$'),
 status text not null default 'open' check (status in ('open','closed','archived')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 closed_at timestamptz
);
create table cuentas.members(
 group_id uuid not null references cuentas.groups(id),
 user_id uuid not null references auth.users(id),
 role text not null check (role in ('admin','coadmin','member')),
 status text not null default 'active' check (status in ('active','former')),
 joined_at timestamptz not null default now(),
 left_at timestamptz,
 primary key(group_id,user_id)
);
create table cuentas.invites(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references cuentas.groups(id),
 token_hash text not null unique,
 created_by uuid not null references auth.users(id),
 expires_at timestamptz not null,
 max_uses int not null default 20 check (max_uses between 1 and 1000),
 uses int not null default 0 check (uses>=0),
 revoked_at timestamptz,
 created_at timestamptz not null default now()
);
create table cuentas.movements(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references cuentas.groups(id),
 kind text not null check (kind in ('expense','payment','payment_confirmation','void')),
 currency text not null check (currency ~ '^[A-Z]{3}$'),
 amount_minor bigint not null check (amount_minor>0),
 from_user uuid references auth.users(id),
 to_user uuid references auth.users(id),
 description text check (length(description)<=300),
 occurred_on date not null default current_date,
 ref_id uuid references cuentas.movements(id),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 idempotency_key text,
 unique (group_id, created_by, idempotency_key),
 check (
  (kind='expense' and from_user is not null and to_user is null and ref_id is null)
  or (kind='payment' and from_user is not null and to_user is not null and from_user<>to_user and ref_id is null)
  or (kind in ('payment_confirmation','void') and ref_id is not null)
 )
);
create unique index movements_one_followup on cuentas.movements(ref_id, kind) where ref_id is not null;
create table cuentas.movement_shares(
 movement_id uuid not null references cuentas.movements(id),
 user_id uuid not null references auth.users(id),
 share_minor bigint not null check (share_minor>=0),
 primary key(movement_id,user_id)
);
create table cuentas.audit_log(
 id bigint generated always as identity primary key,
 group_id uuid references cuentas.groups(id),
 actor_id uuid,
 action text not null,
 detail jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

-- Solo altas: sin UPDATE, DELETE ni TRUNCATE sobre libro mayor, repartos y auditoria.
create function cuentas.deny_change() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Cuentas es solo de altas: % no permitido', tg_op; end $$;
create trigger movements_append_only before update or delete on cuentas.movements for each row execute function cuentas.deny_change();
create trigger movements_no_truncate before truncate on cuentas.movements for each statement execute function cuentas.deny_change();
create trigger shares_append_only before update or delete on cuentas.movement_shares for each row execute function cuentas.deny_change();
create trigger shares_no_truncate before truncate on cuentas.movement_shares for each statement execute function cuentas.deny_change();
create trigger audit_append_only before update or delete on cuentas.audit_log for each row execute function cuentas.deny_change();
create trigger audit_no_truncate before truncate on cuentas.audit_log for each statement execute function cuentas.deny_change();

-- Defensa en profundidad: el reparto debe sumar el importe del gasto (se verifica al cierre de la transaccion).
create function cuentas.check_shares() returns trigger language plpgsql set search_path='' as $$
declare v_amt bigint; v_kind text; v_sum bigint;
begin
 select amount_minor, kind into v_amt, v_kind from cuentas.movements where id=new.movement_id;
 select coalesce(sum(share_minor),0) into v_sum from cuentas.movement_shares where movement_id=new.movement_id;
 if v_kind<>'expense' or v_sum<>v_amt then raise exception 'El reparto no suma el importe del gasto'; end if;
 return null;
end $$;
create constraint trigger shares_sum_check after insert on cuentas.movement_shares deferrable initially deferred for each row execute function cuentas.check_shares();

alter table cuentas.groups enable row level security;
alter table cuentas.members enable row level security;
alter table cuentas.invites enable row level security;
alter table cuentas.movements enable row level security;
alter table cuentas.movement_shares enable row level security;
alter table cuentas.audit_log enable row level security;
revoke all on all tables in schema cuentas from anon, authenticated, public;

create function cuentas.is_active_member(p_group uuid, p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from cuentas.members where group_id=p_group and user_id=p_user and status='active') $$;
create function cuentas.log(p_group uuid, p_actor uuid, p_action text, p_detail jsonb) returns void
language sql security definer set search_path='' as $$
 insert into cuentas.audit_log(group_id,actor_id,action,detail) values(p_group,p_actor,p_action,coalesce(p_detail,'{}'::jsonb)) $$;
revoke all on function cuentas.is_active_member(uuid,uuid), cuentas.log(uuid,uuid,text,jsonb), cuentas.deny_change(), cuentas.check_shares() from public, anon, authenticated;

-- ===== API (funciones en public, solo authenticated) =====
create function public.cuentas_group_create(p_name text, p_currency text default 'ARS') returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 120 then raise exception 'Nombre inválido'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Moneda inválida'; end if;
 insert into cuentas.groups(name,reference_currency,created_by) values(trim(p_name),p_currency,v_user) returning id into v_id;
 insert into cuentas.members(group_id,user_id,role) values(v_id,v_user,'admin');
 perform cuentas.log(v_id,v_user,'group_created',jsonb_build_object('name',trim(p_name)));
 return v_id;
end $$;

create function public.cuentas_invite_create(p_group uuid, p_hours int default 168, p_max_uses int default 20) returns text
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_token text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id
   where m.group_id=p_group and m.user_id=v_user and m.status='active' and m.role='admin' and g.status<>'archived') then
  raise exception 'No autorizado'; end if;
 if p_hours not between 1 and 720 or p_max_uses not between 1 and 1000 then raise exception 'Parámetros inválidos'; end if;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into cuentas.invites(group_id,token_hash,created_by,expires_at,max_uses)
 values(p_group,encode(extensions.digest(v_token,'sha256'),'hex'),v_user,now()+make_interval(hours=>p_hours),p_max_uses);
 perform cuentas.log(p_group,v_user,'invite_created','{}'::jsonb);
 return v_token;
end $$;

create function public.cuentas_invite_accept(p_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_inv cuentas.invites%rowtype; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión para aceptar'; end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then raise exception 'Invitación inválida'; end if;
 select * into v_inv from cuentas.invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or v_inv.revoked_at is not null or v_inv.expires_at<=now() or v_inv.uses>=v_inv.max_uses then
  raise exception 'Invitación vencida o inválida'; end if;
 select status into v_status from cuentas.groups where id=v_inv.group_id;
 if v_status='archived' then raise exception 'Invitación vencida o inválida'; end if;
 if cuentas.is_active_member(v_inv.group_id,v_user) then return v_inv.group_id; end if;
 insert into cuentas.members(group_id,user_id,role) values(v_inv.group_id,v_user,'member')
 on conflict (group_id,user_id) do update set status='active', left_at=null;
 update cuentas.invites set uses=uses+1 where id=v_inv.id;
 perform cuentas.log(v_inv.group_id,v_user,'member_joined','{}'::jsonb);
 return v_inv.group_id;
end $$;

create function public.cuentas_expense_add(p_group uuid, p_currency text, p_amount_minor bigint, p_payer uuid,
 p_participants uuid[], p_shares jsonb, p_description text, p_occurred_on date, p_key text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_status text; v_id uuid; v_parts uuid[]; v_n int; v_base bigint; v_rem bigint; v_i int:=0; v_sum bigint:=0; r record; u uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then return v_id; end if;
 if v_status<>'open' then raise exception 'El grupo está cerrado: no admite gastos nuevos'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;
 if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;
 if not cuentas.is_active_member(p_group,p_payer) then raise exception 'El pagador no es miembro activo'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,occurred_on,created_by,idempotency_key)
 values(p_group,'expense',p_currency,p_amount_minor,p_payer,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key) returning id into v_id;
 if p_shares is not null then
  if jsonb_typeof(p_shares)<>'object' then raise exception 'Reparto inválido'; end if;
  for r in select key, value from jsonb_each_text(p_shares) loop
   u:=r.key::uuid;
   if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   insert into cuentas.movement_shares(movement_id,user_id,share_minor) values(v_id,u,r.value::bigint);
   v_sum:=v_sum+r.value::bigint;
  end loop;
  if v_sum<>p_amount_minor then raise exception 'El reparto no suma el importe'; end if;
 else
  select array_agg(distinct x order by x) into v_parts from unnest(p_participants) as x;
  v_n:=coalesce(array_length(v_parts,1),0);
  if v_n=0 then raise exception 'Falta repartir entre al menos una persona'; end if;
  v_base:=p_amount_minor / v_n; v_rem:=p_amount_minor % v_n;
  foreach u in array v_parts loop
   v_i:=v_i+1;
   if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   insert into cuentas.movement_shares(movement_id,user_id,share_minor) values(v_id,u,v_base+case when v_i<=v_rem then 1 else 0 end);
  end loop;
 end if;
 perform cuentas.log(p_group,v_user,'expense_added',jsonb_build_object('movement',v_id,'amount_minor',p_amount_minor,'currency',p_currency));
 return v_id;
end $$;

create function public.cuentas_payment_add(p_group uuid, p_currency text, p_amount_minor bigint, p_to uuid,
 p_description text, p_occurred_on date, p_key text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_status text; v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then return v_id; end if;
 if v_status='archived' then raise exception 'El grupo está archivado'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;
 if p_to is null or p_to=v_user or not cuentas.is_active_member(p_group,p_to) then raise exception 'Destinatario inválido'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,occurred_on,created_by,idempotency_key)
 values(p_group,'payment',p_currency,p_amount_minor,v_user,p_to,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key) returning id into v_id;
 perform cuentas.log(p_group,v_user,'payment_added',jsonb_build_object('movement',v_id));
 return v_id;
end $$;

create function public.cuentas_payment_confirm(p_payment uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); p cuentas.movements%rowtype; v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into p from cuentas.movements where id=p_payment and kind='payment';
 if not found or p.to_user<>v_user then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where ref_id=p.id and kind='payment_confirmation';
 if found then return v_id; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,ref_id,created_by,idempotency_key)
 values(p.group_id,'payment_confirmation',p.currency,p.amount_minor,p.from_user,p.to_user,p.id,v_user,'confirm:'||p.id) returning id into v_id;
 perform cuentas.log(p.group_id,v_user,'payment_confirmed',jsonb_build_object('payment',p.id));
 return v_id;
end $$;

create function public.cuentas_expense_void(p_expense uuid, p_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); e cuentas.movements%rowtype; v_id uuid; v_role text; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into e from cuentas.movements where id=p_expense and kind='expense';
 if not found or not cuentas.is_active_member(e.group_id,v_user) then raise exception 'No autorizado'; end if;
 select role into v_role from cuentas.members where group_id=e.group_id and user_id=v_user;
 select status into v_status from cuentas.groups where id=e.group_id;
 if v_status='archived' then raise exception 'El grupo está archivado'; end if;
 if e.created_by<>v_user and v_role<>'admin' then raise exception 'Solo el autor o un administrador puede anular'; end if;
 select id into v_id from cuentas.movements where ref_id=e.id and kind='void';
 if found then return v_id; end if;
 if exists(select 1 from cuentas.movements where group_id=e.group_id and kind='payment_confirmation') then
  raise exception 'Hay pagos confirmados en el grupo: anular requiere la aprobación de los afectados (todavía no implementado)'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,ref_id,created_by,idempotency_key)
 values(e.group_id,'void',e.currency,e.amount_minor,e.from_user,left(p_reason,300),e.id,v_user,'void:'||e.id) returning id into v_id;
 perform cuentas.log(e.group_id,v_user,'expense_voided',jsonb_build_object('expense',e.id));
 return v_id;
end $$;

create function public.cuentas_group_set_status(p_group uuid, p_status text) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_cur text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_status not in ('open','closed') then raise exception 'Estado inválido'; end if;
 select status into v_cur from cuentas.groups where id=p_group;
 if not found or not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;
 if v_cur='archived' then raise exception 'El grupo está archivado'; end if;
 update cuentas.groups set status=p_status, closed_at=case when p_status='closed' then now() else null end where id=p_group;
 perform cuentas.log(p_group,v_user,'group_'||p_status,'{}'::jsonb);
end $$;

create function public.cuentas_balances(p_group uuid) returns table(user_id uuid, currency text, balance_minor bigint)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return query
 with e as (select m.id,m.currency as cur,m.amount_minor,m.from_user from cuentas.movements m
   where m.group_id=p_group and m.kind='expense' and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void')),
 p as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='payment' and exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')),
 l as (
  select e.from_user as u, e.cur, e.amount_minor as a from e
  union all select s.user_id, e.cur, -s.share_minor from cuentas.movement_shares s join e on e.id=s.movement_id
  union all select p.from_user, p.cur, p.amount_minor from p
  union all select p.to_user, p.cur, -p.amount_minor from p)
 select l.u, l.cur, sum(l.a)::bigint from l group by l.u, l.cur order by l.cur, l.u;
end $$;

create function public.cuentas_movements_list(p_group uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',m.id,'kind',m.kind,'currency',m.currency,'amount_minor',m.amount_minor,'from_user',m.from_user,'to_user',m.to_user,
   'description',m.description,'occurred_on',m.occurred_on,'ref_id',m.ref_id,'created_by',m.created_by,'created_at',m.created_at,
   'voided',exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void'),
   'confirmed',exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation'),
   'shares',(select coalesce(jsonb_object_agg(s.user_id,s.share_minor),'{}'::jsonb) from cuentas.movement_shares s where s.movement_id=m.id)
  ) order by m.created_at, m.id) from cuentas.movements m where m.group_id=p_group),'[]'::jsonb);
end $$;

create function public.cuentas_group_get(p_group uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return (select jsonb_build_object('id',g.id,'name',g.name,'reference_currency',g.reference_currency,'status',g.status,
   'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'status',m.status,'display_name',p.display_name) order by m.joined_at),'[]'::jsonb)
     from cuentas.members m left join core.planazo_profiles p on p.user_id=m.user_id where m.group_id=g.id))
  from cuentas.groups g where g.id=p_group);
end $$;

revoke all on function public.cuentas_group_create(text,text), public.cuentas_invite_create(uuid,int,int), public.cuentas_invite_accept(text),
 public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text), public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text),
 public.cuentas_payment_confirm(uuid), public.cuentas_expense_void(uuid,text), public.cuentas_group_set_status(uuid,text),
 public.cuentas_balances(uuid), public.cuentas_movements_list(uuid), public.cuentas_group_get(uuid) from public, anon;
grant execute on function public.cuentas_group_create(text,text), public.cuentas_invite_create(uuid,int,int), public.cuentas_invite_accept(text),
 public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text), public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text),
 public.cuentas_payment_confirm(uuid), public.cuentas_expense_void(uuid,text), public.cuentas_group_set_status(uuid,text),
 public.cuentas_balances(uuid), public.cuentas_movements_list(uuid), public.cuentas_group_get(uuid) to authenticated;
