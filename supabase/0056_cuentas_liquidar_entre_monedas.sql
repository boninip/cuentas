-- 0056 · Cuentas: liquidar entre monedas (ítem 21 de la etapa 4b). GF-14 reconstruido, aprobado Q2a (16/11) y 21/11 (cotización sugerida, confirma quien cobra).
-- Diseño: el pago sigue siendo UN movimiento cuya moneda e importe (currency, amount_minor) son los de la DEUDA que baja (el equivalente).
-- Lo que realmente se pagó queda en paid_currency/paid_amount_minor, junto con fx_rate, fx_source y fx_at. Por eso balances_raw, debt_avail,
-- credit_avail, comp_has_dependents, check_unit_mov y las anulaciones NO cambian: la anulación copia el equivalente, o sea revierte con la misma cotización.
-- Quien cobra confirma el pago (y con él la cotización); también puede rechazarlo mientras no lo confirmó.
-- Reversa: 0056_REVERSA.sql
alter table cuentas.movements add column if not exists paid_currency text, add column if not exists paid_amount_minor bigint;
do $m$ begin
 if not exists(select 1 from pg_constraint where conrelid='cuentas.movements'::regclass and conname='movements_paid_check') then
  alter table cuentas.movements add constraint movements_paid_check check (
   (paid_currency is null and paid_amount_minor is null)
   or (kind='payment' and paid_currency ~ '^[A-Z]{3}$' and paid_currency<>currency and paid_amount_minor>0 and fx_rate is not null)); end if;
end $m$;
-- una cotización de 1 ARS = 0,000687 USD no entra en 6 decimales
alter table cuentas.movements alter column fx_rate type numeric(24,12);
insert into cuentas.config(key,int_value) values ('cross_pay',1) on conflict (key) do nothing;

create or replace function public.cuentas_payment_add(p_group uuid, p_currency text, p_amount_minor bigint, p_to uuid, p_description text, p_occurred_on date, p_key text,
  p_paid_currency text default null, p_paid_minor bigint default null, p_fx numeric default null, p_fx_source text default null, p_fx_at timestamptz default null)
returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_status text; v_id uuid; v_cross boolean:=(p_paid_currency is not null and p_paid_currency is distinct from p_currency); v_amount bigint:=p_amount_minor; v_unit int;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia' using detail='CUE_FALTA_CLAVE'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not exists(select 1 from cuentas.members mm where mm.group_id=p_group and mm.user_id=v_user) then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 -- el servidor es quien calcula el equivalente: baja la deuda por (importe pagado x cotización), con los decimales de la moneda de la deuda
 if v_cross then
  if coalesce(p_currency,'') ~ '^[A-Z]{3}$' and p_paid_minor is not null and p_paid_minor>0 and p_paid_minor<=1000000000000 and p_fx is not null and p_fx>0 and p_fx<=1000000000 then
   v_unit:=cuentas.unit(p_currency); v_amount:=(round(p_paid_minor*p_fx/v_unit)*v_unit)::bigint;
  else v_amount:=null; end if;
 end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='payment' and amount_minor is not distinct from coalesce(v_amount,p_amount_minor) and currency=p_currency and to_user=p_to and paid_amount_minor is not distinct from (case when v_cross then p_paid_minor end)) then raise exception 'La clave de idempotencia ya se usó con otros datos' using detail='CUE_CLAVE_REUSADA'; end if;
  return v_id; end if;
 if v_status='archived' then raise exception 'El grupo está archivado' using detail='CUE_GRUPO_ARCHIVADO'; end if;
 if v_cross then
  if cuentas.cfg_int('cross_pay',1)<>1 then raise exception 'Pagar en otra moneda está apagado' using detail='CUE_PAGO_OTRA_MONEDA_APAGADO'; end if;
  if p_paid_currency !~ '^[A-Z]{3}$' or p_paid_minor is null or p_paid_minor<=0 or p_paid_minor>1000000000000 or p_paid_minor % cuentas.unit(p_paid_currency)<>0 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if;
  if p_fx is null or p_fx<=0 or p_fx>1000000000 then raise exception 'Cotización inválida' using detail='CUE_COTIZACION_INVALIDA'; end if;
 end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or v_amount is null or v_amount<=0 or v_amount>1000000000000 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if;
 if p_to is null or p_to=v_user or not cuentas.is_active_member(p_group,p_to) then raise exception 'Destinatario inválido' using detail='CUE_DESTINATARIO_INVALIDO'; end if;
 if exists(select 1 from cuentas.guests where group_id=p_group and guest_id=p_to and claimed_by is null) then raise exception 'Esa persona todavía no aceptó la invitación: no se pueden registrar pagos hacia ella' using detail='CUE_DESTINATARIO_SIN_ACEPTAR'; end if;
 if v_amount > greatest(0, -coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=v_user and b.currency=p_currency),0))
   - coalesce((select sum(m.amount_minor) from cuentas.movements m where m.group_id=p_group and m.kind='payment' and m.from_user=v_user and m.currency=p_currency and not exists(select 1 from cuentas.movements c where c.ref_id=m.id)),0)
 then raise exception 'El pago supera lo que debés: no se admite crédito a favor' using detail='CUE_PAGO_SUPERA_DEUDA'; end if;
 if v_amount > greatest(0, coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=p_to and b.currency=p_currency),0))
 then raise exception 'El pago supera lo que esa persona tiene a favor' using detail='CUE_PAGO_SUPERA_CREDITO'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,occurred_on,created_by,idempotency_key,fx_rate,fx_source,fx_at,paid_currency,paid_amount_minor)
 values(p_group,'payment',p_currency,v_amount,v_user,p_to,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key,
  case when v_cross then p_fx end, case when v_cross then left(p_fx_source,60) end, case when v_cross then p_fx_at end,
  case when v_cross then p_paid_currency end, case when v_cross then p_paid_minor end) returning id into v_id;
 perform cuentas.log(p_group,v_user,'payment_added',jsonb_build_object('movement',v_id)||case when v_cross then jsonb_build_object('paid_currency',p_paid_currency,'paid_minor',p_paid_minor,'fx',p_fx,'equivalent_minor',v_amount) else '{}'::jsonb end);
 return v_id;
end $function$;

do $mig$
declare v_def text; v_new text;
begin
 -- se reemplaza la firma vieja de 7 argumentos (si no, una llamada con 7 argumentos sería ambigua)
 drop function if exists public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text);
 revoke all on function public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text,text,bigint,numeric,text,timestamptz) from public, anon;
 grant execute on function public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text,text,bigint,numeric,text,timestamptz) to authenticated;
 -- la lista de movimientos devuelve lo pagado y la fuente de la cotización
 v_def:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 v_new:=replace(v_def,'''category'',m.category,''fx_rate'',m.fx_rate,','''category'',m.category,''fx_rate'',m.fx_rate,''fx_source'',m.fx_source,''fx_at'',m.fx_at,''paid_currency'',m.paid_currency,''paid_amount_minor'',m.paid_amount_minor,');
 if v_new=v_def then raise exception 'Ancla de cuentas_movements_list no encontrada'; end if;
 execute v_new;
 -- quien cobra puede rechazar un pago que todavía no confirmó
 v_def:=pg_get_functiondef('public.cuentas_payment_cancel(uuid)'::regprocedure);
 v_new:=replace(v_def,'if not (v_adm or (p.created_by=v_user and not v_conf)) then','if not (v_adm or ((p.created_by=v_user or p.to_user=v_user) and not v_conf)) then');
 v_new:=replace(v_new,'''by_admin'',v_adm and p.created_by<>v_user)','''by_admin'',v_adm and p.created_by<>v_user,''by_receiver'',p.to_user=v_user and p.created_by<>v_user and not v_adm)');
 if v_new=v_def or position('by_receiver' in v_new)=0 then raise exception 'Anclas de cuentas_payment_cancel no encontradas'; end if;
 execute v_new;
 -- group_get avisa si pagar en otra moneda está habilitado
 v_def:=pg_get_functiondef('public.cuentas_group_get(uuid)'::regprocedure);
 v_new:=replace(v_def,'''fx_warn_pct'',cuentas.cfg_int(''fx_warn_pct'',10),','''fx_warn_pct'',cuentas.cfg_int(''fx_warn_pct'',10),''cross_pay'',(cuentas.cfg_int(''cross_pay'',1)=1),');
 if v_new=v_def then raise exception 'Ancla de cuentas_group_get no encontrada'; end if;
 execute v_new;
end $mig$;
