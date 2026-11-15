drop function if exists public.cuentas_recurring_run(uuid);
drop function if exists public.cuentas_recurring_set_status(uuid,text);
drop function if exists public.cuentas_recurring_list(uuid);
drop function if exists public.cuentas_recurring_save(uuid,text,bigint,text,uuid,uuid[],jsonb,text,numeric,text,date,date);
drop function if exists cuentas.rec_next(text,date,date);
drop table if exists cuentas.recurring_rules; -- los gastos ya generados quedan en el libro (append-only)
