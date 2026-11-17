-- Reversa 0013 (DEV): elimina el registro de vínculos (no toca nada de Cuentas).
drop function if exists public.core_link_for_ref(text,uuid,uuid);
drop function if exists public.core_links_list(uuid);
drop function if exists public.core_link_remove(uuid);
drop function if exists public.core_link_create(uuid,text,uuid,uuid);
drop function if exists core.can_organize(text,uuid,uuid,uuid);
drop table if exists core.links;
