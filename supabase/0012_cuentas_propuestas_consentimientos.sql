-- 0012 · Cuentas (DEV): propuestas con consentimiento explícito y versionado (anular un gasto con pagos confirmados; revertir un pago).
-- Leer un aviso no es consentir: el consentimiento es una acción en el servidor ligada al hash exacto de la propuesta.
-- Opciones RECOMENDADAS (pendientes de aprobación de Pau).

-- 1) Nuevo tipo de movimiento: reversión de pago (contramovimiento, referencia al pago).
do $m$
declare c record;
begin
 for c in select conname from pg_constraint where conrelid='cuentas.movements'::regclass and contype='c' loop
  execute format('alter table cuentas.movements drop constraint %I',c.conname);
 end loop;
end $m$;
alter table cuentas.movements add constraint movements_kind_check check (kind in ('expense','payment','payment_confirmation','void','payment_reversal'));
alter table cuentas.movements add constraint movements_amount_check check (amount_minor>0);
alter table cuentas.movements add constraint movements_currency_check check (currency ~ '^[A-Z]{3}$');
alter table cuentas.movements add constraint movements_description_check check (length(description)<=300);
alter table cuentas.movements add constraint movements_shape_check check (
  (kind='expense' and from_user is not null and to_user is null and ref_id is null)
  or (kind='payment' and from_user is not null and to_user is not null and from_user<>to_user and ref_id is null)
  or (kind in ('payment_confirmation','void','payment_reversal') and ref_id is not null));

-- 2) Los saldos no cuentan pagos revertidos; cuentas_balances pasa a usar la misma consulta interna.
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

create or replace function public.cuentas_balances(p_group uuid) returns table(user_id uuid, currency text, balance_minor bigint)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return query select b.user_id, b.currency, b.balance_minor from cuentas.balances_raw(p_group) b order by b.currency, b.user_id;
end $$;

-- 3) Listado de movimientos: marca los pagos revertidos.
do $m$
declare d text; a text:=$a$'confirmed',exists($a$;
begin
 d:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 if position(a in d)=0 then raise exception 'patrón list'; end if;
 execute replace(d,a,$b$'reversed',exists(select 1 from cuentas.movements v2 where v2.ref_id=m.id and v2.kind='payment_reversal'),'confirmed',exists($b$);
 -- confirmar un pago ya revertido/cancelado no corresponde
 d:=pg_get_functiondef('public.cuentas_payment_confirm(uuid)'::regprocedure);
 a:=$a$ select id into v_id from cuentas.movements where ref_id=p.id and kind='payment_confirmation';$a$;
 if position(a in d)=0 then raise exception 'patrón confirm'; end if;
 execute replace(d,a,$b$ if exists(select 1 from cuentas.movements where ref_id=p.id and kind='payment_reversal') then raise exception 'El pago fue anulado'; end if;
$b$||a);
end $m$;

-- 4) Propuestas y consentimientos.
create table cuentas.proposals(
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references cuentas.groups(id),
 kind text not null check (kind in ('void_expense','reverse_payment')),
 target_id uuid not null references cuentas.movements(id),
 version_hash text not null,
 reason text check (length(reason)<=300),
 status text not null default 'open' check (status in ('open','approved','rejected','invalidated','cancelled')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 resolved_at timestamptz
);
create unique index proposals_one_open on cuentas.proposals(kind,target_id) where status='open';
create table cuentas.proposal_required(
 proposal_id uuid not null references cuentas.proposals(id),
 user_id uuid not null references auth.users(id),
 primary key(proposal_id,user_id)
);
create table cuentas.consents(
 id uuid primary key default gen_random_uuid(),
 proposal_id uuid not null references cuentas.proposals(id),
 version_hash text not null,
 user_id uuid not null references auth.users(id),
 decision text not null check (decision in ('approve','reject')),
 created_at timestamptz not null default now(),
 unique(proposal_id,user_id)
);
create trigger consents_append_only before update or delete on cuentas.consents for each row execute function cuentas.deny_change();
create trigger consents_no_truncate before truncate on cuentas.consents for each statement execute function cuentas.deny_change();
create trigger required_append_only before update or delete on cuentas.proposal_required for each row execute function cuentas.deny_change();
create trigger required_no_truncate before truncate on cuentas.proposal_required for each statement execute function cuentas.deny_change();
alter table cuentas.proposals enable row level security;
alter table cuentas.proposal_required enable row level security;
alter table cuentas.consents enable row level security;
revoke all on cuentas.proposals, cuentas.proposal_required, cuentas.consents from public, anon, authenticated;

-- Aplica el efecto de una propuesta aprobada (interno).
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

create function public.cuentas_proposal_create(p_kind text, p_target uuid, p_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); t cuentas.movements%rowtype; v_id uuid; v_req uuid[]; v_hash text; v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_kind not in ('void_expense','reverse_payment') then raise exception 'Tipo de propuesta inválido'; end if;
 select * into t from cuentas.movements where id=p_target;
 if not found or not cuentas.is_active_member(t.group_id,v_user) then raise exception 'No autorizado'; end if;
 select status into v_status from cuentas.groups where id=t.group_id;
 if v_status='archived' then raise exception 'El grupo está archivado'; end if;
 if coalesce(length(p_reason),0)>300 then raise exception 'Motivo demasiado largo'; end if;
 if p_kind='void_expense' then
  if t.kind<>'expense' then raise exception 'El movimiento no es un gasto'; end if;
  if exists(select 1 from cuentas.movements where ref_id=t.id and kind='void') then raise exception 'El gasto ya está anulado'; end if;
  if t.created_by<>v_user and not cuentas.can(t.group_id,v_user,'void') then raise exception 'Solo el autor o quien administra puede pedir la anulación'; end if;
  select array_agg(distinct u order by u) into v_req from (select t.from_user as u union select s.user_id from cuentas.movement_shares s where s.movement_id=t.id) x;
 else
  if t.kind<>'payment' then raise exception 'El movimiento no es un pago'; end if;
  if not exists(select 1 from cuentas.movements where ref_id=t.id and kind='payment_confirmation') then raise exception 'El pago no está confirmado: el que pagó puede cancelarlo'; end if;
  if exists(select 1 from cuentas.movements where ref_id=t.id and kind='payment_reversal') then raise exception 'El pago ya fue revertido'; end if;
  if v_user not in (t.from_user,t.to_user) then raise exception 'Solo quien pagó o quien cobró puede pedir la reversión'; end if;
  v_req:=array[least(t.from_user,t.to_user),greatest(t.from_user,t.to_user)];
 end if;
 v_hash:=encode(extensions.digest(p_kind||'|'||t.id::text||'|'||array_to_string(v_req,',')||'|'||t.amount_minor::text||t.currency||'|'||coalesce(p_reason,''),'sha256'),'hex');
 insert into cuentas.proposals(group_id,kind,target_id,version_hash,reason,created_by) values(t.group_id,p_kind,t.id,v_hash,nullif(trim(coalesce(p_reason,'')),''),v_user) returning id into v_id;
 insert into cuentas.proposal_required(proposal_id,user_id) select v_id,unnest(v_req);
 perform cuentas.log(t.group_id,v_user,'proposal_created',jsonb_build_object('proposal',v_id,'kind',p_kind,'target',t.id));
 return v_id;
end $$;

-- Consentimiento: acción explícita de cada afectado, validada en el servidor y ligada al hash exacto.
create function public.cuentas_proposal_consent(p_proposal uuid, p_hash text, p_decision text) returns text
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); pr cuentas.proposals%rowtype; n_req int; n_ok int;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_decision not in ('approve','reject') then raise exception 'Decisión inválida'; end if;
 select * into pr from cuentas.proposals where id=p_proposal for update;
 if not found or not cuentas.is_active_member(pr.group_id,v_user) then raise exception 'No autorizado'; end if;
 if not exists(select 1 from cuentas.proposal_required where proposal_id=p_proposal and user_id=v_user) then raise exception 'No sos parte afectada por esta propuesta'; end if;
 if pr.status<>'open' then raise exception 'La propuesta ya no está abierta (%)',pr.status; end if;
 if p_hash is distinct from pr.version_hash then raise exception 'La propuesta cambió: revisá la versión actual'; end if;
 if exists(select 1 from cuentas.consents where proposal_id=p_proposal and user_id=v_user) then raise exception 'Ya respondiste esta propuesta'; end if;
 insert into cuentas.consents(proposal_id,version_hash,user_id,decision) values(p_proposal,p_hash,v_user,p_decision);
 perform cuentas.log(pr.group_id,v_user,'consent_'||p_decision,jsonb_build_object('proposal',p_proposal));
 if p_decision='reject' then
  update cuentas.proposals set status='rejected', resolved_at=now() where id=p_proposal; return 'rejected';
 end if;
 select count(*) into n_req from cuentas.proposal_required where proposal_id=p_proposal;
 select count(*) into n_ok from cuentas.consents c where c.proposal_id=p_proposal and c.decision='approve' and c.version_hash=pr.version_hash;
 if n_ok>=n_req then perform cuentas.apply_proposal(p_proposal); return 'approved'; end if;
 return 'open';
end $$;

create function public.cuentas_proposal_cancel(p_proposal uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); pr cuentas.proposals%rowtype;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into pr from cuentas.proposals where id=p_proposal for update;
 if not found or pr.created_by<>v_user then raise exception 'No autorizado'; end if;
 if pr.status<>'open' then raise exception 'La propuesta ya no está abierta'; end if;
 update cuentas.proposals set status='cancelled', resolved_at=now() where id=p_proposal;
 perform cuentas.log(pr.group_id,v_user,'proposal_cancelled',jsonb_build_object('proposal',p_proposal));
end $$;

create function public.cuentas_proposals_list(p_group uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'kind',p.kind,'target_id',p.target_id,'status',p.status,'version_hash',p.version_hash,'reason',p.reason,
   'created_by',p.created_by,'created_at',p.created_at,'amount_minor',t.amount_minor,'currency',t.currency,'description',t.description,
   'required',(select jsonb_agg(jsonb_build_object('user_id',r.user_id,'decision',(select c.decision from cuentas.consents c where c.proposal_id=p.id and c.user_id=r.user_id)) order by r.user_id)
               from cuentas.proposal_required r where r.proposal_id=p.id)) order by p.created_at desc)
   from cuentas.proposals p join cuentas.movements t on t.id=p.target_id where p.group_id=p_group),'[]'::jsonb);
end $$;

-- Cancelar un pago todavía no confirmado: lo hace quien lo registró (sin consentimiento, no afectó saldos).
create function public.cuentas_payment_cancel(p_payment uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); p cuentas.movements%rowtype; v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into p from cuentas.movements where id=p_payment and kind='payment';
 if not found or p.from_user<>v_user then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where ref_id=p.id and kind='payment_reversal';
 if found then return v_id; end if;
 if exists(select 1 from cuentas.movements where ref_id=p.id and kind='payment_confirmation') then raise exception 'El pago ya fue confirmado: pedí una reversión'; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,ref_id,created_by,idempotency_key)
 values(p.group_id,'payment_reversal',p.currency,p.amount_minor,p.from_user,p.to_user,p.id,v_user,'reverse:'||p.id) returning id into v_id;
 perform cuentas.log(p.group_id,v_user,'payment_cancelled',jsonb_build_object('payment',p.id));
 return v_id;
end $$;

-- Anular un gasto con pagos confirmados ya no se bloquea sin más: pasa por propuesta.
do $m$
declare d text; a text:=$a$anular requiere la aprobación de los afectados (todavía no implementado)$a$;
begin
 d:=pg_get_functiondef('public.cuentas_expense_void(uuid,text)'::regprocedure);
 if position(a in d)=0 then raise exception 'patrón void'; end if;
 execute replace(d,a,$b$para anular hay que crear una propuesta que aprueben todos los afectados$b$);
end $m$;

-- Una baja o salida invalida las propuestas abiertas donde la persona era parte afectada.
do $m$
declare d text; a1 text:=$a$ update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=v_user;$a$; a2 text:=$a$ update cuentas.members set status='former', left_at=now() where group_id=p_group and user_id=p_user;$a$;
begin
 d:=pg_get_functiondef('public.cuentas_member_leave(uuid)'::regprocedure);
 if position(a1 in d)=0 then raise exception 'patrón leave'; end if;
 execute replace(d,a1,$b$ update cuentas.proposals set status='invalidated', resolved_at=now() where group_id=p_group and status='open' and id in (select proposal_id from cuentas.proposal_required where user_id=v_user);
$b$||a1);
 d:=pg_get_functiondef('public.cuentas_member_remove(uuid,uuid)'::regprocedure);
 if position(a2 in d)=0 then raise exception 'patrón remove'; end if;
 execute replace(d,a2,$b$ update cuentas.proposals set status='invalidated', resolved_at=now() where group_id=p_group and status='open' and id in (select proposal_id from cuentas.proposal_required where user_id=p_user);
$b$||a2);
end $m$;

revoke all on function public.cuentas_proposal_create(text,uuid,text), public.cuentas_proposal_consent(uuid,text,text), public.cuentas_proposal_cancel(uuid), public.cuentas_proposals_list(uuid), public.cuentas_payment_cancel(uuid) from public, anon;
grant execute on function public.cuentas_proposal_create(text,uuid,text), public.cuentas_proposal_consent(uuid,text,text), public.cuentas_proposal_cancel(uuid), public.cuentas_proposals_list(uuid), public.cuentas_payment_cancel(uuid) to authenticated;
