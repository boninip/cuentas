-- Reversa de 0057. Se pierden las notas de los gastos y la marca de grupo personal (los grupos "Gastos sin grupo" quedan como grupos comunes).
do $mig$
declare v_def text; v_new text;
begin
 v_def:=pg_get_functiondef('public.cuentas_group_delete(uuid)'::regprocedure);
 v_new:=replace(v_def,'
 if g.kind=''personal'' then raise exception ''Este grupo no se puede eliminar'' using detail=''CUE_GRUPO_PERSONAL''; end if;','');
 execute v_new;
 v_def:=pg_get_functiondef('public.cuentas_my_groups_all()'::regprocedure);
 execute replace(v_def,'''kind'',g.kind,','');
 v_def:=pg_get_functiondef('public.cuentas_movements_list(uuid)'::regprocedure);
 execute replace(v_def,'''notes'',m.notes,','');
 -- expense_edit y expense_add vuelven a sus firmas anteriores
 v_def:=pg_get_functiondef('public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text)'::regprocedure);
 v_new:=replace(v_def,', p_notes text DEFAULT NULL::text)',')');
 v_new:=replace(v_new,'p_category,p_fx,p_notes=>p_notes);','p_category,p_fx);');
 execute v_new;
 drop function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text);
 revoke all on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric) from public, anon;
 grant execute on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric) to authenticated;
 v_def:=pg_get_functiondef('public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz,text)'::regprocedure);
 v_new:=replace(v_def,', p_notes text DEFAULT NULL::text)',')');
 v_new:=replace(v_new,'category,fx_rate,fx_source,fx_at,notes)','category,fx_rate,fx_source,fx_at)');
 v_new:=replace(v_new,'else p_fx_at end,nullif(left(trim(coalesce(p_notes,'''')),1000),'''')) returning id into v_id;','else p_fx_at end) returning id into v_id;');
 execute v_new;
 drop function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz,text);
 revoke all on function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz) from public, anon;
 grant execute on function public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text,text,numeric,text,timestamptz) to authenticated;
end $mig$;
drop function if exists public.cuentas_personal_group();
drop index if exists cuentas.groups_one_personal;
alter table cuentas.movements drop constraint if exists movements_notes_check, drop column if exists notes;
alter table cuentas.groups drop constraint if exists groups_kind_check, drop column if exists kind;
