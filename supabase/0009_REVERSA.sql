-- Reversa 0009: volver al comportamiento anterior (devolver el original sin comparar).
do $m$
declare d text; sig text; a text; b text;
begin
 foreach sig in array array['public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text)','public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text)'] loop
  d:=pg_get_functiondef(sig::regprocedure);
  d:=regexp_replace(d,E' if found then\\n  if not exists\\(select 1 from cuentas.movements where id=v_id[^\\n]*\\n  return v_id; end if;',' if found then return v_id; end if;');
  execute d;
 end loop;
end $m$;
