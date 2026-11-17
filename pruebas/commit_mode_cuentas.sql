-- Prueba de Cuentas "en modo confirmación" (DEV). Corre como rol authenticated y termina en excepción => no deja datos.
-- LECCIÓN (14/11): las pruebas que terminan en rollback NO disparan los triggers diferidos (se evalúan al COMMIT, fuera de
-- las funciones SECURITY DEFINER, con el rol de quien llama). Por eso un error de permisos pasó desapercibido y ningún gasto
-- se guardaba desde la app. Regla: después de cada operación que escribe, forzar `set constraints all immediate;`.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; tok text; tmp uuid; pay uuid; r text:='';
begin
 insert into auth.users(id,aud,role,email) select u,'authenticated','authenticated','prueba-'||u||'@example.invalid' from unnest(array[a,b]) u;
 set local role authenticated;
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 g:=public.cuentas_group_create('Modo confirmación','ARS'); tok:=public.cuentas_invite_create(g);
 tmp:=public.cuentas_expense_add(g,'ARS',2000000,a,array[a],null,'Un miembro',current_date,gen_random_uuid()::text);
 begin set constraints all immediate; r:=r||'1 gasto de 1 persona OK; '; exception when others then r:=r||'1 ERROR: '||sqlerrm||'; '; end; set constraints all deferred;
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true); tmp:=public.cuentas_invite_accept(tok);
 perform set_config('request.jwt.claims',json_build_object('sub',a,'role','authenticated')::text,true);
 tmp:=public.cuentas_expense_add(g,'ARS',1001,a,array[a,b],null,'Impar',current_date,gen_random_uuid()::text);
 begin set constraints all immediate; r:=r||'2 gasto de 2 personas con importe impar OK; '; exception when others then r:=r||'2 ERROR: '||sqlerrm||'; '; end; set constraints all deferred;
 tmp:=public.cuentas_expense_add(g,'ARS',3000,a,null,jsonb_build_object(a::text,1000,b::text,2000),'Exacto',current_date,gen_random_uuid()::text);
 begin set constraints all immediate; r:=r||'3 importes exactos OK; '; exception when others then r:=r||'3 ERROR: '||sqlerrm||'; '; end; set constraints all deferred;
 perform set_config('request.jwt.claims',json_build_object('sub',b,'role','authenticated')::text,true);
 pay:=public.cuentas_payment_add(g,'ARS',500,a,'pago',current_date,gen_random_uuid()::text);
 begin set constraints all immediate; r:=r||'4 pago OK; '; exception when others then r:=r||'4 ERROR: '||sqlerrm||'; '; end;
 raise exception 'REPORTE: %',r;
end $$;
