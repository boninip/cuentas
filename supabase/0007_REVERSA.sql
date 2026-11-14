-- REVERSA de 0007 (SOLO DESARROLLO): borra la base de Cuentas, incluidos sus datos. No usar si hay datos que conservar.
drop function if exists public.cuentas_group_create(text,text), public.cuentas_invite_create(uuid,int,int), public.cuentas_invite_accept(text),
 public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text), public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text),
 public.cuentas_payment_confirm(uuid), public.cuentas_expense_void(uuid,text), public.cuentas_group_set_status(uuid,text),
 public.cuentas_balances(uuid), public.cuentas_movements_list(uuid), public.cuentas_group_get(uuid);
drop table if exists cuentas.audit_log, cuentas.movement_shares, cuentas.movements, cuentas.invites, cuentas.members, cuentas.groups cascade;
drop function if exists cuentas.check_shares(), cuentas.deny_change(), cuentas.is_active_member(uuid,uuid), cuentas.log(uuid,uuid,text,jsonb);
