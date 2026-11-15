-- Invitados por nombre (0024). DEV, termina en excepción => no deja datos.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; gu uuid; tok text; r text:=''; n int; j jsonb; pay uuid; bal bigint;
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b]) u;
 insert into core.planazo_profiles(user_id,display_name) values(a,'Ana'),(b,'Bruno real');
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Invitados','ARS');
 gu:=public.cuentas_guest_add(g,'Bruno');
 begin perform public.cuentas_guest_add(g,'bruno'); r:=r||'1 duplicado ACEPTADO (mal); '; exception when others then r:=r||'1 duplicado rechazado ok; '; end;
 j:=public.cuentas_group_get(g); r:=r||'2 miembros='||jsonb_array_length(j->'members')||' (esperado 2); ';
 -- gasto compartido con el invitado, paga Ana
 perform public.cuentas_expense_add(g,'ARS',3000,a,array[a,gu],null,'Cena',current_date,gen_random_uuid()::text);
 set constraints all immediate; set constraints all deferred;
 select balance_minor into bal from public.cuentas_balances(g) where user_id=gu; r:=r||'3 saldo invitado='||coalesce(bal,0)||' (esperado -150000? en centavos: -150000 si 3000 son centavos=>-1500); ';
 begin perform public.cuentas_payment_add(g,'ARS',100,gu,'x',current_date,gen_random_uuid()::text); r:=r||'4 pago a invitado ACEPTADO (mal); '; exception when others then r:=r||'4 pago hacia invitado: '||sqlerrm||'; '; end;
 tok:=public.cuentas_guest_invite_create(g,gu);
 -- Bruno real acepta el link personal
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 j:=public.cuentas_invite_preview(tok); r:=r||'5 preview guest_name='||(j->>'guest_name')||'; ';
 perform public.cuentas_invite_accept(tok);
 begin perform public.cuentas_invite_accept(tok); r:=r||'6 segunda aceptación OK (idempotente); '; exception when others then r:=r||'6 segunda aceptación: '||sqlerrm||'; '; end;
 j:=public.cuentas_group_get(g); r:=r||'7 miembros tras vincular='||jsonb_array_length(j->'members')||' (esperado 2: Ana y Bruno real); ';
 select balance_minor into bal from public.cuentas_balances(g) where user_id=b; r:=r||'8 saldo de Bruno real='||coalesce(bal,0)||' (hereda lo del invitado); ';
 select count(*) into n from public.cuentas_balances(g) where user_id=gu; r:=r||'9 filas del cascarón='||n||' (esperado 0); ';
 j:=public.cuentas_movements_list(g); r:=r||'10 shares en lista incluye a Bruno real='||((j->0->'shares') ? b::text)||' y no al cascarón='||(not ((j->0->'shares') ? gu::text))||'; ';
 pay:=public.cuentas_payment_add(g,'ARS',500,a,'pago',current_date,gen_random_uuid()::text); r:=r||'11 pago de Bruno real a Ana creado; ';
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 perform public.cuentas_payment_confirm(pay);
 select balance_minor into bal from public.cuentas_balances(g) where user_id=b; r:=r||'12 saldo tras pago='||coalesce(bal,0)||'; ';
 raise exception 'REPORTE: %',r;
end $$;
