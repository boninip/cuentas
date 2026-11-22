-- 0058 (Cuentas): monedas permitidas configurables y nota larga rechazada con código.
-- Decidido por Pau el 22/11/2026: lista configurable con las 8 actuales por defecto; avisar y no cortar notas de más de 1000 caracteres.
create table if not exists cuentas.allowed_currencies(code text primary key check (code ~ '^[A-Z]{3}$'), active boolean not null default true, updated_at timestamptz not null default now());
alter table cuentas.allowed_currencies enable row level security;
revoke all on cuentas.allowed_currencies from public, anon, authenticated;
insert into cuentas.allowed_currencies(code) values ('USD'),('EUR'),('BRL'),('ARS'),('CLP'),('UYU'),('MXN'),('GBP') on conflict do nothing;
create or replace function cuentas.currency_ok(p text) returns boolean language sql stable security definer set search_path to '' as $$ select exists(select 1 from cuentas.allowed_currencies where code=p and active) $$;
revoke all on function cuentas.currency_ok(text) from public, anon, authenticated;
do $mig$
declare v_def text; v_new text; v_sig regprocedure;
begin
 v_sig:='public.cuentas_group_create(text,text)'::regprocedure; v_def:=pg_get_functiondef(v_sig);
 if position($a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Moneda inválida' using detail='CUE_MONEDA_INVALIDA'; end if;$a$ in v_def)=0 then raise exception 'Ancla no encontrada en group_create'; end if;
 execute replace(v_def,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Moneda inválida' using detail='CUE_MONEDA_INVALIDA'; end if;$a$,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Moneda inválida' using detail='CUE_MONEDA_INVALIDA'; end if; if not cuentas.currency_ok(p_currency) then raise exception 'Esa moneda no está habilitada' using detail='CUE_MONEDA_NO_PERMITIDA'; end if;$a$);
 v_sig:='public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz,text)'::regprocedure; v_def:=pg_get_functiondef(v_sig);
 if position($a$if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;$a$ in v_def)=0 then raise exception 'Ancla no encontrada en expense_add'; end if;
 execute replace(v_def,$a$if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;$a$,$a$if not cuentas.currency_ok(p_currency) then raise exception 'Esa moneda no está habilitada' using detail='CUE_MONEDA_NO_PERMITIDA'; end if;
 if length(trim(coalesce(p_notes,'')))>1000 then raise exception 'La nota es demasiado larga (máximo 1000 caracteres)' using detail='CUE_NOTA_LARGA'; end if;
 if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;$a$);
 v_sig:='public.cuentas_recurring_save(uuid,text,bigint,text,uuid,uuid[],jsonb,text,numeric,text,date,date)'::regprocedure; v_def:=pg_get_functiondef(v_sig);
 if position($a$or coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Importe o moneda inválidos'; end if;$a$ in v_def)=0 then raise exception 'Ancla no encontrada en recurring_save'; end if;
 execute replace(v_def,$a$or coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Importe o moneda inválidos'; end if;$a$,$a$or coalesce(p_currency,'') !~ '^[A-Z]{3}$' then raise exception 'Importe o moneda inválidos'; end if; if not cuentas.currency_ok(p_currency) then raise exception 'Esa moneda no está habilitada' using detail='CUE_MONEDA_NO_PERMITIDA'; end if;$a$);
 v_sig:='public.cuentas_compensation_propose(uuid,text,bigint,text)'::regprocedure; v_def:=pg_get_functiondef(v_sig);
 if position($a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;$a$ in v_def)=0 then raise exception 'Ancla no encontrada en compensation_propose'; end if;
 execute replace(v_def,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;$a$,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if; if not cuentas.currency_ok(p_currency) then raise exception 'Esa moneda no está habilitada' using detail='CUE_MONEDA_NO_PERMITIDA'; end if;$a$);
 v_sig:='public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text,text,bigint,numeric,text,timestamptz)'::regprocedure; v_def:=pg_get_functiondef(v_sig);
 if position($a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or v_amount is null or v_amount<=0 or v_amount>1000000000000 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if;$a$ in v_def)=0 then raise exception 'Ancla no encontrada en payment_add'; end if;
 execute replace(v_def,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or v_amount is null or v_amount<=0 or v_amount>1000000000000 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if;$a$,$a$if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or v_amount is null or v_amount<=0 or v_amount>1000000000000 then raise exception 'Importe o moneda inválidos' using detail='CUE_IMPORTE_INVALIDO'; end if; if not cuentas.currency_ok(p_currency) then raise exception 'Esa moneda no está habilitada' using detail='CUE_MONEDA_NO_PERMITIDA'; end if;$a$);
end $mig$;
