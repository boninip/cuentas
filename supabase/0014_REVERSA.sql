drop function if exists public.cuentas_group_payouts(uuid);
drop function if exists public.cuentas_payout_clear();
drop function if exists public.cuentas_payout_get();
drop function if exists public.cuentas_payout_set(text,text,text,text,boolean);
drop table if exists cuentas.payout_info;
