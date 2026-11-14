-- 0011 · Cuentas (DEV): coadministrador por delegación expresa, revocable y auditada; archivar grupo.
-- Opciones RECOMENDADAS (pendientes de aprobación de Pau). Alcances: invite, close, void, link.

create table cuentas.delegations(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references cuentas.groups(id),
 delegate_id uuid not null references auth.users(id),
 scopes text[] not null check (cardinality(scopes)>0 and scopes <@ array['invite','close','void','link']),
 granted_by uuid not null references auth.users(id),
 granted_at timestamptz not null default now(),
 revoked_at timestamptz,
 revoked_by uuid references auth.users(id)
);
create unique index delegations_one_active on cuentas.delegations(group_id,delegate_id) where revoked_at is null;
alter table cuentas.delegations enable row level security;
revoke all on cuentas.delegations from public, anon, authenticated;

-- ¿Puede esta persona realizar el alcance? Admin siempre; coadmin solo con delegación vigente que lo incluya.
create function cuentas.can(p_group uuid, p_user uuid, p_scope text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from cuentas.members m where m.group_id=p_group and m.user_id=p_user and m.status='active' and m.role='admin')
  or exists(select 1 from cuentas.members m join cuentas.delegations d on d.group_id=m.group_id and d.delegate_id=m.user_id and d.revoked_at is null
            where m.group_id=p_group and m.user_id=p_user and m.status='active' and m.role='coadmin' and p_scope=any(d.scopes)) $$;
revoke all on function cuentas.can(uuid,uuid,text) from public, anon, authenticated;

create function public.cuentas_delegate_grant(p_group uuid, p_user uuid, p_scopes text[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;
 if p_user=v_user then raise exception 'No podés delegarte a vos mismo'; end if;
 if not exists(select 1 from cuentas.members where group_id=p_group and user_id=p_user and status='active' and role in ('member','coadmin')) then raise exception 'La persona no es miembro activo'; end if;
 if p_scopes is null or cardinality(p_scopes)=0 or not (p_scopes <@ array['invite','close','void','link']) then raise exception 'Alcance inválido'; end if;
 update cuentas.delegations set revoked_at=now(), revoked_by=v_user where group_id=p_group and delegate_id=p_user and revoked_at is null;
 insert into cuentas.delegations(group_id,delegate_id,scopes,granted_by) values(p_group,p_user,p_scopes,v_user) returning id into v_id;
 update cuentas.members set role='coadmin' where group_id=p_group and user_id=p_user;
 perform cuentas.log(p_group,v_user,'delegation_granted',jsonb_build_object('delegate',p_user,'scopes',to_jsonb(p_scopes)));
 return v_id;
end $$;

create function public.cuentas_delegate_revoke(p_group uuid, p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;
 update cuentas.delegations set revoked_at=now(), revoked_by=v_user where group_id=p_group and delegate_id=p_user and revoked_at is null;
 if not found then raise exception 'No hay delegación vigente'; end if;
 update cuentas.members set role='member' where group_id=p_group and user_id=p_user and role='coadmin';
 perform cuentas.log(p_group,v_user,'delegation_revoked',jsonb_build_object('delegate',p_user));
end $$;

create function public.cuentas_delegations_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'delegate_id',d.delegate_id,'scopes',d.scopes,'granted_by',d.granted_by,'granted_at',d.granted_at) order by d.granted_at)
   from cuentas.delegations d where d.group_id=p_group and d.revoked_at is null),'[]'::jsonb);
end $$;

-- Permisos con delegación: invitar (invite), cerrar (close), anular gasto ajeno (void). Reabrir queda solo para el administrador.
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_invite_create(uuid,integer,integer)'::regprocedure);
 if position($a$m.status='active' and m.role='admin' and g.status<>'archived') then$a$ in d)=0 then raise exception 'patrón invite'; end if;
 d:=replace(d,$a$m.status='active' and m.role='admin' and g.status<>'archived') then$a$,$b$m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_group_set_status(uuid,text)'::regprocedure);
 if position($a$ if not found or not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;$a$ in d)=0 then raise exception 'patrón status'; end if;
 d:=replace(d,$a$ if not found or not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;$a$,
  $b$ if not found or not (case when p_status='closed' then cuentas.can(p_group,v_user,'close') else cuentas.can(p_group,v_user,'__admin__') end) then raise exception 'No autorizado'; end if;$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_expense_void(uuid,text)'::regprocedure);
 if position($a$if e.created_by<>v_user and v_role<>'admin' then$a$ in d)=0 then raise exception 'patrón void'; end if;
 d:=replace(d,$a$if e.created_by<>v_user and v_role<>'admin' then$a$,$b$if e.created_by<>v_user and not cuentas.can(e.group_id,v_user,'void') then$b$);
 execute d;
 -- salir o ser dado de baja revoca la delegación
 d:=pg_get_functiondef('public.cuentas_member_leave(uuid)'::regprocedure);
 d:=replace(d,$a$ update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=v_user;$a$,
  $b$ update cuentas.delegations set revoked_at=now(), revoked_by=v_user where group_id=p_group and delegate_id=v_user and revoked_at is null;
 update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=v_user;$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_member_remove(uuid,uuid)'::regprocedure);
 d:=replace(d,$a$ update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=p_user;$a$,
  $b$ update cuentas.delegations set revoked_at=now(), revoked_by=v_user where group_id=p_group and delegate_id=p_user and revoked_at is null;
 update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=p_user;$b$);
 execute d;
end $m$;

-- Archivar: solo administrador, solo un grupo cerrado y sin pagos pendientes de confirmación. Solo lectura desde entonces.
create function public.cuentas_group_archive(p_group uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_cur text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select status into v_cur from cuentas.groups where id=p_group;
 if not found or not cuentas.can(p_group,v_user,'__admin__') then raise exception 'No autorizado'; end if;
 if v_cur<>'closed' then raise exception 'Primero hay que cerrar el grupo'; end if;
 if exists(select 1 from cuentas.movements m where m.group_id=p_group and m.kind='payment' and not exists(select 1 from cuentas.movements c where c.ref_id=m.id)) then
  raise exception 'Hay pagos pendientes de confirmar'; end if;
 update cuentas.groups set status='archived' where id=p_group;
 perform cuentas.log(p_group,v_user,'group_archived','{}'::jsonb);
end $$;

revoke all on function public.cuentas_delegate_grant(uuid,uuid,text[]), public.cuentas_delegate_revoke(uuid,uuid), public.cuentas_delegations_list(uuid), public.cuentas_group_archive(uuid) from public, anon;
grant execute on function public.cuentas_delegate_grant(uuid,uuid,text[]), public.cuentas_delegate_revoke(uuid,uuid), public.cuentas_delegations_list(uuid), public.cuentas_group_archive(uuid) to authenticated;
