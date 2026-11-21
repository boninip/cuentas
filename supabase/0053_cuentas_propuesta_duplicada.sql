-- 0053 · Cuentas: proponer sobre algo que ya tiene una propuesta abierta da un error con código
-- (antes: violación cruda del índice único proposals_one_open). Parche por ancla sobre la definición viva.
-- Reversa: 0053_REVERSA.sql
do $mig$
declare v_def text; v_new text; v_anchor text:=' if coalesce(length(p_reason),0)>300 then';
begin
 v_def:=pg_get_functiondef('public.cuentas_proposal_create(text,uuid,text)'::regprocedure);
 if position(v_anchor in v_def)=0 then raise exception 'Ancla no encontrada: revisar cuentas_proposal_create'; end if;
 if position('CUE_PROPUESTA_DUPLICADA' in v_def)>0 then return; end if;
 v_new:=replace(v_def,v_anchor,E' if exists(select 1 from cuentas.proposals where kind=p_kind and target_id=t.id and status=''open'') then raise exception ''Ya hay una propuesta abierta para este movimiento'' using detail=''CUE_PROPUESTA_DUPLICADA''; end if;\n'||v_anchor);
 execute v_new;
end $mig$;
