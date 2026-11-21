-- Reversa de 0050: vuelve a las definiciones previas (sin ref_name ni requested_by_name).
create or replace function public.core_link_requests_list(p_group uuid default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión' using detail='LNK_SIN_SESION'; end if;
 return coalesce((select jsonb_agg(x order by x->>'created_at' desc) from (
  select jsonb_build_object('id',q.id,'group_id',q.group_id,'group_name',g.name,'ref_type',q.ref_type,'ref_id',q.ref_id,
    'needs',q.needs,'status',q.status,'expires_at',q.expires_at,'created_at',q.created_at,
    'mine',q.requested_by=auth.uid(),
    'i_can_approve',appr.ok,
    'version_hash',case when appr.ok then q.version_hash end) x
  from core.link_requests q join cuentas.groups g on g.id=q.group_id
  cross join lateral (select exists(select 1 from core.link_approvers(q.group_id,q.ref_type,q.ref_id,q.needs) a where a=auth.uid()) ok) appr
  where q.status='pending' and q.expires_at>now() and (p_group is null or q.group_id=p_group)
    and (q.requested_by=auth.uid() or appr.ok)) t),'[]'::jsonb);
end $f$;

create or replace function public.core_link_requests_history(p_group uuid default null, p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare v_days int:=least(greatest(coalesce(p_days,30),1),90);
begin
 if auth.uid() is null then raise exception 'Iniciá sesión' using detail='LNK_SIN_SESION'; end if;
 return coalesce((select jsonb_agg(x order by x->>'created_at' desc) from (
  select jsonb_build_object('id',q.id,'group_id',q.group_id,'group_name',g.name,'ref_type',q.ref_type,'ref_id',q.ref_id,
    'needs',q.needs,'status',case when q.status='pending' then 'expired' else q.status end,
    'expires_at',q.expires_at,'created_at',q.created_at,'decided_at',q.decided_at,
    'mine',q.requested_by=auth.uid(),'i_can_approve',appr.ok) x
  from core.link_requests q join cuentas.groups g on g.id=q.group_id
  cross join lateral (select exists(select 1 from core.link_approvers(q.group_id,q.ref_type,q.ref_id,q.needs) a where a=auth.uid()) ok) appr
  where (q.status<>'pending' or q.expires_at<=now())
    and q.created_at>now()-make_interval(days=>v_days)
    and (p_group is null or q.group_id=p_group)
    and (q.requested_by=auth.uid() or appr.ok)
  order by q.created_at desc limit 100) t),'[]'::jsonb);
end $f$;
