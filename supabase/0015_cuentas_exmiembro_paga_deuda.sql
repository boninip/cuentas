-- 0015 Cuentas: un ex miembro (se fue o lo quitaron) puede registrar PAGOS para saldar su deuda. PROPUESTA (opción A), solo DEV.
-- No puede cargar gastos ni ver otros saldos. El tope ya existente (0010) limita el pago a lo que debe y a lo que el destinatario tiene a favor.
do $mig$
declare d text; a text:='if not found or not cuentas.is_active_member(p_group,v_user) then raise exception ''No autorizado''; end if;';
        b text:='if not found or not exists(select 1 from cuentas.members mm where mm.group_id=p_group and mm.user_id=v_user) then raise exception ''No autorizado''; end if;';
begin
 d:=pg_get_functiondef('public.cuentas_payment_add(uuid,text,bigint,uuid,text,date,text)'::regprocedure);
 if position(a in d)=0 then raise exception 'patrón no encontrado en payment_add'; end if;
 execute replace(d,a,b);
end $mig$;
