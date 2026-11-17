-- Reversa de 0025 (solo DEV). Quita categorías, cotización, peso y responsable; restaura firmas y funciones anteriores.
-- Requiere volver a crear cuentas_expense_add/edit/movements_list/group_get/balances_raw de 0023/0024 (ver esos archivos).
drop function if exists public.cuentas_member_set_weight(uuid,uuid,numeric);
drop function if exists public.cuentas_member_set_guardian(uuid,uuid,uuid);
drop function if exists public.cuentas_categories_list(uuid);
drop function if exists public.cuentas_category_save(uuid,text,text,text,integer);
drop function if exists public.cuentas_category_archive(uuid,text,boolean);
drop function if exists public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric);
drop function if exists public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric);
-- (re-crear las versiones previas desde 0019-0024 antes de usar la app)
drop function if exists cuentas.eff_pay(uuid,uuid);
drop table if exists cuentas.group_categories;
alter table cuentas.movements drop column if exists category, drop column if exists fx_rate;
alter table cuentas.members drop column if exists weight, drop column if exists guardian;
