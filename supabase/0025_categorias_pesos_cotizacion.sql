-- 0025 · Cuentas: categorías por grupo, cotización por gasto, peso y responsable por miembro
-- ESTADO: PROPUESTA (aplicada solo en DEV "Pinto Core"). Reversa: 0025_REVERSA.sql
-- Diseño:
--  * Categorías: lista base editable por grupo (cuentas.group_categories). El gasto guarda la clave (movements.category).
--  * Cotización: movements.fx_rate = unidades de la moneda del grupo por 1 unidad de la moneda del gasto, fijada al cargar.
--    Los saldos siguen por moneda (no se mezclan); la cotización solo se usa para totales y gráficos en la moneda del grupo.
--  * Familia: members.weight (peso en "partes iguales": adulto 1, niño 0,5, bebé 0) y members.guardian (responsable).
--    El saldo de quien tiene responsable se suma al del responsable al leer (cuentas.eff_pay); el libro no se reescribe.

alter table cuentas.members
  add column if not exists weight numeric(4,2) not null default 1 check (weight >= 0 and weight <= 5),
  add column if not exists guardian uuid references auth.users(id);
alter table cuentas.movements
  add column if not exists category text check (category is null or length(category) between 1 and 40),
  add column if not exists fx_rate numeric(18,6) check (fx_rate is null or fx_rate > 0);

create table if not exists cuentas.group_categories(
  group_id uuid not null references cuentas.groups(id),
  key text not null check (key ~ '^[a-z0-9_-]{1,40}$'),
  name text not null check (length(trim(name)) between 1 and 30),
  icon text not null default 'dots',
  color int not null default 0 check (color between 0 and 5),
  position int not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (group_id, key));
alter table cuentas.group_categories enable row level security;
revoke all on cuentas.group_categories from anon, authenticated, public;

-- saldo efectivo: claim de invitado y después responsable
create or replace function cuentas.eff_pay(p_group uuid, p_user uuid) returns uuid
language sql stable security definer set search_path to '' as $$
 select coalesce(
   (select cuentas.eff(p_group, m.guardian) from cuentas.members m
     where m.group_id=p_group and m.user_id=cuentas.eff(p_group,p_user) and m.guardian is not null and m.status='active'),
   cuentas.eff(p_group,p_user)) $$;
revoke all on function cuentas.eff_pay(uuid,uuid) from public, anon, authenticated;

create or replace function cuentas.balances_raw(p_group uuid)
returns table(user_id uuid, currency text, balance_minor bigint)
language sql stable security definer set search_path to '' as $$
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
 select cuentas.eff_pay(p_group,l.u), l.cur, sum(l.a)::bigint from l group by cuentas.eff_pay(p_group,l.u), l.cur $$;

-- grupo: ahora devuelve peso y responsable
create or replace function public.cuentas_group_get(p_group uuid) returns jsonb
language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return (select jsonb_build_object('id',g.id,'name',g.name,'reference_currency',g.reference_currency,'status',g.status,
   'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'status',m.status,'display_name',p.display_name,
        'weight',m.weight,'guardian',m.guardian,
        'guest',exists(select 1 from cuentas.guests gu where gu.group_id=m.group_id and gu.guest_id=m.user_id)) order by m.joined_at),'[]'::jsonb)
     from cuentas.members m left join core.planazo_profiles p on p.user_id=m.user_id
     where m.group_id=g.id and not exists(select 1 from cuentas.guests gu where gu.group_id=m.group_id and gu.guest_id=m.user_id and gu.claimed_by is not null)))
  from cuentas.groups g where g.id=p_group);
end $$;

create or replace function public.cuentas_member_set_weight(p_group uuid, p_user uuid, p_weight numeric) returns void
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 if p_weight is null or p_weight<0 or p_weight>5 then raise exception 'El peso va de 0 a 5'; end if;
 update cuentas.members set weight=round(p_weight,2) where group_id=p_group and user_id=p_user and status='active';
 if not found then raise exception 'No es miembro activo'; end if;
 perform cuentas.log(p_group,v_user,'member_weight_set',jsonb_build_object('user',p_user,'weight',p_weight));
end $$;

create or replace function public.cuentas_member_set_guardian(p_group uuid, p_user uuid, p_guardian uuid) returns void
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.members where group_id=p_group and user_id=p_user and status='active') then raise exception 'No es miembro activo'; end if;
 if p_guardian is not null then
  if p_guardian=p_user then raise exception 'Una persona no puede ser su propio responsable'; end if;
  if not exists(select 1 from cuentas.members where group_id=p_group and user_id=p_guardian and status='active') then raise exception 'El responsable no es miembro activo'; end if;
  if exists(select 1 from cuentas.members where group_id=p_group and user_id=p_guardian and guardian is not null) then raise exception 'El responsable ya tiene un responsable'; end if;
  if exists(select 1 from cuentas.members where group_id=p_group and guardian=p_user) then raise exception 'Esa persona ya es responsable de otras'; end if;
 end if;
 update cuentas.members set guardian=p_guardian where group_id=p_group and user_id=p_user;
 perform cuentas.log(p_group,v_user,'member_guardian_set',jsonb_build_object('user',p_user,'guardian',p_guardian));
end $$;

-- categorías
create or replace function public.cuentas_categories_list(p_group uuid) returns jsonb
language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.group_categories where group_id=p_group) then
  insert into cuentas.group_categories(group_id,key,name,icon,color,position) values
   (p_group,'comida','Comida y bebida','fork',0,1),(p_group,'transporte','Transporte','car',3,2),
   (p_group,'alojamiento','Alojamiento','bed',1,3),(p_group,'ocio','Salidas y ocio','ticket',4,4),
   (p_group,'hogar','Hogar y servicios','home',5,5),(p_group,'compras','Compras y regalos','bag',2,6),
   (p_group,'otros','Otros','dots',5,7) on conflict do nothing;
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object('key',c.key,'name',c.name,'icon',c.icon,'color',c.color,'archived',c.archived) order by c.position,c.name)
   from cuentas.group_categories c where c.group_id=p_group),'[]'::jsonb);
end $$;

create or replace function public.cuentas_category_save(p_group uuid, p_key text, p_name text, p_icon text, p_color int) returns text
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); v_key text:=p_key; v_name text:=trim(coalesce(p_name,'')); v_pos int;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 if length(v_name) not between 1 and 30 then raise exception 'El nombre va de 1 a 30 letras'; end if;
 if p_icon is null or p_icon not in ('fork','car','bed','ticket','home','bag','gift','heart','plane','dots','sun','paw') then raise exception 'Ícono inválido'; end if;
 if p_color is null or p_color not between 0 and 5 then raise exception 'Color inválido'; end if;
 perform public.cuentas_categories_list(p_group);
 if v_key is null then
  v_key:=left(regexp_replace(lower(translate(v_name,'áéíóúñÁÉÍÓÚÑ','aeiounaeioun')),'[^a-z0-9]+','-','g'),24)||'-'||substr(md5(random()::text),1,5);
  select coalesce(max(position),0)+1 into v_pos from cuentas.group_categories where group_id=p_group;
  insert into cuentas.group_categories(group_id,key,name,icon,color,position) values(p_group,v_key,v_name,p_icon,p_color,v_pos);
 else
  update cuentas.group_categories set name=v_name,icon=p_icon,color=p_color where group_id=p_group and key=v_key;
  if not found then raise exception 'La categoría no existe'; end if;
 end if;
 perform cuentas.log(p_group,v_user,'category_saved',jsonb_build_object('key',v_key));
 return v_key;
end $$;

create or replace function public.cuentas_category_archive(p_group uuid, p_key text, p_archived boolean) returns void
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m join cuentas.groups g on g.id=m.group_id where m.group_id=p_group and m.user_id=v_user and m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then raise exception 'No autorizado'; end if;
 update cuentas.group_categories set archived=coalesce(p_archived,true) where group_id=p_group and key=p_key;
 if not found then raise exception 'La categoría no existe'; end if;
 perform cuentas.log(p_group,v_user,'category_archived',jsonb_build_object('key',p_key,'archived',p_archived));
end $$;

-- gastos con categoría y cotización (misma firma anterior + 2 parámetros opcionales al final)
drop function if exists public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text);
drop function if exists public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text);

create or replace function public.cuentas_expense_add(p_group uuid, p_currency text, p_amount_minor bigint, p_payer uuid, p_participants uuid[], p_shares jsonb, p_description text, p_occurred_on date, p_key text, p_category text default null, p_fx numeric default null)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); v_status text; v_ref text; v_id uuid; v_parts uuid[]; v_n int; v_base bigint; v_rem bigint; v_i int:=0; v_sum bigint:=0; r record; u uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia'; end if;
 select status, reference_currency into v_status, v_ref from cuentas.groups where id=p_group;
 if not found or not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='expense' and amount_minor=p_amount_minor and currency=p_currency and from_user=p_payer) then raise exception 'La clave de idempotencia ya se usó con otros datos'; end if;
  return v_id; end if;
 if v_status<>'open' then raise exception 'El grupo está cerrado: no admite gastos nuevos'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;
 if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;
 if not cuentas.is_active_member(p_group,p_payer) then raise exception 'El pagador no es miembro activo'; end if;
 if p_category is not null and not exists(select 1 from cuentas.group_categories where group_id=p_group and key=p_category) then raise exception 'La categoría no existe'; end if;
 if p_fx is not null and (p_currency=v_ref or p_fx<=0 or p_fx>1000000000) then raise exception 'Cotización inválida'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,occurred_on,created_by,idempotency_key,category,fx_rate)
 values(p_group,'expense',p_currency,p_amount_minor,p_payer,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key,p_category,case when p_currency=v_ref then null else p_fx end) returning id into v_id;
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

create or replace function public.cuentas_expense_edit(p_expense uuid, p_currency text, p_amount_minor bigint, p_payer uuid, p_participants uuid[], p_shares jsonb, p_description text, p_occurred_on date, p_key text, p_category text default null, p_fx numeric default null)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_group uuid; v_new uuid;
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 select group_id into v_group from cuentas.movements where id=p_expense and kind='expense';
 if not found then raise exception 'No autorizado'; end if;
 if exists(select 1 from cuentas.movements where ref_id=p_expense and kind='void') then raise exception 'Ese gasto ya fue anulado o editado'; end if;
 perform public.cuentas_expense_void(p_expense,'Editado');
 v_new:=public.cuentas_expense_add(v_group,p_currency,p_amount_minor,p_payer,p_participants,p_shares,p_description,p_occurred_on,p_key,p_category,p_fx);
 perform cuentas.log(v_group,auth.uid(),'expense_edited',jsonb_build_object('old',p_expense,'new',v_new));
 return v_new;
end $$;

-- lista de movimientos: suma category y fx_rate (el resto igual)
create or replace function public.cuentas_movements_list(p_group uuid) returns jsonb
language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',m.id,'kind',m.kind,'currency',m.currency,'amount_minor',m.amount_minor,'from_user',cuentas.eff(p_group,m.from_user),'to_user',cuentas.eff(p_group,m.to_user),
   'description',m.description,'occurred_on',m.occurred_on,'ref_id',m.ref_id,'created_by',m.created_by,'created_at',m.created_at,
   'category',m.category,'fx_rate',m.fx_rate,
   'voided',exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void'),
   'reversed',exists(select 1 from cuentas.movements v2 where v2.ref_id=m.id and v2.kind in ('payment_reversal','compensation_reversal')),'confirmed',exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation'),
   'shares',(select coalesce(jsonb_object_agg(x.u,x.s),'{}'::jsonb) from (select cuentas.eff(p_group,s.user_id) u, sum(s.share_minor) s from cuentas.movement_shares s where s.movement_id=m.id group by 1) x)
  ) order by m.created_at, m.id) from cuentas.movements m where m.group_id=p_group),'[]'::jsonb);
end $$;

-- permisos: solo usuarios autenticados ejecutan las RPC públicas
do $$ declare f text; begin
 foreach f in array array[
  'cuentas_member_set_weight(uuid,uuid,numeric)','cuentas_member_set_guardian(uuid,uuid,uuid)',
  'cuentas_categories_list(uuid)','cuentas_category_save(uuid,text,text,text,integer)','cuentas_category_archive(uuid,text,boolean)',
  'cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric)',
  'cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric)'] loop
  execute format('revoke all on function public.%s from public, anon', f);
  execute format('grant execute on function public.%s to authenticated', f);
 end loop; end $$;
