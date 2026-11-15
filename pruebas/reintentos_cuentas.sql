-- Resultado 14/11 en DEV: todo OK (reintento con misma clave = mismo id, 1 gasto; doble aceptación = 1 miembro; pago repetido = mismo id; doble confirmación idempotente; 1 pago).
-- Reintentos y repeticiones (DEV, termina en excepción => no deja datos). Simula doble toque / reintento de red.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; tok text; k text:=gen_random_uuid()::text; e1 uuid; e2 uuid; e3 uuid; pay uuid; k2 text:=gen_random_uuid()::text; p1 uuid; p2 uuid; n int; r text:=''; t1 uuid; t2 uuid;
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b]) u;
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Reintentos','ARS'); tok:=public.cuentas_invite_create(g);
 -- 1 mismo gasto con la misma clave dos veces
 e1:=public.cuentas_expense_add(g,'ARS',1000,a,array[a],null,'Doble toque',current_date,k);
 begin e2:=public.cuentas_expense_add(g,'ARS',1000,a,array[a],null,'Doble toque',current_date,k); r:=r||'1 reintento devuelve '||case when e1=e2 then 'el mismo id' else 'OTRO id (duplica)' end||'; ';
 exception when others then r:=r||'1 reintento rechazado: '||sqlerrm||'; '; end;
 set constraints all immediate; set constraints all deferred;
 reset role; select count(*) into n from cuentas.movements where group_id=g and kind='expense'; set local role authenticated; r:=r||'1 gastos guardados='||n||' (esperado 1); ';
 -- 2 aceptar la invitación dos veces
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 t1:=public.cuentas_invite_accept(tok);
 begin t2:=public.cuentas_invite_accept(tok); r:=r||'2 doble aceptación OK sin duplicar; '; exception when others then r:=r||'2 segunda aceptación: '||sqlerrm||'; '; end;
 reset role; select count(*) into n from cuentas.members where group_id=g and user_id=b; set local role authenticated; r:=r||'2 filas de miembro='||n||' (esperado 1); ';
-- 3 pago repetido y doble confirmación (b debe algo: a carga un gasto compartido)
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 e3:=public.cuentas_expense_add(g,'ARS',2000,a,array[a,b],null,'Compartido',current_date,gen_random_uuid()::text);
 set constraints all immediate; set constraints all deferred;
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 pay:=public.cuentas_payment_add(g,'ARS',500,a,'pago',current_date,k2);
 begin p2:=public.cuentas_payment_add(g,'ARS',500,a,'pago',current_date,k2); r:=r||'3 pago repetido '||case when pay=p2 then 'mismo id' else 'OTRO id (duplica)' end||'; ';
 exception when others then r:=r||'3 pago repetido rechazado: '||sqlerrm||'; '; end;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 perform public.cuentas_payment_confirm(pay);
 begin perform public.cuentas_payment_confirm(pay); r:=r||'3 doble confirmación OK (idempotente); '; exception when others then r:=r||'3 doble confirmación: '||sqlerrm||'; '; end;
 reset role; select count(*) into n from cuentas.movements where group_id=g and kind='payment'; set local role authenticated; r:=r||'3 pagos guardados='||n||' (esperado 1); ';
 raise exception 'REPORTE: %',r;
end $$;
