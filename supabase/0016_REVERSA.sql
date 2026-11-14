-- REVERSA de 0016 (revisada estáticamente, NO ejecutada). Solo si no hay compensaciones aplicadas que se quieran conservar.
-- 1) salir/quitar: quitar los agregados de 0016
do $m$
declare d text; x text; i int;
begin
 for d in select unnest(array['public.cuentas_member_leave(uuid)','public.cuentas_member_remove(uuid,uuid)']) loop
  x:=pg_get_functiondef(d::regprocedure);
  i:=position(' update cuentas.proposals set status=''invalidated'', resolved_at=now() where status=''open'' and account_id in' in x);
  if i>0 then
   x:=regexp_replace(x,' update cuentas\.proposals set status=''invalidated'', resolved_at=now\(\) where status=''open'' and account_id in \(select id from cuentas\.shared_accounts[^\n]*\n update cuentas\.shared_accounts set status=case[^\n]*\n','','g');
   execute x;
  end if;
 end loop;
end $m$;
drop function if exists public.cuentas_compensation_reverse_propose(uuid,text);
drop function if exists public.cuentas_compensation_propose(uuid,text,bigint,text);
drop function if exists public.cuentas_pairs_list(uuid);
drop function if exists public.cuentas_pair_end(uuid);
drop function if exists public.cuentas_pair_respond(uuid,boolean);
drop function if exists public.cuentas_pair_request(uuid,uuid);
-- 2) consent y apply_proposal como en 0012
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_proposal_consent(uuid,text,text)'::regprocedure);
 execute replace(d,'if n_ok>=n_req then return cuentas.apply_proposal(p_proposal); end if;','if n_ok>=n_req then perform cuentas.apply_proposal(p_proposal); return ''approved''; end if;');
end $m$;
drop function if exists cuentas.apply_proposal(uuid);
create function cuentas.apply_proposal(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare pr cuentas.proposals%rowtype; t cuentas.movements%rowtype;
begin
 select * into pr from cuentas.proposals where id=p_id;
 select * into t from cuentas.movements where id=pr.target_id;
 if pr.kind='void_expense' then
  insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,ref_id,created_by,idempotency_key)
  values(t.group_id,'void',t.currency,t.amount_minor,t.from_user,left(pr.reason,300),t.id,pr.created_by,'void:'||t.id);
 else
  insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,description,ref_id,created_by,idempotency_key)
  values(t.group_id,'payment_reversal',t.currency,t.amount_minor,t.from_user,t.to_user,left(pr.reason,300),t.id,pr.created_by,'reverse:'||t.id);
 end if;
 update cuentas.proposals set status='approved', resolved_at=now() where id=p_id;
 perform cuentas.log(pr.group_id,pr.created_by,'proposal_applied',jsonb_build_object('proposal',p_id,'kind',pr.kind,'target',pr.target_id));
end $$;
revoke all on function cuentas.apply_proposal(uuid) from public, anon, authenticated;
drop function if exists cuentas.comp_has_dependents(uuid);
drop function if exists cuentas.credit_avail(uuid,uuid,text);
drop function if exists cuentas.debt_avail(uuid,uuid,text);
drop function if exists cuentas.bal(uuid,uuid,text);
-- 3) propuestas: volver al esquema de 0012 (requiere que no existan compensaciones)
create or replace function public.cuentas_proposals_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'kind',p.kind,'target_id',p.target_id,'status',p.status,'version_hash',p.version_hash,'reason',p.reason,
   'created_by',p.created_by,'created_at',p.created_at,'amount_minor',t.amount_minor,'currency',t.currency,'description',t.description,
   'required',(select jsonb_agg(jsonb_build_object('user_id',r.user_id,'decision',(select c.decision from cuentas.consents c where c.proposal_id=p.id and c.user_id=r.user_id)) order by r.user_id)
               from cuentas.proposal_required r where r.proposal_id=p.id)) order by p.created_at desc)
   from cuentas.proposals p join cuentas.movements t on t.id=p.target_id where p.group_id=p_group),'[]'::jsonb);
end $$;
drop index if exists cuentas.proposals_one_open_compensation;
alter table cuentas.proposals drop constraint proposals_shape_check, drop constraint proposals_kind_check, drop constraint proposals_status_check, drop constraint proposals_reason_check;
alter table cuentas.proposals drop column account_id, drop column currency, drop column amount_minor, drop column debtor, drop column creditor;
alter table cuentas.proposals alter column target_id set not null;
alter table cuentas.proposals add constraint proposals_kind_check check (kind in ('void_expense','reverse_payment'));
alter table cuentas.proposals add constraint proposals_status_check check (status in ('open','approved','rejected','invalidated','cancelled'));
alter table cuentas.proposals add constraint proposals_reason_check check (length(reason)<=300);
-- 4) cuenta compartida
drop table if exists cuentas.shared_accounts;
drop function if exists cuentas.shared_accounts_guard();
-- 5) saldos y movimientos como en 0012
create or replace function cuentas.balances_raw(p_group uuid) returns table(user_id uuid, currency text, balance_minor bigint)
language sql stable security definer set search_path='' as $$
 with e as (select m.id,m.currency as cur,m.amount_minor,m.from_user from cuentas.movements m
   where m.group_id=p_group and m.kind='expense' and not exists(select 1 from cuentas.movements v where v.ref_id=m.id and v.kind='void')),
 p as (select m.currency as cur,m.amount_minor,m.from_user,m.to_user from cuentas.movements m
   where m.group_id=p_group and m.kind='payment' and exists(select 1 from cuentas.movements c where c.ref_id=m.id and c.kind='payment_confirmation')
     and not exists(select 1 from cuentas.movements x where x.ref_id=m.id and x.kind='payment_reversal')),
 l as (
  select e.from_user as u, e.cur, e.amount_minor as a from e
  union all select s.user_id, e.cur, -s.share_minor from cuentas.movement_shares s join e on e.id=s.movement_id
  union all select p.from_user, p.cur, p.amount_minor from p
  union all select p.to_user, p.cur, -p.amount_minor from p)
 select l.u, l.cur, sum(l.a)::bigint from l group by l.u, l.cur $$;
do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 execute replace(d,$a$v2.kind in ('payment_reversal','compensation_reversal')$a$,$b$v2.kind='payment_reversal'$b$);
end $m$;
alter table cuentas.movements drop constraint movements_kind_check, drop constraint movements_shape_check;
alter table cuentas.movements add constraint movements_kind_check check (kind in ('expense','payment','payment_confirmation','void','payment_reversal'));
alter table cuentas.movements add constraint movements_shape_check check (
  (kind='expense' and from_user is not null and to_user is null and ref_id is null)
  or (kind='payment' and from_user is not null and to_user is not null and from_user<>to_user and ref_id is null)
  or (kind in ('payment_confirmation','void','payment_reversal') and ref_id is not null));
alter table cuentas.movements drop column seq;
