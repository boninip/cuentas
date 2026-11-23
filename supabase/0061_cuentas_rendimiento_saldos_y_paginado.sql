-- 0061 · Cuentas · rendimiento (P1 + P2 de la revisión del 22/11/2026)
-- PROPUESTA aplicada en DEV con autorización de Pau. No ir a producción sin su OK.
-- P2: balances_raw agrega por (usuario, moneda) ANTES de resolver eff_pay (antes se llamaba por fila).
--     Resultado idéntico (0 diferencias medidas con invitados, tutores, anulaciones y reversiones); 3861 ms -> 32 ms con 8.4k movimientos.
-- P1: nueva RPC cuentas_movements_page (paginado por seq; orden por seq, estable aunque haya created_at iguales). cuentas_movements_list queda igual (compatibilidad).

create or replace function cuentas.balances_raw(p_group uuid)
 returns table(user_id uuid, currency text, balance_minor bigint)
 language sql stable security definer set search_path to '' as $$
 with e as (select m.id,m.currency as cur,m.amount_minor,m.from_user from cuentas.movements m
   where m.group_id=p_group and m.kind='expense' and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void')),
 p as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='payment' and exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')
     and not exists(select 1 from cuentas.movements x where x.ref_id=m.id and x.kind='payment_reversal')),
 k as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='compensation'
     and not exists(select 1 from cuentas.movements x where x.ref_id=m.id and x.kind='compensation_reversal')),
 l as (
  select e.from_user as u, e.cur, e.amount_minor as a from e
  union all select s.user_id, e.cur, -s.share_minor from cuentas.movement_shares s join e on e.id=s.movement_id
  union all select p.from_user, p.cur, p.amount_minor from p
  union all select p.to_user, p.cur, -p.amount_minor from p
  union all select k.from_user, k.cur, k.amount_minor from k
  union all select k.to_user, k.cur, -k.amount_minor from k),
 pre as (select l.u, l.cur, sum(l.a) as a from l group by l.u, l.cur)
 select cuentas.eff_pay(p_group,pre.u), pre.cur, sum(pre.a)::bigint from pre group by 1, 2 $$;

create index if not exists movements_group_seq_idx on cuentas.movements (group_id, seq desc);

create or replace function public.cuentas_movements_page(p_group uuid, p_limit int default 100, p_before bigint default null)
 returns jsonb language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 if p_limit is null or p_limit<1 or p_limit>1000 then raise exception 'Límite inválido' using detail='CUE_LIMITE_INVALIDO'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',m.id,'seq',m.seq,'kind',m.kind,'currency',m.currency,'amount_minor',m.amount_minor,'from_user',cuentas.eff(p_group,m.from_user),'to_user',cuentas.eff(p_group,m.to_user),
   'description',m.description,'occurred_on',m.occurred_on,'ref_id',m.ref_id,'created_by',m.created_by,'created_at',m.created_at,
   'category',m.category,'fx_rate',m.fx_rate,'fx_source',m.fx_source,'notes',m.notes,'fx_at',m.fx_at,'paid_currency',m.paid_currency,'paid_amount_minor',m.paid_amount_minor,
   'voided',exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void'),
   'reversed',exists(select 1 from cuentas.movements v2 where v2.ref_id=m.id and v2.kind in ('payment_reversal','compensation_reversal')),'confirmed',exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation'),
   'shares',(select coalesce(jsonb_object_agg(x.u,x.s),'{}'::jsonb) from (select cuentas.eff(p_group,s.user_id) u, sum(s.share_minor) s from cuentas.movement_shares s where s.movement_id=m.id group by 1) x)
  ) order by m.seq)
  from (select * from cuentas.movements w where w.group_id=p_group and (p_before is null or w.seq<p_before) order by w.seq desc limit p_limit) m),'[]'::jsonb);
end $$;
revoke all on function public.cuentas_movements_page(uuid,int,bigint) from public, anon;
grant execute on function public.cuentas_movements_page(uuid,int,bigint) to authenticated;
