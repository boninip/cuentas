-- 0027 PROPUESTA (no aprobada): gastos recurrentes (alquiler, expensas, suscripciones).
-- Sin pg_cron: los vencimientos se generan en el servidor cuando alguien abre el grupo (cuentas_recurring_run).
-- Sin duplicados: cada ocurrencia usa la clave de idempotencia 'rec-<regla>-<fecha>'. Cada gasto generado es un gasto
-- común del libro (anulable/editable como cualquier otro). Fecha de corte: hoy en America/Argentina/Buenos_Aires.
create table cuentas.recurring_rules(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references cuentas.groups(id),
 created_by uuid not null references auth.users(id),
 description text not null check (length(description) between 1 and 300),
 amount_minor bigint not null check (amount_minor>0 and amount_minor<=1000000000000),
 currency text not null check (currency ~ '^[A-Z]{3}$'),
 payer uuid not null references auth.users(id),
 shares jsonb not null,
 category text,
 fx_rate numeric(18,6),
 frequency text not null check (frequency in ('weekly','monthly')),
 start_on date not null,
 ends_on date,
 status text not null default 'active' check (status in ('active','paused','ended')),
 last_run_on date,
 blocked_reason text,
 created_at timestamptz not null default now(),
 check (ends_on is null or ends_on>=start_on)
);
alter table cuentas.recurring_rules enable row level security;
create index recurring_rules_group_idx on cuentas.recurring_rules(group_id) where status<>'ended';

create function cuentas.rec_next(p_freq text, p_start date, p_last date) returns date
language plpgsql immutable set search_path to '' as $$
declare m date; dom int:=extract(day from p_start); eom int;
begin
 if p_last is null then return p_start; end if;
 if p_freq='weekly' then return p_last+7; end if;
 m:=(date_trunc('month',p_last)+interval '1 month')::date;
 eom:=extract(day from (date_trunc('month',m)+interval '1 month - 1 day'));
 return m+(least(dom,eom)-1);
end $$;

create function public.cuentas_recurring_save(p_group uuid,p_description text,p_amount_minor bigint,p_currency text,p_payer uuid,
 p_participants uuid[],p_shares jsonb,p_category text,p_fx numeric,p_frequency text,p_start date,p_ends date default null)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); v_ref text; v_status text; v_id uuid; v_sh jsonb:='{}'; v_parts uuid[]; v_n int; v_i int:=0; v_sum bigint:=0; u uuid; r record;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select reference_currency,status into v_ref,v_status from cuentas.groups where id=p_group;
 if not found or not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 if v_status<>'open' then raise exception 'El grupo está cerrado: no admite gastos nuevos'; end if;
 if coalesce(length(trim(p_description)),0) not between 1 and 300 then raise exception 'Poné una descripción'; end if;
 if p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 or coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Importe o moneda inválidos'; end if;
 if p_frequency not in ('weekly','monthly') then raise exception 'Frecuencia inválida'; end if;
 if p_start is null or p_start<(now() at time zone 'America/Argentina/Buenos_Aires')::date-31 then raise exception 'La fecha de inicio es inválida o muy vieja'; end if;
 if p_ends is not null and p_ends<p_start then raise exception 'El fin es anterior al inicio'; end if;
 if not cuentas.is_active_member(p_group,p_payer) then raise exception 'El pagador no es miembro activo'; end if;
 if p_category is not null and not exists(select 1 from cuentas.group_categories where group_id=p_group and key=p_category) then raise exception 'La categoría no existe'; end if;
 if p_fx is not null and (p_currency=v_ref or p_fx<=0 or p_fx>1000000000) then raise exception 'Cotización inválida'; end if;
 if p_shares is not null then
  if jsonb_typeof(p_shares)<>'object' then raise exception 'Reparto inválido'; end if;
  for r in select key,value from jsonb_each_text(p_shares) loop
   u:=r.key::uuid; if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   if r.value::bigint<0 then raise exception 'Reparto inválido'; end if;
   v_sum:=v_sum+r.value::bigint; end loop;
  if v_sum<>p_amount_minor then raise exception 'El reparto no suma el importe'; end if;
  v_sh:=p_shares;
 else
  select array_agg(distinct x order by x) into v_parts from unnest(p_participants) x; v_n:=coalesce(array_length(v_parts,1),0);
  if v_n=0 then raise exception 'Falta repartir entre al menos una persona'; end if;
  foreach u in array v_parts loop v_i:=v_i+1;
   if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   v_sh:=v_sh||jsonb_build_object(u::text,p_amount_minor/v_n+case when v_i<=p_amount_minor%v_n then 1 else 0 end);
  end loop;
 end if;
 insert into cuentas.recurring_rules(group_id,created_by,description,amount_minor,currency,payer,shares,category,fx_rate,frequency,start_on,ends_on)
 values(p_group,v_user,trim(p_description),p_amount_minor,p_currency,p_payer,v_sh,p_category,case when p_currency=v_ref then null else p_fx end,p_frequency,p_start,p_ends) returning id into v_id;
 perform cuentas.log(p_group,v_user,'recurring_created',jsonb_build_object('rule',v_id,'amount_minor',p_amount_minor,'currency',p_currency));
 return v_id;
end $$;

create function public.cuentas_recurring_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'description',r.description,'amount_minor',r.amount_minor,'currency',r.currency,'payer',cuentas.eff(r.group_id,r.payer),
   'shares',r.shares,'category',r.category,'frequency',r.frequency,'start_on',r.start_on,'ends_on',r.ends_on,'status',r.status,'blocked_reason',r.blocked_reason,'created_by',cuentas.eff(r.group_id,r.created_by),
   'next_on',case when r.status='active' then cuentas.rec_next(r.frequency,r.start_on,r.last_run_on) end) order by r.created_at desc)
  from cuentas.recurring_rules r where r.group_id=p_group and r.status<>'ended'),'[]'::jsonb);
end $$;

create function public.cuentas_recurring_set_status(p_rule uuid,p_status text) returns void
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); r record;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_status not in ('active','paused','ended') then raise exception 'Estado inválido'; end if;
 select * into r from cuentas.recurring_rules where id=p_rule for update;
 if not found or not cuentas.is_active_member(r.group_id,v_user) then raise exception 'No autorizado'; end if;
 if not (r.created_by=v_user or cuentas.can(r.group_id,v_user,'invite')) then raise exception 'Solo quien lo creó o la administración puede cambiarlo'; end if;
 if r.status='ended' then raise exception 'Ya terminó'; end if;
 update cuentas.recurring_rules set status=p_status where id=p_rule;
 perform cuentas.log(r.group_id,v_user,'recurring_'||p_status,jsonb_build_object('rule',p_rule));
end $$;

-- Genera los gastos vencidos (hasta 24 por llamada). Cualquier miembro activo puede dispararlo; los duplicados son imposibles por la clave.
create function public.cuentas_recurring_run(p_group uuid) returns int
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); v_today date:=(now() at time zone 'America/Argentina/Buenos_Aires')::date; v_n int:=0; r record; d date; v_id uuid; v_ref text; k record; v_bad text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 select reference_currency into v_ref from cuentas.groups where id=p_group and status='open';
 if not found then return 0; end if;
 for r in select * from cuentas.recurring_rules where group_id=p_group and status='active' order by created_at for update loop
  v_bad:=null;
  if not cuentas.is_active_member(p_group,r.payer) then v_bad:='El pagador ya no es miembro activo';
  elsif exists(select 1 from jsonb_each_text(r.shares) s where not cuentas.is_active_member(p_group,s.key::uuid)) then v_bad:='Una persona del reparto ya no es miembro activo';
  elsif r.category is not null and not exists(select 1 from cuentas.group_categories where group_id=p_group and key=r.category) then v_bad:='La categoría ya no existe'; end if;
  if v_bad is not null then update cuentas.recurring_rules set blocked_reason=v_bad where id=r.id; continue; end if;
  if r.blocked_reason is not null then update cuentas.recurring_rules set blocked_reason=null where id=r.id; end if;
  loop
   d:=cuentas.rec_next(r.frequency,r.start_on,r.last_run_on);
   exit when d>v_today or (r.ends_on is not null and d>r.ends_on) or v_n>=24;
   insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,occurred_on,created_by,idempotency_key,category,fx_rate)
   values(p_group,'expense',r.currency,r.amount_minor,r.payer,r.description,d,r.created_by,'rec-'||r.id||'-'||d,r.category,r.fx_rate)
   on conflict do nothing returning id into v_id;
   if v_id is not null then
    for k in select key,value from jsonb_each_text(r.shares) loop
     insert into cuentas.movement_shares(movement_id,user_id,share_minor) values(v_id,k.key::uuid,k.value::bigint);
    end loop;
    perform cuentas.log(p_group,r.created_by,'expense_added',jsonb_build_object('movement',v_id,'amount_minor',r.amount_minor,'currency',r.currency,'recurring',r.id));
    v_n:=v_n+1;
   end if;
   v_id:=null;
   update cuentas.recurring_rules set last_run_on=d where id=r.id; r.last_run_on:=d;
  end loop;
  if r.ends_on is not null and cuentas.rec_next(r.frequency,r.start_on,r.last_run_on)>r.ends_on then update cuentas.recurring_rules set status='ended' where id=r.id; end if;
 end loop;
 return v_n;
end $$;

do $$ declare f text; begin
 foreach f in array array['cuentas_recurring_save(uuid,text,bigint,text,uuid,uuid[],jsonb,text,numeric,text,date,date)','cuentas_recurring_list(uuid)','cuentas_recurring_set_status(uuid,text)','cuentas_recurring_run(uuid)'] loop
  execute format('revoke all on function public.%s from public, anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop; end $$;
