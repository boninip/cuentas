-- Reversa de 0060: quita los disparadores, las funciones y la tabla de preferencias de avisos. Los avisos ya generados quedan en core.notifications.
drop trigger if exists groups_status_notify2 on cuentas.groups;
drop trigger if exists shares_notify on cuentas.movement_shares;
drop trigger if exists movements_notify on cuentas.movements;
drop function if exists cuentas.t_notify_group_status();
drop function if exists cuentas.t_notify_share();
drop function if exists cuentas.t_notify_movement();
drop function if exists public.cuentas_notif_pref_set(text,boolean);
drop function if exists public.cuentas_notif_prefs_get();
drop function if exists cuentas.notify_pref(uuid,text,uuid,uuid,jsonb,boolean,boolean);
drop table if exists cuentas.notif_prefs;
