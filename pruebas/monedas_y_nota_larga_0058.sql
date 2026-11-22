do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; r text:=''; e uuid; d text; n text:=repeat('n',1000);
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b]) u;
 insert into core.pinto_profiles(user_id,display_name) values(a,'Ana'),(b,'Beto');
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Prueba 0058','ARS'); r:=r||'1 grupo ARS ok; ';
 begin perform public.cuentas_group_create('Mala','XYZ'); r:=r||'2 grupo XYZ ACEPTADO (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'2 grupo XYZ -> '||coalesce(d,'?')||'; '; end;
 reset role; insert into cuentas.members(group_id,user_id,role,status) values(g,b,'member','active') on conflict do nothing; set local role authenticated;
 e:=public.cuentas_expense_add(g,'USD',1000,a,array[a,b],null,'Cena USD',current_date,gen_random_uuid()::text); r:=r||'3 gasto USD ok; ';
 begin perform public.cuentas_expense_add(g,'XYZ',1000,a,array[a,b],null,'x',current_date,gen_random_uuid()::text); r:=r||'4 gasto XYZ ACEPTADO (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'4 gasto XYZ -> '||coalesce(d,'?')||'; '; end;
 e:=public.cuentas_expense_add(g,'ARS',1000,a,array[a,b],null,'Nota exacta',current_date,gen_random_uuid()::text,null,null,null,null,n); r:=r||'5 nota de 1000 ok; ';
 begin perform public.cuentas_expense_add(g,'ARS',1000,a,array[a,b],null,'Nota larga',current_date,gen_random_uuid()::text,null,null,null,null,n||'x'); r:=r||'6 nota 1001 ACEPTADA (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'6 nota 1001 -> '||coalesce(d,'?')||'; '; end;
 begin perform public.cuentas_expense_edit(e,'ARS',1000,a,array[a,b],null,'Nota exacta',current_date,gen_random_uuid()::text,null,null,n||'x'); r:=r||'7 editar con nota 1001 ACEPTADO (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'7 editar nota 1001 -> '||coalesce(d,'?')||'; '; end;
 begin perform public.cuentas_recurring_save(g,'Alquiler',1000,'XYZ',a,array[a,b],null,null,null,'monthly',current_date,null); r:=r||'8 repetido XYZ ACEPTADO (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'8 repetido XYZ -> '||coalesce(d,'?')||'; '; end;
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 begin perform public.cuentas_payment_add(g,'XYZ',100,a,'p',current_date,gen_random_uuid()::text); r:=r||'9 pago XYZ ACEPTADO (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'9 pago XYZ -> '||coalesce(d,'?')||'; '; end;
 perform public.cuentas_payment_add(g,'ARS',100,a,'p',current_date,gen_random_uuid()::text); r:=r||'10 pago ARS ok; ';
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 reset role; update cuentas.allowed_currencies set active=false where code='USD'; set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 begin perform public.cuentas_expense_add(g,'USD',1000,a,array[a,b],null,'x',current_date,gen_random_uuid()::text); r:=r||'11 USD apagada ACEPTADA (mal); '; exception when others then get stacked diagnostics d=pg_exception_detail; r:=r||'11 USD apagada -> '||coalesce(d,'?')||'; '; end;
 begin perform cuentas.currency_ok('ARS'); r:=r||'12 authenticated ejecuta currency_ok (mal); '; exception when others then r:=r||'12 currency_ok cerrada ok; '; end;
 begin perform 1 from cuentas.allowed_currencies; r:=r||'13 authenticated lee la tabla (mal); '; exception when others then r:=r||'13 tabla cerrada ok; '; end;
 reset role;
 r:=r||'14 anon currency_ok='||has_function_privilege('anon','cuentas.currency_ok(text)','execute');
 raise exception 'REPORTE: %',r;
end $$;
