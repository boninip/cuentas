-- 0026 PROPUESTA (no aprobada): lista de actividad del grupo, solo lectura sobre cuentas.audit_log.
-- Solo miembros activos del grupo. No expone el detalle crudo: devuelve campos acotados.
create or replace function public.cuentas_activity_list(p_group uuid, p_limit int default 40)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if not exists(select 1 from cuentas.members m where m.group_id=p_group and m.user_id=auth.uid() and m.status='active') then
  raise exception 'No sos miembro de este grupo'; end if;
 return coalesce((select jsonb_agg(x order by (x->>'created_at') desc) from (
  select jsonb_build_object('id',a.id,'action',a.action,'actor',cuentas.eff(a.group_id,a.actor_id),'created_at',a.created_at,
   'amount_minor',a.detail->'amount_minor','currency',a.detail->'currency','name',a.detail->'name','weight',a.detail->'weight','target',case when a.detail->>'user' ~ '^[0-9a-f-]{36}$' then cuentas.eff(a.group_id,(a.detail->>'user')::uuid) end,
   'description',(select mv.description from cuentas.movements mv where mv.id=nullif(coalesce(a.detail->>'movement',a.detail->>'new',a.detail->>'expense'),'')::uuid)) x
  from cuentas.audit_log a where a.group_id=p_group order by a.created_at desc, a.id desc limit least(greatest(coalesce(p_limit,40),1),100)) q),'[]'::jsonb);
end $$;
revoke all on function public.cuentas_activity_list(uuid,int) from public, anon;
grant execute on function public.cuentas_activity_list(uuid,int) to authenticated;
