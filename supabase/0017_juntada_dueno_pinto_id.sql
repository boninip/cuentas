-- 0017 Juntada con Pinto ID, etapa A (aditiva). PROPUESTA, solo DEV.
-- Un evento puede tener dueño logueado (owner_user_id). El token de organizador sigue valiendo (compatibilidad).
-- Primero en reclamar gana; reasignar no está permitido (definición pendiente de Pau).
alter table juntada.juntadas add column owner_user_id uuid references auth.users(id) on delete set null;
create index juntadas_owner_idx on juntada.juntadas(owner_user_id) where owner_user_id is not null;

create function public.juntada_reclamar(p_juntada uuid, p_organizador uuid) returns void
language plpgsql security definer set search_path to '' as $$
declare v_owner uuid; v_ok boolean;
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 select owner_user_id, organizer_token_hash=encode(extensions.digest(coalesce(p_organizador::text,''),'sha256'),'hex')
  into v_owner, v_ok from juntada.juntadas where id=p_juntada for update;
 if not found or not v_ok then raise exception 'Acceso no autorizado'; end if;
 if v_owner is not null and v_owner<>auth.uid() then raise exception 'Este evento ya tiene dueño'; end if;
 update juntada.juntadas set owner_user_id=auth.uid() where id=p_juntada and owner_user_id is null;
end $$;

create function public.juntada_mis_eventos() returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',j.id,'nombre',j.nombre,'fecha_texto',j.fecha_texto,'cancelada',j.cancelada,'suspendida',j.suspendida) order by j.created_at desc)
   from juntada.juntadas j where j.owner_user_id=auth.uid()),'[]'::jsonb);
end $$;

do $$ declare f text; begin
 foreach f in array array['juntada_reclamar(uuid,uuid)','juntada_mis_eventos()'] loop
  execute format('revoke all on function public.%s from public, anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop; end $$;

-- can_organize: el dueño logueado también puede organizar (además del token).
do $m$ declare d text; n text:='return p_organizer is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.organizer_token_hash=encode(extensions.digest(p_organizer::text,''sha256''),''hex''));';
begin
 d:=pg_get_functiondef('core.can_organize(text,uuid,uuid,uuid)'::regprocedure);
 if position(n in d)=0 then raise exception 'ancla no encontrada en core.can_organize'; end if;
 d:=replace(d,n,'return (p_organizer is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.organizer_token_hash=encode(extensions.digest(p_organizer::text,''sha256''),''hex''))) or (p_user is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.owner_user_id=p_user));');
 execute d;
end $m$;
