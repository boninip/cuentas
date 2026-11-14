-- 0013 · Pinto Core (DEV): registro de vínculos entre un grupo de Cuentas y un evento o viaje.
-- El registro vive en Core (decisión aprobada). Un evento vincula un solo grupo activo; un grupo puede tener varios eventos.
-- Desvincular o eliminar el evento NO borra obligaciones, pagos ni historial en Cuentas. Ningún rol de evento o viaje da acceso financiero.
create table core.links(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null,                      -- grupo de Cuentas (sin FK entre dominios; se valida en la función)
 ref_type text not null check (ref_type in ('juntada','escapada_trip')),
 ref_id uuid not null,                        -- evento o viaje (sin FK: borrar el evento no toca el vínculo ni a Cuentas)
 status text not null default 'active' check (status in ('active','unlinked')),
 linked_by uuid not null references auth.users(id),
 linked_at timestamptz not null default now(),
 unlinked_by uuid references auth.users(id),
 unlinked_at timestamptz
);
create unique index links_one_active_per_ref on core.links(ref_type,ref_id) where status='active';
create index links_group_idx on core.links(group_id);
alter table core.links enable row level security;
revoke all on core.links from public, anon, authenticated;

-- ¿Esta persona organiza el evento o viaje? Juntada: con el token de organizador; Escapada: dueño u organizador.
create function core.can_organize(p_ref_type text, p_ref_id uuid, p_user uuid, p_organizer uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if p_ref_type='juntada' then
  return p_organizer is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.organizer_token_hash=encode(extensions.digest(p_organizer::text,'sha256'),'hex'));
 elsif p_ref_type='escapada_trip' then
  return exists(select 1 from escapada.escapada_trips t where t.id=p_ref_id and t.owner_id=p_user)
      or exists(select 1 from escapada.escapada_members m where m.trip_id=p_ref_id and m.user_id=p_user and m.role in ('organizer'));
 end if;
 return false;
end $$;
revoke all on function core.can_organize(text,uuid,uuid,uuid) from public, anon, authenticated;

create function public.core_link_create(p_group uuid, p_ref_type text, p_ref_id uuid, p_organizer uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_ref_type not in ('juntada','escapada_trip') then raise exception 'Tipo de vínculo inválido'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not cuentas.can(p_group,v_user,'link') then raise exception 'No autorizado'; end if;
 if v_status='archived' then raise exception 'El grupo está archivado'; end if;
 if not core.can_organize(p_ref_type,p_ref_id,v_user,p_organizer) then raise exception 'No autorizado en el evento o viaje'; end if;
 if exists(select 1 from core.links where ref_type=p_ref_type and ref_id=p_ref_id and status='active') then raise exception 'Ese evento o viaje ya está vinculado a un grupo'; end if;
 insert into core.links(group_id,ref_type,ref_id,linked_by) values(p_group,p_ref_type,p_ref_id,v_user) returning id into v_id;
 perform cuentas.log(p_group,v_user,'link_created',jsonb_build_object('link',v_id,'ref_type',p_ref_type,'ref_id',p_ref_id));
 return v_id;
end $$;

create function public.core_link_remove(p_link uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); l core.links%rowtype;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into l from core.links where id=p_link for update;
 if not found or not cuentas.can(l.group_id,v_user,'link') then raise exception 'No autorizado'; end if;
 if l.status<>'active' then return; end if;
 update core.links set status='unlinked', unlinked_by=v_user, unlinked_at=now() where id=p_link;
 perform cuentas.log(l.group_id,v_user,'link_removed',jsonb_build_object('link',p_link,'ref_type',l.ref_type,'ref_id',l.ref_id));
end $$;

-- Vínculos del grupo (para sus miembros). Muestra el nombre del evento o viaje como referencia.
create function public.core_links_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'ref_type',l.ref_type,'ref_id',l.ref_id,'status',l.status,'linked_at',l.linked_at,'unlinked_at',l.unlinked_at,
   'name',case l.ref_type when 'juntada' then (select j.nombre from juntada.juntadas j where j.id=l.ref_id) else (select t.name from escapada.escapada_trips t where t.id=l.ref_id) end) order by l.linked_at desc)
   from core.links l where l.group_id=p_group),'[]'::jsonb);
end $$;

-- Desde el evento o viaje: ¿tiene un grupo de Cuentas vinculado? Solo para quien lo organiza; devuelve el id y el nombre del grupo, nada financiero.
create function public.core_link_for_ref(p_ref_type text, p_ref_id uuid, p_organizer uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); l core.links%rowtype;
begin
 if p_ref_type not in ('juntada','escapada_trip') then raise exception 'Tipo de vínculo inválido'; end if;
 if not core.can_organize(p_ref_type,p_ref_id,v_user,p_organizer) then raise exception 'No autorizado'; end if;
 select * into l from core.links where ref_type=p_ref_type and ref_id=p_ref_id and status='active';
 if not found then return null; end if;
 return jsonb_build_object('link_id',l.id,'group_id',l.group_id,'group_name',(select g.name from cuentas.groups g where g.id=l.group_id));
end $$;

revoke all on function public.core_link_create(uuid,text,uuid,uuid), public.core_link_remove(uuid), public.core_links_list(uuid), public.core_link_for_ref(text,uuid,uuid) from public, anon;
grant execute on function public.core_link_create(uuid,text,uuid,uuid), public.core_link_remove(uuid), public.core_links_list(uuid), public.core_link_for_ref(text,uuid,uuid) to authenticated;
