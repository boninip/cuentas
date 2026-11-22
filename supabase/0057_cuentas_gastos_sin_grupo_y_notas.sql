-- 0057 · Cuentas: "Gastos sin grupo" (un grupo personal por persona), notas en los gastos y permisos de cuentas_expense_add.
-- Aprobado por Pau (21/11, respuestas por opciones): un solo grupo "Gastos sin grupo" por persona; botones de fecha con repetición, foto y notas; "Elegir grupo" desde el inicio.
-- Cambios: groups.kind ('normal'|'personal', uno personal por persona); movements.notes (hasta 1000); cuentas_personal_group();
-- cuentas_expense_add y cuentas_expense_edit con p_notes (firmas viejas reemplazadas); movements_list y my_groups_all devuelven notes y kind;
-- el grupo personal no se puede eliminar. También corrige un olvido de 0055: la firma nueva de cuentas_expense_add había quedado sin los permisos
-- (solo authenticated). Reversa: 0057_REVERSA.sql
alter table cuentas.groups add column if not exists kind text not null default 'normal';
alter table cuentas.movements add column if not exists notes text;
do $m$ begin
 if not exists(select 1 from pg_constraint where conrelid='cuentas.groups'::regclass and conname='groups_kind_check') then
  alter table cuentas.groups add constraint groups_kind_check check (kind in ('normal','personal')); end if;
 if not exists(select 1 from pg_constraint where conrelid='cuentas.movements'::regclass and conname='movements_notes_check') then
  alter table cuentas.movements add constraint movements_notes_check check (notes is null or length(notes) between 1 and 1000); end if;
end $m$;
create unique index if not exists groups_one_personal on cuentas.groups(created_by) where kind='personal';

create or replace function public.cuentas_personal_group() returns uuid language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 select g.id into v_id from cuentas.groups g where g.created_by=v_user and g.kind='personal';
 if found then return v_id; end if;
 insert into cuentas.groups(name,reference_currency,created_by,kind) values('Gastos sin grupo','ARS',v_user,'personal') returning id into v_id;
 insert into cuentas.members(group_id,user_id,role) values(v_id,v_user,'admin');
 perform cuentas.log(v_id,v_user,'group_created',jsonb_build_object('name','Gastos sin grupo','personal',true));
 return v_id;
end $f$;
revoke all on function public.cuentas_personal_group() from public, anon;
grant execute on function public.cuentas_personal_group() to authenticated;

do $mig$
declare v_def text; v_new text;
begin
 -- cuentas_expense_add: p_notes
 v_def:=pg_get_functiondef('public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz)'::regprocedure);
 v_new:=replace(v_def,'p_fx_at timestamp with time zone DEFAULT NULL::timestamp with time zone)','p_fx_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_notes text DEFAULT NULL::text)');
 v_new:=replace(v_new,'category,fx_rate,fx_source,fx_at)','category,fx_rate,fx_source,fx_at,notes)');
 v_new:=replace(v_new,'else p_fx_at end) returning id into v_id;','else p_fx_at end,nullif(left(trim(coalesce(p_notes,'''')),1000),'''')) returning id into v_id;');
 if position('p_notes text' in v_new)=0 or position('fx_at,notes)' in v_new)=0 or position('left(trim(coalesce(p_notes' in v_new)=0 then raise exception 'Anclas de cuentas_expense_add no encontradas'; end if;
 execute v_new;
 drop function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz);
 revoke all on function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz,text) from public, anon;
 grant execute on function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz,text) to authenticated;
 -- cuentas_expense_edit: p_notes
 v_def:=pg_get_functiondef('public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric)'::regprocedure);
 v_new:=replace(v_def,'p_fx numeric DEFAULT NULL::numeric)','p_fx numeric DEFAULT NULL::numeric, p_notes text DEFAULT NULL::text)');
 v_new:=replace(v_new,'p_category,p_fx);','p_category,p_fx,p_notes=>p_notes);');
 if position('p_notes text' in v_new)=0 or position('p_notes=>p_notes' in v_new)=0 then raise exception 'Anclas de cuentas_expense_edit no encontradas'; end if;
 execute v_new;
 drop function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric);
 revoke all on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text) from public, anon;
 grant execute on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text) to authenticated;
 -- lista de movimientos y de grupos
 v_def:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 v_new:=replace(v_def,'''fx_source'',m.fx_source,','''fx_source'',m.fx_source,''notes'',m.notes,');
 if v_new=v_def then raise exception 'Ancla de cuentas_movements_list no encontrada'; end if;
 execute v_new;
 v_def:=pg_get_functiondef('public.cuentas_my_groups_all()'::regprocedure);
 v_new:=replace(v_def,'''status'',g.status,''role'',m.role,','''status'',g.status,''kind'',g.kind,''role'',m.role,');
 if v_new=v_def then raise exception 'Ancla de cuentas_my_groups_all no encontrada'; end if;
 execute v_new;
 -- el grupo personal no se elimina
 v_def:=pg_get_functiondef('public.cuentas_group_delete(uuid)'::regprocedure);
 v_new:=replace(v_def,'raise exception ''El grupo está archivado'' using detail=''CUE_GRUPO_ARCHIVADO''; end if;','raise exception ''El grupo está archivado'' using detail=''CUE_GRUPO_ARCHIVADO''; end if;
 if g.kind=''personal'' then raise exception ''Este grupo no se puede eliminar'' using detail=''CUE_GRUPO_PERSONAL''; end if;');
 if v_new=v_def then raise exception 'Ancla de cuentas_group_delete no encontrada'; end if;
 execute v_new;
end $mig$;
