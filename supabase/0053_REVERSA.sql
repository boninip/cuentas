-- Reversa de 0053: quita el chequeo de propuesta duplicada.
do $mig$
declare v_def text; v_new text;
begin
 v_def:=pg_get_functiondef('public.cuentas_proposal_create(text,uuid,text)'::regprocedure);
 v_new:=regexp_replace(v_def,E' if exists\\(select 1 from cuentas.proposals where kind=p_kind and target_id=t.id and status=''open''\\) then raise exception ''Ya hay una propuesta abierta para este movimiento'' using detail=''CUE_PROPUESTA_DUPLICADA''; end if;\n','');
 if v_new<>v_def then execute v_new; end if;
end $mig$;
