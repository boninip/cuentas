-- 0009 · Cuentas: misma clave de idempotencia con otros datos -> error (antes devolvía el original en silencio). DEV.
do $m$
declare d text; oldt text:=$o$ if found then return v_id; end if;$o$; nw text; sig text;
begin
 foreach sig in array array['public.cuentas_expense_add(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text)','public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text)'] loop
  d:=pg_get_functiondef(sig::regprocedure);
  if sig like '%expense_add%' then
   nw:=$n$ if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='expense' and amount_minor=p_amount_minor and currency=p_currency and from_user=p_payer) then raise exception 'La clave de idempotencia ya se usó con otros datos'; end if;
  return v_id; end if;$n$;
  else
   nw:=$n$ if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='payment' and amount_minor=p_amount_minor and currency=p_currency and to_user=p_to) then raise exception 'La clave de idempotencia ya se usó con otros datos'; end if;
  return v_id; end if;$n$;
  end if;
  if position(oldt in d)=0 then raise exception 'patrón no encontrado en %',sig; end if;
  execute replace(d,oldt,nw);
 end loop;
end $m$;
