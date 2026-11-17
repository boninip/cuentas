-- 0015b: a quién puede pagarle un ex miembro con deuda (solo quienes tienen saldo a favor; sin mostrar importes)
create function public.cuentas_exmember_payees(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_st text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select status into v_st from cuentas.members where group_id=p_group and user_id=v_user;
 if v_st is distinct from 'former' then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.balances_raw(p_group) b where b.user_id=v_user and b.balance_minor<0) then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'display_name',p.display_name,'alias',case when i.shared then i.alias end,'cbu',case when i.shared then i.cbu end))
   from cuentas.members m
   join (select distinct b.user_id from cuentas.balances_raw(p_group) b where b.balance_minor>0) cr on cr.user_id=m.user_id
   left join core.planazo_profiles p on p.user_id=m.user_id
   left join cuentas.payout_info i on i.user_id=m.user_id
   where m.group_id=p_group and m.status='active'),'[]'::jsonb);
end $$;
revoke all on function public.cuentas_exmember_payees(uuid) from public, anon;
grant execute on function public.cuentas_exmember_payees(uuid) to authenticated;
