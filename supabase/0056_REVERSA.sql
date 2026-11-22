-- Reversa de 0056. Atención: si ya hay pagos en otra moneda, al borrar paid_currency/paid_amount_minor se pierde cuánto se pagó y en qué moneda;
-- el pago sigue bajando la deuda por su equivalente (currency/amount_minor), así que los saldos no cambian. Revisar antes de correrla en producción.
do $mig$
declare v_def text; v_new text;
begin
 v_def:=pg_get_functiondef('public.cuentas_payment_cancel(uuid)'::regprocedure);
 v_new:=replace(v_def,'if not (v_adm or ((p.created_by=v_user or p.to_user=v_user) and not v_conf)) then','if not (v_adm or (p.created_by=v_user and not v_conf)) then');
 v_new:=replace(v_new,'''by_admin'',v_adm and p.created_by<>v_user,''by_receiver'',p.to_user=v_user and p.created_by<>v_user and not v_adm)','''by_admin'',v_adm and p.created_by<>v_user)');
 execute v_new;
 v_def:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 v_new:=replace(v_def,'''fx_source'',m.fx_source,''fx_at'',m.fx_at,''paid_currency'',m.paid_currency,''paid_amount_minor'',m.paid_amount_minor,','');
 execute v_new;
 v_def:=pg_get_functiondef('public.cuentas_group_get(uuid)'::regprocedure);
 v_new:=replace(v_def,'''cross_pay'',(cuentas.cfg_int(''cross_pay'',1)=1),','');
 execute v_new;
end $mig$;
drop function if exists public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text,text,bigint,numeric,text,timestamptz);
create or replace function public.cuentas_payment_add(p_group uuid, p_currency text, p_amount_minor bigint, p_to uuid, p_description text, p_occurred_on date, p_key text)
returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_status text; v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia' using detail='CUE_FALTA_CLAVE'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not exists(select 1 from cuentas.members mm where mm.group_id=p_group and mm.user_id=v_user) then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='payment' and amount_minor=p_amount_minor and currency=p_currency and to_user=p_to) then raise exception 'La clave de idempotencia ya se usó con otros datos' using detail='CUE_CLAVE_REUSADA'; end if;
  return v_id; end if;
 if v_status='archived' then raise exception 'El grupo está archivado' using detail='CUE_GRUPO_ARCHIVADO'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if;
 if p_to is null or p_to=v_user or not cuentas.is_active_member(p_group,p_to) then raise exception 'Destinatario inválido' using detail='CUE_DESTINATARIO_INVALIDO'; end if;
 if exists(select 1 from cuentas.guests where group_id=p_group and guest_id=p_to and claimed_by is null) then raise exception 'Esa persona todavía no aceptó la invitación: no se pueden registrar pagos hacia ella' using detail='CUE_DESTINATARIO_SIN_ACEPTAR'; end if;
 if p_amount_minor > greatest(0, -coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=v_user and b.currency=p_currency),0))
   - coalesce((select sum(m.amount_minor) from cuentas.movements m where m.group_id=p_group and m.kind='payment' and m.from_user=v_user and m.currency=p_currency and not exists(select 1 from cuentas.movements c where c.ref_id=m.id)),0)
 then raise exception 'El pago supera lo que debés: no se admite crédito a favor' using detail='CUE_PAGO_SUPERA_DEUDA'; end if;
 if p_amount_minor > greatest(0, coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=p_to and b.currency=p_currency),0))
 then raise exception 'El pago supera lo que esa persona tiene a favor' using detail='CUE_PAGO_SUPERA_CREDITO'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,occurred_on,created_by,idempotency_key)
 values(p_group,'payment',p_currency,p_amount_minor,v_user,p_to,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key) returning id into v_id;
 perform cuentas.log(p_group,v_user,'payment_added',jsonb_build_object('movement',v_id));
 return v_id;
end $function$;
revoke all on function public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text) from public, anon;
grant execute on function public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text) to authenticated;
delete from cuentas.config where key='cross_pay';
alter table cuentas.movements drop constraint if exists movements_paid_check, drop column if exists paid_currency, drop column if exists paid_amount_minor;
alter table cuentas.movements alter column fx_rate type numeric(18,6);
