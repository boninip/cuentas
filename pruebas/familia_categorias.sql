-- Categorías, cotización, peso y responsable (0025). DEV, termina en excepción => no deja datos.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; kid uuid; k text; cats jsonb; r text:=''; j jsonb; mv jsonb; e uuid; n int; bal bigint; w numeric;
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b]) u;
 insert into core.planazo_profiles(user_id,display_name) values(a,'Ana'),(b,'Beto');
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Familia','ARS');
 kid:=public.cuentas_guest_add(g,'Mateo');
 -- categorías
 cats:=public.cuentas_categories_list(g); r:=r||'1 categorías base='||jsonb_array_length(cats)||' (esperado 7); ';
 k:=public.cuentas_category_save(g,null,'Mascotas','paw',2); r:=r||'2 categoría nueva key='||k||'; ';
 perform public.cuentas_category_save(g,k,'Mascotas y vet','heart',2);
 perform public.cuentas_category_archive(g,k,true);
 select (x->>'archived')::boolean::text into k from jsonb_array_elements(public.cuentas_categories_list(g)) x where x->>'key' like 'mascotas%'; r:=r||'3 archivada='||k||'; ';
 begin perform public.cuentas_category_save(g,null,'x','nopermitido',0); r:=r||'4 ícono inválido ACEPTADO (mal); '; exception when others then r:=r||'4 ícono inválido rechazado ok; '; end;
 -- gasto con categoría
 e:=public.cuentas_expense_add(g,'ARS',9000,a,array[a,kid],null,'Asado',current_date,gen_random_uuid()::text,'comida',null);
 mv:=public.cuentas_movements_list(g); r:=r||'5 categoría en lista='||coalesce((select x->>'category' from jsonb_array_elements(mv) x where x->>'description'='Asado'),'null')||'; ';
 begin perform public.cuentas_expense_add(g,'ARS',100,a,array[a],null,'x',current_date,gen_random_uuid()::text,'no-existe',null); r:=r||'6 categoría inexistente ACEPTADA (mal); '; exception when others then r:=r||'6 categoría inexistente rechazada ok; '; end;
 -- cotización
 e:=public.cuentas_expense_add(g,'USD',1000,a,array[a],null,'Hotel',current_date,gen_random_uuid()::text,'alojamiento',1250.5);
 mv:=public.cuentas_movements_list(g); r:=r||'7 fx guardado='||coalesce((select x->>'fx_rate' from jsonb_array_elements(mv) x where x->>'description'='Hotel'),'null')||'; ';
 begin perform public.cuentas_expense_add(g,'ARS',500,a,array[a],null,'Sin fx',current_date,gen_random_uuid()::text,null,99); r:=r||'8 fx en moneda del grupo ACEPTADO (mal); '; exception when others then r:=r||'8 fx en moneda del grupo rechazado ok; '; end;
 begin perform public.cuentas_expense_add(g,'USD',100,a,array[a],null,'x',current_date,gen_random_uuid()::text,null,0); r:=r||'9 fx 0 ACEPTADO (mal); '; exception when others then r:=r||'9 fx 0 rechazado ok; '; end;
 -- pesos
 perform public.cuentas_member_set_weight(g,kid,0.5);
 j:=public.cuentas_group_get(g); select (m->>'weight')::numeric into w from jsonb_array_elements(j->'members') m where (m->>'user_id')::uuid=kid; r:=r||'10 peso de Mateo='||w||'; ';
 begin perform public.cuentas_member_set_weight(g,kid,9); r:=r||'11 peso 9 ACEPTADO (mal); '; exception when others then r:=r||'11 peso 9 rechazado ok; '; end;
 -- responsable
 begin perform public.cuentas_member_set_guardian(g,kid,kid); r:=r||'12 responsable=uno mismo ACEPTADO (mal); '; exception when others then r:=r||'12 responsable=uno mismo rechazado ok; '; end;
 select balance_minor into bal from public.cuentas_balances(g) where user_id=kid and currency='ARS'; r:=r||'13 saldo Mateo antes='||coalesce(bal,0)||'; ';
 perform public.cuentas_member_set_guardian(g,kid,a);
 select count(*) into n from public.cuentas_balances(g) where user_id=kid; r:=r||'14 filas de Mateo tras responsable='||n||' (esperado 0); ';
 select balance_minor into bal from public.cuentas_balances(g) where user_id=a and currency='ARS'; r:=r||'15 saldo de Ana='||coalesce(bal,0)||' (esperado: puso 9000+1000USD aparte; en ARS 9000 menos su parte y la de Mateo = 0); ';
 j:=public.cuentas_movements_list(g); r:=r||'16 shares de la lista siguen con Mateo='||((j->0->'shares') ? kid::text)||'; ';
 begin perform public.cuentas_member_set_guardian(g,a,kid); r:=r||'17 ciclo ACEPTADO (mal); '; exception when others then r:=r||'17 ciclo rechazado ok; '; end;
 -- permiso: un miembro común no puede
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 begin perform public.cuentas_member_set_weight(g,kid,1); r:=r||'18 peso por no miembro ACEPTADO (mal); '; exception when others then r:=r||'18 no miembro rechazado ok; '; end;
 set constraints all immediate;
 raise exception 'REPORTE: %',r;
end $$;
