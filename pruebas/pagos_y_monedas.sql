-- 0029: anulación de pagos por la administración y monedas sin decimales. DEV, termina en excepción => no deja datos.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); g uuid; r text:=''; e uuid; p uuid; x uuid; n int; s text; bal bigint;
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b,c]) u;
 insert into core.planazo_profiles(user_id,display_name) values(a,'Ana'),(b,'Beto'),(c,'Cami');
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Prueba 0029','ARS');
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 reset role; insert into cuentas.members(group_id,user_id,role,status) values(g,b,'member','active'),(g,c,'member','active') on conflict do nothing; set local role authenticated;
 -- monedas sin decimales
 e:=public.cuentas_expense_add(g,'CLP',1000000,a,array[a,b,c],null,'Cena CLP',current_date,gen_random_uuid()::text);
 reset role; select string_agg(share_minor::text,',' order by share_minor desc) into s from cuentas.movement_shares where movement_id=e; set local role authenticated;
 r:=r||'1 CLP 10000 en 3 = '||s||' (esperado 333400,333300,333300); ';
 begin perform public.cuentas_expense_add(g,'CLP',1050,a,array[a],null,'x',current_date,gen_random_uuid()::text); r:=r||'2 CLP con decimales ACEPTADO (mal); '; exception when others then r:=r||'2 CLP con decimales rechazado ok; '; end;
 begin perform public.cuentas_expense_add(g,'CLP',1000,a,array[a,b],jsonb_build_object(a::text,550,b::text,450),'x',current_date,gen_random_uuid()::text); r:=r||'3 partes CLP con decimales ACEPTADO (mal); '; exception when others then r:=r||'3 partes CLP con decimales rechazado ok; '; end;
 e:=public.cuentas_expense_add(g,'ARS',900000,a,array[a,b,c],null,'Cena ARS',current_date,gen_random_uuid()::text);
 e:=public.cuentas_expense_add(g,'ARS',10001,a,array[a,b,c],null,'Centavos',current_date,gen_random_uuid()::text);
 reset role; select string_agg(share_minor::text,',' order by share_minor desc) into s from cuentas.movement_shares where movement_id=e; set local role authenticated;
 r:=r||'4 ARS 100,01 en 3 = '||s||' (esperado 3334,3334,3333); ';
 -- pagos
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 p:=public.cuentas_payment_add(g,'ARS',100000,a,'Parcial',current_date,gen_random_uuid()::text);
 r:=r||'5 pago parcial registrado; ';
 perform set_config('request.jwt.claims',json_build_object('sub',c,'role','authenticated')::text,true);
 begin perform public.cuentas_payment_cancel(p); r:=r||'6 un tercero anuló ACEPTADO (mal); '; exception when others then r:=r||'6 tercero rechazado ok; '; end;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 x:=public.cuentas_payment_cancel(p); r:=r||'7 la administración anuló un pago sin confirmar: '||(x is not null)||'; ';
 reset role; select count(*) into n from cuentas.audit_log where group_id=g and action='payment_cancelled' and (detail->>'by_admin')='true'; set local role authenticated;
 r:=r||'8 auditoría by_admin='||n||'; ';
 -- confirmado
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 p:=public.cuentas_payment_add(g,'ARS',100000,a,'Otro',current_date,gen_random_uuid()::text);
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 perform public.cuentas_payment_confirm(p);
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 begin perform public.cuentas_payment_cancel(p); r:=r||'9 el autor anuló uno confirmado ACEPTADO (mal); '; exception when others then r:=r||'9 autor con pago confirmado rechazado ok; '; end;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 select balance_minor into bal from public.cuentas_balances(g) where user_id=b and currency='ARS'; r:=r||'10 saldo de Beto con pago confirmado='||bal||'; ';
 x:=public.cuentas_payment_cancel(p);
 select balance_minor into bal from public.cuentas_balances(g) where user_id=b and currency='ARS'; r:=r||'11 saldo de Beto tras anular el confirmado='||bal||' (debe ser más negativo en 100000); ';
 r:=r||'12 anular dos veces devuelve lo mismo='||(public.cuentas_payment_cancel(p)=x)||'; ';
 set constraints all immediate;
 raise exception 'REPORTE: %',r;
end $$;
