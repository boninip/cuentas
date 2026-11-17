-- Antes de ejecutar: vaciar el bucket desde el panel o la API de Storage (los objetos no se borran con SQL de forma segura).
drop function if exists public.cuentas_receipts_list(uuid);
drop function if exists public.cuentas_receipt_copy(uuid,uuid);
drop function if exists public.cuentas_receipt_register(uuid,int);
drop policy if exists cuentas_receipts_insert on storage.objects;
drop policy if exists cuentas_receipts_select on storage.objects;
drop function if exists public.cuentas_receipt_ok(text);
drop table if exists cuentas.movement_attachments;
delete from storage.buckets where id='cuentas-receipts';
