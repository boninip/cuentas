-- 0022 Pinto ID: nombre visible de cada persona (core.planazo_profiles ya existía, sin forma de cargarlo). PROPUESTA, solo DEV.
-- Sin esto, en los grupos todos aparecían como «Miembro xxxx». Solo lo ven los miembros de los mismos grupos (vía cuentas_group_get).
create function public.core_profile_get() returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return (select jsonb_build_object('display_name',p.display_name) from core.planazo_profiles p where p.user_id=auth.uid());
end $$;
create function public.core_profile_set(p_name text) returns void
language plpgsql security definer set search_path to '' as $$
declare n text:=btrim(regexp_replace(coalesce(p_name,''),'\s+',' ','g'));
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if char_length(n) not between 1 and 40 then raise exception 'El nombre debe tener entre 1 y 40 caracteres'; end if;
 insert into core.planazo_profiles(user_id,display_name) values(auth.uid(),n)
  on conflict(user_id) do update set display_name=excluded.display_name;
end $$;
do $$ declare f text; begin
 foreach f in array array['core_profile_get()','core_profile_set(text)'] loop
  execute format('revoke all on function public.%s from public, anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop; end $$;
