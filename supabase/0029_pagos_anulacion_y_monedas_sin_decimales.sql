-- 0029 · PROPUESTA (DEV). Cuentas 1.0:
--  A1: anular un pago registrado (contramovimiento). Lo anula quien lo registró mientras no esté confirmado;
--      la administración (permiso 'void') puede anularlo siempre, también confirmado. Queda auditado con quién lo hizo.
--  A4: monedas sin decimales (CLP, PYG, JPY, KRW, VND, ISK, UGX): importes y partes en unidades enteras
--      (se sigue guardando en escala x100, por eso deben ser múltiplos de 100). El reparto en partes iguales
--      reparte el resto de a una unidad entera.
create or replace function cuentas.unit(p_cur text) returns int language sql immutable set search_path='' as
$$ select case when p_cur in ('CLP','PYG','JPY','KRW','VND','ISK','UGX') then 100 else 1 end $$;

create or replace function cuentas.check_unit_mov() returns trigger language plpgsql set search_path='' as
$$ begin
 if new.kind in ('expense','payment','compensation') and new.amount_minor % cuentas.unit(new.currency) <> 0 then
  raise exception 'La moneda % no admite decimales', new.currency; end if;
 return new; end $$;
drop trigger if exists movements_unit_check on cuentas.movements;
create trigger movements_unit_check before insert on cuentas.movements for each row execute function cuentas.check_unit_mov();

create or replace function cuentas.check_unit_share() returns trigger language plpgsql set search_path='' as
$$ declare c text; begin
 select currency into c from cuentas.movements where id=new.movement_id;
 if new.share_minor % cuentas.unit(c) <> 0 then raise exception 'La moneda % no admite decimales', c; end if;
 return new; end $$;
drop trigger if exists shares_unit_check on cuentas.movement_shares;
create trigger shares_unit_check before insert on cuentas.movement_shares for each row execute function cuentas.check_unit_share();

-- reparto en partes iguales respetando la unidad de la moneda
create or replace function public.cuentas_expense_add(p_group uuid, p_currency text, p_amount_minor bigint, p_payer uuid, p_participants uuid[], p_shares jsonb, p_description text, p_occurred_on date, p_key text, p_category text DEFAULT NULL::text, p_fx numeric DEFAULT NULL::numeric)
 returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); v_status text; v_ref text; v_id uuid; v_parts uuid[]; v_n int; v_base bigint; v_rem bigint; v_i int:=0; v_sum bigint:=0; r record; u uuid; v_unit int; v_whole bigint;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 if p_key is null or length(p_key) not between 8 and 100 then raise exception 'Falta la clave de idempotencia'; end if;
 select status, reference_currency into v_status, v_ref from cuentas.groups where id=p_group;
 if not found or not cuentas.is_active_member(p_group,v_user) then raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where group_id=p_group and created_by=v_user and idempotency_key=p_key;
 if found then
  if not exists(select 1 from cuentas.movements where id=v_id and kind='expense' and amount_minor=p_amount_minor and currency=p_currency and from_user=p_payer) then raise exception 'La clave de idempotencia ya se usó con otros datos'; end if;
  return v_id; end if;
 if v_status<>'open' then raise exception 'El grupo está cerrado: no admite gastos nuevos'; end if;
 if coalesce(p_currency,'') !~ '^[A-Z]{3}$' or p_amount_minor is null or p_amount_minor<=0 or p_amount_minor>1000000000000 then raise exception 'Importe o moneda inválidos'; end if;
 if coalesce(length(p_description),0)>300 then raise exception 'Descripción demasiado larga'; end if;
 if not cuentas.is_active_member(p_group,p_payer) then raise exception 'El pagador no es miembro activo'; end if;
 if p_category is not null and not exists(select 1 from cuentas.group_categories where group_id=p_group and key=p_category) then raise exception 'La categoría no existe'; end if;
 if p_fx is not null and (p_currency=v_ref or p_fx<=0 or p_fx>1000000000) then raise exception 'Cotización inválida'; end if;
 v_unit:=cuentas.unit(p_currency);
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,description,occurred_on,created_by,idempotency_key,category,fx_rate)
 values(p_group,'expense',p_currency,p_amount_minor,p_payer,nullif(trim(coalesce(p_description,'')),''),coalesce(p_occurred_on,current_date),v_user,p_key,p_category,case when p_currency=v_ref then null else p_fx end) returning id into v_id;
 if p_shares is not null then
  if jsonb_typeof(p_shares)<>'object' then raise exception 'Reparto inválido'; end if;
  for r in select key, value from jsonb_each_text(p_shares) loop
   u:=r.key::uuid;
   if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   insert into cuentas.movement_shares(movement_id,user_id,share_minor) values(v_id,u,r.value::bigint);
   v_sum:=v_sum+r.value::bigint;
  end loop;
  if v_sum<>p_amount_minor then raise exception 'El reparto no suma el importe'; end if;
 else
  select array_agg(distinct x order by x) into v_parts from unnest(p_participants) as x;
  v_n:=coalesce(array_length(v_parts,1),0);
  if v_n=0 then raise exception 'Falta repartir entre al menos una persona'; end if;
  v_whole:=p_amount_minor / v_unit; v_base:=(v_whole / v_n)*v_unit; v_rem:=v_whole % v_n;
  foreach u in array v_parts loop
   v_i:=v_i+1;
   if not cuentas.is_active_member(p_group,u) then raise exception 'Un participante no es miembro activo'; end if;
   insert into cuentas.movement_shares(movement_id,user_id,share_minor) values(v_id,u,v_base+case when v_i<=v_rem then v_unit else 0 end);
  end loop;
 end if;
 perform cuentas.log(p_group,v_user,'expense_added',jsonb_build_object('movement',v_id,'amount_minor',p_amount_minor,'currency',p_currency));
 return v_id;
end $function$;

create or replace function public.cuentas_payment_cancel(p_payment uuid)
 returns uuid language plpgsql security definer set search_path to '' as $function$
declare v_user uuid:=auth.uid(); p cuentas.movements%rowtype; v_id uuid; v_conf boolean; v_adm boolean;
begin
 if v_user is null then raise exception 'Iniciá sesión'; end if;
 select * into p from cuentas.movements where id=p_payment and kind='payment';
 if not found then raise exception 'No autorizado'; end if;
 if (select status from cuentas.groups where id=p.group_id)='archived' then raise exception 'El grupo está archivado'; end if;
 v_adm:=cuentas.can(p.group_id,v_user,'void');
 v_conf:=exists(select 1 from cuentas.movements where ref_id=p.id and kind='payment_confirmation');
 if not (v_adm or (p.created_by=v_user and not v_conf)) then
  if p.created_by=v_user then raise exception 'El pago ya fue confirmado: lo puede anular la administración'; end if;
  raise exception 'No autorizado'; end if;
 select id into v_id from cuentas.movements where ref_id=p.id and kind='payment_reversal';
 if found then return v_id; end if;
 insert into cuentas.movements(group_id,kind,currency,amount_minor,from_user,to_user,ref_id,created_by,idempotency_key)
 values(p.group_id,'payment_reversal',p.currency,p.amount_minor,p.from_user,p.to_user,p.id,v_user,'reverse:'||p.id) returning id into v_id;
 perform cuentas.log(p.group_id,v_user,'payment_cancelled',jsonb_build_object('payment',p.id,'confirmed',v_conf,'by_admin',v_adm and p.created_by<>v_user));
 return v_id;
end $function$;
