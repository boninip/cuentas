-- 0010 · Cuentas (DEV): pago de más rechazado, salida y baja de miembros, exmiembro lee lo propio.
-- Opciones RECOMENDADAS de «Cuentas · Definiciones clave propuestas» (pendientes de aprobación de Pau).

-- Saldos confirmados sin chequeo de acceso (uso interno).
create function cuentas.balances_raw(p_group uuid) returns table(user_id uuid, currency text, balance_minor bigint)
language sql stable security definer set search_path='' as $$
 with e as (select m.id,m.currency as cur,m.amount_minor,m.from_user from cuentas.movements m
   where m.group_id=p_group and m.kind='expense' and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void')),
 p as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='payment' and exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')),
 l as (
  select e.from_user as u, e.cur, e.amount_minor as a from e
  union all select s.user_id, e.cur, -s.share_minor from cuentas.movement_shares s join e on e.id=s.movement_id
  union all select p.from_user, p.cur, p.amount_minor from p
  union all select p.to_user, p.cur, -p.amount_minor from p)
 select l.u, l.cur, sum(l.a)::bigint from l group by l.u, l.cur $$;
revoke all on function cuentas.balances_raw(uuid) from public, anon, authenticated;

-- Pago de más: se rechaza (no hay crédito a favor en V1). Pagos parciales: permitidos.
do $m$
declare d text; anchor text:=$a$ if p_to is null or p_to=v_user or not cuentas.is_active_member(p_group,p_to) then raise exception 'Destinatario inválido'; end if;$a$; blk text;
begin
 blk:=anchor||$b$
 -- 0010:begin
 if p_amount_minor > greatest(0, -coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=v_user and b.currency=p_currency),0))
   - coalesce((select sum(m.amount_minor) from cuentas.movements m where m.group_id=p_group and m.kind='payment' and m.from_user=v_user and m.currency=p_currency and not exists(select 1 from cuentas.movements c where c.ref_id=m.id)),0)
 then raise exception 'El pago supera lo que debés: no se admite crédito a favor'; end if;
 if p_amount_minor > greatest(0, coalesce((select b.balance_minor from cuentas.balances_raw(p_group) b where b.user_id=p_to and b.currency=p_currency),0))
 then raise exception 'El pago supera lo que esa persona tiene a favor'; end if;
 -- 0010:end$b$;
 d:=pg_get_functiondef('public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text)'::regprocedure);
 if position(anchor in d)=0 then raise exception 'patrón no encontrado'; end if;
 execute replace(d,anchor,blk);
end $m$;

-- Salida propia y baja por un administrador. No borra obligaciones ni historial.
create function public.cuentas_member_leave(p_group uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_role text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select role into v_role from cuentas.members where group_id=p_group and user_id=v_user and status='active';
 if not found then raise exception 'No autorizado'; end if;
 if v_role='admin' and not exists(select 1 from cuentas.members where group_id=p_group and user_id<>v_user and status='active' and role='admin') then
  raise exception 'Sos el único administrador: nombrá a otro antes de salir'; end if;
 update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=v_user;
 perform cuentas.log(p_group,v_user,'member_left',jsonb_build_object('user',v_user));
end $$;

create function public.cuentas_member_remove(p_group uuid, p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_role text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select role into v_role from cuentas.members where group_id=p_group and user_id=v_user and status='active';
 if not found or v_role<>'admin' then raise exception 'No autorizado'; end if;
 if p_user=v_user then raise exception 'Para salir usá la opción de salir del grupo'; end if;
 if not exists(select 1 from cuentas.members where group_id=p_group and user_id=p_user and status='active') then raise exception 'No es miembro activo'; end if;
 update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=p_user;
 perform cuentas.log(p_group,v_user,'member_removed',jsonb_build_object('user',p_user));
end $$;

-- Lo que un miembro (activo o ex) ve de sus propias obligaciones.
create function public.cuentas_my_balance(p_group uuid) returns table(currency text, balance_minor bigint, member_status text)
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_st text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select status into v_st from cuentas.members where group_id=p_group and user_id=v_user;
 if not found then raise exception 'No autorizado'; end if;
 return query select b.currency, b.balance_minor, v_st from cuentas.balances_raw(p_group) b where b.user_id=v_user;
end $$;

-- Grupos donde la persona es o fue miembro (para exmiembros: solo lectura de lo propio).
create function public.cuentas_my_groups_all() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'reference_currency',g.reference_currency,'status',g.status,'role',m.role,'member_status',m.status) order by g.created_at desc)
   from cuentas.members m join cuentas.groups g on g.id=m.group_id where m.user_id=auth.uid()),'[]'::jsonb);
end $$;

revoke all on function public.cuentas_member_leave(uuid), public.cuentas_member_remove(uuid,uuid), public.cuentas_my_balance(uuid), public.cuentas_my_groups_all() from public, anon;
grant execute on function public.cuentas_member_leave(uuid), public.cuentas_member_remove(uuid,uuid), public.cuentas_my_balance(uuid), public.cuentas_my_groups_all() to authenticated;
