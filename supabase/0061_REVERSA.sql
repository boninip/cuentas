-- Reversa de 0061 (SIN PROBAR: contiene DROPs). Restaura balances_raw original.
drop function if exists public.cuentas_movements_page(uuid,int,bigint);
drop index if exists cuentas.movements_group_seq_idx;
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
  union all select k.to_user, k.cur, -k.amount_minor from k)
 select cuentas.eff_pay(p_group,l.u), l.cur, sum(l.a)::bigint from l group by cuentas.eff_pay(p_group,l.u), l.cur $$;
