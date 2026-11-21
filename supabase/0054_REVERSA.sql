-- Reversa de 0054: quita las funciones y las columnas de papelera. Los grupos en la papelera quedan archivados (sin pérdida de datos).
drop function if exists public.cuentas_group_delete(uuid);
drop function if exists public.cuentas_group_restore(uuid);
drop function if exists public.cuentas_groups_trash_list();
delete from cuentas.config where key='trash_days';
alter table cuentas.groups drop column if exists deleted_at, drop column if exists deleted_by, drop column if exists status_before_delete;
