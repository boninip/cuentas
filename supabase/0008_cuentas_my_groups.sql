-- 0008 · Cuentas: listar mis grupos (solo lectura). DEV.
create function public.cuentas_my_groups() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'reference_currency',g.reference_currency,'status',g.status,'role',m.role) order by g.created_at desc)
   from cuentas.members m join cuentas.groups g on g.id=m.group_id
   where m.user_id=auth.uid() and m.status='active'),'[]'::jsonb);
end $$;
revoke all on function public.cuentas_my_groups() from public, anon;
grant execute on function public.cuentas_my_groups() to authenticated;
