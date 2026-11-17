-- 0018 Lista de viajes que la persona puede organizar (para elegir al vincular con Cuentas). PROPUESTA, solo DEV.
-- Solo lectura; no toca tablas de Escapada. Devuelve viajes donde es dueña u organizadora.
create function public.core_organizable_trips() returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'destination',t.destination,'starts_on',t.starts_on,'status',t.status) order by t.created_at desc)
   from escapada.escapada_trips t where core.can_organize('escapada_trip',t.id,auth.uid(),null)),'[]'::jsonb);
end $$;
revoke all on function public.core_organizable_trips() from public, anon;
grant execute on function public.core_organizable_trips() to authenticated;
