-- Reversa 0011 (DEV). Revierte los permisos y elimina delegaciones y archivo. Revisión estática: no ejecutada.
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_invite_create(uuid,integer,integer)'::regprocedure);
 d:=replace(d,$a$m.status='active' and g.status<>'archived' and cuentas.can(p_group,v_user,'invite')) then$a$,$b$m.status='active' and m.role='admin' and g.status<>'archived') then$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_group_set_status(uuid,text)'::regprocedure);
 d:=replace(d,$a$ if not found or not (case when p_status='closed' then cuentas.can(p_group,v_user,'close') else cuentas.can(p_group,v_user,'__admin__') end) then raise exception 'No autorizado'; end if;$a$,
  $b$ if not found or not exists(select 1 from cuentas.members where group_id=p_group and user_id=v_user and status='active' and role='admin') then raise exception 'No autorizado'; end if;$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_expense_void(uuid,text)'::regprocedure);
 d:=replace(d,$a$if e.created_by<>v_user and not cuentas.can(e.group_id,v_user,'void') then$a$,$b$if e.created_by<>v_user and v_role<>'admin' then$b$);
 execute d;
 d:=pg_get_functiondef('public.cuentas_member_leave(uuid)'::regprocedure);
 d:=regexp_replace(d,E' update cuentas.delegations set revoked_at=now\\(\\), revoked_by=v_user where group_id=p_group and delegate_id=v_user and revoked_at is null;\\n','');
 execute d;
 d:=pg_get_functiondef('public.cuentas_member_remove(uuid,uuid)'::regprocedure);
 d:=regexp_replace(d,E' update cuentas.delegations set revoked_at=now\\(\\), revoked_by=v_user where group_id=p_group and delegate_id=p_user and revoked_at is null;\\n','');
 execute d;
end $m$;
update cuentas.members set role='member' where role='coadmin';
drop function if exists public.cuentas_group_archive(uuid);
drop function if exists public.cuentas_delegations_list(uuid);
drop function if exists public.cuentas_delegate_revoke(uuid,uuid);
drop function if exists public.cuentas_delegate_grant(uuid,uuid,text[]);
drop function if exists cuentas.can(uuid,uuid,text);
drop table if exists cuentas.delegations;
