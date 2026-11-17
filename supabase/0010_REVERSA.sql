-- Reversa 0010 (DEV).
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text)'::regprocedure);
 d:=regexp_replace(d,E'\\n *-- 0010:begin.*?-- 0010:end','','s');
 execute d;
end $m$;
drop function if exists public.cuentas_member_leave(uuid);
drop function if exists public.cuentas_member_remove(uuid,uuid);
drop function if exists public.cuentas_my_balance(uuid);
drop function if exists public.cuentas_my_groups_all();
drop function if exists cuentas.balances_raw(uuid);
