-- 0021 Cuentas: «Te están esperando». Lista, por grupo, lo que la persona tiene que resolver: pagos por confirmar,
-- propuestas por decidir y solicitudes de cuenta compartida. Solo lectura, sin tablas nuevas, sin avisos por mail/push. PROPUESTA, solo DEV.
create function public.cuentas_my_pending() returns jsonb
language plpgsql stable security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 return coalesce((select jsonb_agg(x order by x->>'name') from (
  select jsonb_build_object('group_id',g.id,'name',g.name,
   'payments',(select count(*) from cuentas.movements m where m.group_id=g.id and m.kind='payment' and m.to_user=auth.uid()
      and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind in ('void','payment_reversal'))
      and not exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')),
   'proposals',(select count(*) from cuentas.proposals p join cuentas.proposal_required r on r.proposal_id=p.id and r.user_id=auth.uid()
      where p.group_id=g.id and p.status='open' and not exists(select 1 from cuentas.consents c where c.proposal_id=p.id and c.user_id=auth.uid())),
   'pairs',(select count(*) from cuentas.shared_accounts s where s.group_id=g.id and s.status='pending' and s.requested_by<>auth.uid() and auth.uid() in (s.member_a,s.member_b))) x
  from cuentas.groups g join cuentas.members mb on mb.group_id=g.id and mb.user_id=auth.uid() and mb.status='active'
  where g.status<>'archived') q
  where (x->>'payments')::int+(x->>'proposals')::int+(x->>'pairs')::int>0),'[]'::jsonb);
end $$;
revoke all on function public.cuentas_my_pending() from public, anon;
grant execute on function public.cuentas_my_pending() to authenticated;
