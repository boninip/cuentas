-- Reversa 0012 (DEV). Revisión estática: NO ejecutada. Pierde propuestas y consentimientos y los movimientos de tipo payment_reversal deben eliminarse antes (el libro es de solo altas: hace falta deshabilitar el disparador como dueño).
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_member_leave(uuid)'::regprocedure);
 d:=regexp_replace(d,E' update cuentas.proposals set status=''invalidated''[^\\n]*\\n','');
 execute d;
 d:=pg_get_functiondef('public.cuentas_member_remove(uuid,uuid)'::regprocedure);
 d:=regexp_replace(d,E' update cuentas.proposals set status=''invalidated''[^\\n]*\\n','');
 execute d;
 d:=pg_get_functiondef('public.cuentas_expense_void(uuid,text)'::regprocedure);
 execute replace(d,'para anular hay que crear una propuesta que aprueben todos los afectados','anular requiere la aprobación de los afectados (todavía no implementado)');
 d:=pg_get_functiondef('public.cuentas_payment_confirm(uuid)'::regprocedure);
 d:=regexp_replace(d,E' if exists\\(select 1 from cuentas.movements where ref_id=p.id and kind=''payment_reversal''\\) then raise exception ''El pago fue anulado''; end if;\\n','');
 execute d;
 d:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 d:=replace(d,$a$'reversed',exists(select 1 from cuentas.movements v2 where v2.ref_id=m.id and v2.kind='payment_reversal'),$a$,'');
 execute d;
end $m$;
drop function if exists public.cuentas_payment_cancel(uuid);
drop function if exists public.cuentas_proposals_list(uuid);
drop function if exists public.cuentas_proposal_cancel(uuid);
drop function if exists public.cuentas_proposal_consent(uuid,text,text);
drop function if exists public.cuentas_proposal_create(text,uuid,text);
drop function if exists cuentas.apply_proposal(uuid);
drop table if exists cuentas.consents;
drop table if exists cuentas.proposal_required;
drop table if exists cuentas.proposals;
create or replace function cuentas.balances_raw(p_group uuid) returns table(user_id uuid, currency text, balance_minor bigint)
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
-- Las restricciones de movements (kind/shape) se mantienen: aceptan un tipo más y no rompen nada.
