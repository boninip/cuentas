-- 0028 PROPUESTA (no aprobada): foto del comprobante por gasto. Decisiones de Pau (15/11): una foto por gasto (~1 MB),
-- visible para miembros activos del grupo, conservada al anular el gasto (libro append-only: sin borrado).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('cuentas-receipts','cuentas-receipts',false,1500000,array['image/jpeg'])
on conflict(id) do nothing;

create table cuentas.movement_attachments(
 movement_id uuid primary key references cuentas.movements(id),
 group_id uuid not null references cuentas.groups(id),
 path text not null check (path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'),
 size_bytes int not null check (size_bytes>0 and size_bytes<=1500000),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table cuentas.movement_attachments enable row level security;

-- Las políticas de Storage corren como el usuario, que no tiene acceso al esquema cuentas: se consulta por esta función.
create function public.cuentas_receipt_ok(p_path text) returns boolean
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null or p_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$' then return false; end if;
 return cuentas.is_active_member(split_part(p_path,'/',1)::uuid,auth.uid());
end $$;
revoke all on function public.cuentas_receipt_ok(text) from public, anon;
grant execute on function public.cuentas_receipt_ok(text) to authenticated;

create policy cuentas_receipts_select on storage.objects for select to authenticated
 using (bucket_id='cuentas-receipts' and public.cuentas_receipt_ok(name));
create policy cuentas_receipts_insert on storage.objects for insert to authenticated
 with check (bucket_id='cuentas-receipts' and public.cuentas_receipt_ok(name));
-- Sin políticas de update ni delete: los comprobantes no se pisan ni se borran.

create function public.cuentas_receipt_register(p_movement uuid,p_size int) returns text
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); m record; v_path text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select id,group_id,kind into m from cuentas.movements where id=p_movement;
 if not found or m.kind<>'expense' or not cuentas.is_active_member(m.group_id,v_user) then raise exception 'No autorizado'; end if;
 if p_size is null or p_size<=0 or p_size>1500000 then raise exception 'La foto es demasiado grande'; end if;
 v_path:=m.group_id||'/'||m.id||'.jpg';
 if not exists(select 1 from storage.objects where bucket_id='cuentas-receipts' and name=v_path) then raise exception 'La foto no llegó al servidor'; end if;
 if exists(select 1 from cuentas.movement_attachments where movement_id=p_movement) then raise exception 'Este gasto ya tiene comprobante'; end if;
 insert into cuentas.movement_attachments(movement_id,group_id,path,size_bytes,created_by) values(m.id,m.group_id,v_path,p_size,v_user);
 perform cuentas.log(m.group_id,v_user,'receipt_added',jsonb_build_object('movement',m.id));
 return v_path;
end $$;

-- Al editar un gasto (se anula y se crea otro) el comprobante se vincula al nuevo sin copiar el archivo.
create function public.cuentas_receipt_copy(p_from uuid,p_to uuid) returns void
language plpgsql security definer set search_path to '' as $$
declare v_user uuid:=auth.uid(); a record; g uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into a from cuentas.movement_attachments where movement_id=p_from;
 if not found then return; end if;
 select group_id into g from cuentas.movements where id=p_to and kind='expense';
 if g is null or g<>a.group_id or not cuentas.is_active_member(g,v_user) then raise exception 'No autorizado'; end if;
 insert into cuentas.movement_attachments(movement_id,group_id,path,size_bytes,created_by) values(p_to,g,a.path,a.size_bytes,v_user) on conflict do nothing;
end $$;

create function public.cuentas_receipts_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('movement',movement_id,'path',path)) from cuentas.movement_attachments where group_id=p_group),'[]'::jsonb);
end $$;

do $$ declare f text; begin
 foreach f in array array['cuentas_receipt_register(uuid,int)','cuentas_receipt_copy(uuid,uuid)','cuentas_receipts_list(uuid)'] loop
  execute format('revoke all on function public.%s from public, anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop; end $$;
