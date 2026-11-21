-- 0055 · Cuentas: cotización automática (ítem 20 de la etapa 4b). Diseño: Pinto_Cuentas_4b_monedas_y_OCR_diseno_GF14_PROPUESTA.md
-- Aprobado por Pau: Q2b (16/11), cotización elegible por grupo con oficial por defecto y consulta desde el celular (21/11).
-- Cambios aditivos: columnas fx_source/fx_at en el libro, fx_rate_type por grupo, interruptor y umbral en cuentas.config,
-- parámetros opcionales nuevos en cuentas_expense_add (la firma vieja se reemplaza; los clientes con argumentos por nombre siguen igual).
-- Reversa: 0055_REVERSA.sql
alter table cuentas.movements add column if not exists fx_source text, add column if not exists fx_at timestamptz;
alter table cuentas.groups add column if not exists fx_rate_type text not null default 'oficial';
do $m$ begin
 if not exists(select 1 from pg_constraint where conrelid='cuentas.groups'::regclass and conname='groups_fx_rate_type_check') then
  alter table cuentas.groups add constraint groups_fx_rate_type_check check (fx_rate_type in ('oficial','mep','blue')); end if;
 alter table cuentas.config drop constraint if exists config_int_value_check;
 alter table cuentas.config add constraint config_int_value_check check (int_value >= 0);
end $m$;
insert into cuentas.config(key,int_value) values ('fx_auto',1),('fx_warn_pct',10) on conflict (key) do nothing;

do $mig$
declare v_def text; v_new text;
begin
 v_def:=pg_get_functiondef('public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric)'::regprocedure);
 v_new:=replace(v_def,'p_fx numeric DEFAULT NULL::numeric)','p_fx numeric DEFAULT NULL::numeric, p_fx_source text DEFAULT NULL::text, p_fx_at timestamp with time zone DEFAULT NULL::timestamp with time zone)');
 v_new:=replace(v_new,'created_by,idempotency_key,category,fx_rate)','created_by,idempotency_key,category,fx_rate,fx_source,fx_at)');
 v_new:=replace(v_new,'case when p_currency=v_ref then null else p_fx end) returning id into v_id;','case when p_currency=v_ref then null else p_fx end,case when p_currency=v_ref or p_fx is null then null else left(p_fx_source,60) end,case when p_currency=v_ref or p_fx is null then null else p_fx_at end) returning id into v_id;');
 if v_new=v_def or position('fx_source,fx_at' in v_new)=0 or position('left(p_fx_source,60)' in v_new)=0 or position('p_fx_source text' in v_new)=0 then raise exception 'Anclas de cuentas_expense_add no encontradas'; end if;
 execute v_new;
 drop function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric);
 -- cuentas_group_get: suma el tipo de cotización, el interruptor y el umbral
 v_def:=pg_get_functiondef('public.cuentas_group_get(uuid)'::regprocedure);
 v_new:=replace(v_def,'''status'',g.status,','''status'',g.status,''fx_rate_type'',g.fx_rate_type,''fx_auto'',(cuentas.cfg_int(''fx_auto'',1)=1),''fx_warn_pct'',cuentas.cfg_int(''fx_warn_pct'',10),');
 if v_new=v_def then raise exception 'Ancla de cuentas_group_get no encontrada'; end if;
 execute v_new;
end $mig$;

create or replace function public.cuentas_group_set_fx_type(p_group uuid, p_type text)
returns void language plpgsql security definer set search_path to '' as $f$
declare v_user uuid:=auth.uid(); v_status text;
begin
 if v_user is null then raise exception 'Iniciá sesión' using detail='CUE_SIN_SESION'; end if;
 select status into v_status from cuentas.groups where id=p_group;
 if not found or not cuentas.can(p_group,v_user,'__admin__') then raise exception 'No autorizado' using detail='CUE_NO_AUTORIZADO'; end if;
 if v_status='archived' then raise exception 'El grupo está archivado' using detail='CUE_GRUPO_ARCHIVADO'; end if;
 if p_type not in ('oficial','mep','blue') then raise exception 'Tipo de cotización inválido' using detail='CUE_COTIZACION_TIPO_INVALIDO'; end if;
 update cuentas.groups set fx_rate_type=p_type where id=p_group;
 perform cuentas.log(p_group,v_user,'fx_type_set',jsonb_build_object('type',p_type));
end $f$;
revoke all on function public.cuentas_group_set_fx_type(uuid,text) from public, anon;
grant execute on function public.cuentas_group_set_fx_type(uuid,text) to authenticated;
