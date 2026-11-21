-- Reversa de 0055: vuelve a la firma anterior de cuentas_expense_add y quita lo agregado.
-- Las columnas fx_source/fx_at y fx_rate_type se eliminan (se pierde solo esa información; fx_rate queda).
do $mig$
declare v_def text; v_new text;
begin
 v_def:=pg_get_functiondef('public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamp with time zone)'::regprocedure);
 v_new:=replace(v_def,', p_fx_source text DEFAULT NULL::text, p_fx_at timestamp with time zone DEFAULT NULL::timestamp with time zone)',')');
 v_new:=replace(v_new,'category,fx_rate,fx_source,fx_at)','category,fx_rate)');
 v_new:=replace(v_new,',case when p_currency=v_ref or p_fx is null then null else left(p_fx_source,60) end,case when p_currency=v_ref or p_fx is null then null else p_fx_at end) returning id into v_id;',') returning id into v_id;');
 if v_new=v_def then raise exception 'Anclas no encontradas'; end if;
 execute v_new;
 drop function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamp with time zone);
 v_def:=pg_get_functiondef('public.cuentas_group_get(uuid)'::regprocedure);
 v_new:=replace(v_def,'''fx_rate_type'',g.fx_rate_type,''fx_auto'',(cuentas.cfg_int(''fx_auto'',1)=1),''fx_warn_pct'',cuentas.cfg_int(''fx_warn_pct'',10),','');
 execute v_new;
end $mig$;
drop function if exists public.cuentas_group_set_fx_type(uuid,text);
delete from cuentas.config where key in ('fx_auto','fx_warn_pct');
alter table cuentas.groups drop constraint if exists groups_fx_rate_type_check, drop column if exists fx_rate_type;
alter table cuentas.movements drop column if exists fx_source, drop column if exists fx_at;
alter table cuentas.config drop constraint if exists config_int_value_check;
alter table cuentas.config add constraint config_int_value_check check (int_value > 0);
