-- 0054 · Cuentas: eliminar grupos vacíos con papelera de 30 días (Q1 aprobada 16/11: «archivar siempre; eliminar solo vacíos»).
-- Decisiones mías, configurables: papelera de 30 días (cuentas.config 'trash_days'); no hay borrado físico (el historial y la
-- auditoría nunca se borran): al vencer la papelera el grupo deja de poder restaurarse y queda archivado y oculto.
-- «Vacío» = sin movimientos, propuestas, gastos repetidos ni comprobantes, sin vínculos activos y sin otros miembros activos.
-- Reversa: 0054_REVERSA.sql
alter table cuentas.groups add column if not exists deleted_at timestamptz, add column if not exists deleted_by uuid, add column if not exists status_before_delete text;
insert into cuentas.config(key,int_value) values ('trash_days',30) on conflict (key) do nothing;

create or replace function public.cuentas_group_delete(p_group uuid)
returns void language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); g cuentas.groups%rowtype;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 select * into g from cuentas.groups where id=p_group for update;
 if not found or not cuentas.can(p_group,v_user,'__admin__') then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 if g.deleted_at is not null or g.status='archived' then raise exception 'El grupo está archivado' using detail='CUE_GRUPO_ARCHIVADO'; end if;
 if exists(select 1 from cuentas.movements where group_id=p_group)
    or exists(select 1 from cuentas.proposals where group_id=p_group)
    or exists(select 1 from cuentas.recurring_rules where group_id=p_group)
    or exists(select 1 from cuentas.movement_attachments where group_id=p_group)
    or exists(select 1 from cuentas.shared_accounts where group_id=p_group) then
  raise exception 'El grupo tiene historial: solo se puede archivar' using detail='CUE_GRUPO_CON_HISTORIAL'; end if;
 if exists(select 1 from core.links where group_id=p_group and status='active') then
  raise exception 'Primero desvinculá los viajes y eventos' using detail='CUE_GRUPO_CON_VINCULOS'; end if;
 if exists(select 1 from cuentas.members where group_id=p_group and status='active' and user_id<>v_user) then
  raise exception 'Hay otras personas en el grupo: que salgan antes de eliminarlo' using detail='CUE_GRUPO_CON_MIEMBROS'; end if;
 update cuentas.groups set status_before_delete=status, status='archived', deleted_at=now(), deleted_by=v_user where id=p_group;
 perform cuentas.log(p_group,v_user,'group_deleted','{}'::jsonb);
end $f$;

create or replace function public.cuentas_group_restore(p_group uuid)
returns void language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); g cuentas.groups%rowtype; v_days int:=cuentas.cfg_int('trash_days',30);
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 select * into g from cuentas.groups where id=p_group for update;
 if not found or not cuentas.can(p_group,v_user,'__admin__') then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 if g.deleted_at is null then raise exception 'El grupo no está en la papelera' using detail='CUE_NO_ESTA_EN_PAPELERA'; end if;
 if g.deleted_at + make_interval(days=>v_days) <= now() then raise exception 'La papelera venció: ya no se puede restaurar' using detail='CUE_PAPELERA_VENCIDA'; end if;
 update cuentas.groups set status=coalesce(status_before_delete,'open'), deleted_at=null, deleted_by=null, status_before_delete=null where id=p_group;
 perform cuentas.log(p_group,v_user,'group_restored','{}'::jsonb);
end $f$;

create or replace function public.cuentas_groups_trash_list()
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare v_days int:=cuentas.cfg_int('trash_days',30);
begin
 if auth.uid() is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'deleted_at',g.deleted_at,'expires_at',g.deleted_at+make_interval(days=>v_days)) order by g.deleted_at desc)
  from cuentas.groups g where g.deleted_at is not null and g.deleted_at+make_interval(days=>v_days)>now()
   and cuentas.can(g.id,auth.uid(),'__admin__')),'[]'::jsonb);
end $f$;

revoke all on function public.cuentas_group_delete(uuid), public.cuentas_group_restore(uuid), public.cuentas_groups_trash_list() from public, anon;
grant execute on function public.cuentas_group_delete(uuid), public.cuentas_group_restore(uuid), public.cuentas_groups_trash_list() to authenticated;
