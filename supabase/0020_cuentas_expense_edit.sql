-- 0020 Cuentas: editar un gasto = anularlo y crear el corregido, en una sola operación atómica. PROPUESTA, solo DEV.
-- Respeta las reglas de anular: autor o quien tenga delegación 'void'; si hay pagos confirmados en el grupo, no se puede (hay que usar propuesta).
create function public.cuentas_expense_edit(p_expense uuid, p_currency text, p_amount_minor bigint, p_payer uuid, p_participants uuid[], p_shares jsonb, p_description text, p_occurred_on date, p_key text)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_group uuid; v_new uuid;
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 select group_id into v_group from cuentas.movements where id=p_expense and kind='expense';
 if not found then raise exception 'No autorizado'; end if;
 if exists(select 1 from cuentas.movements where ref_id=p_expense and kind='void') then raise exception 'Ese gasto ya fue anulado o editado'; end if;
 perform public.cuentas_expense_void(p_expense,'Editado');
 v_new:=public.cuentas_expense_add(v_group,p_currency,p_amount_minor,p_payer,p_participants,p_shares,p_description,p_occurred_on,p_key);
 perform cuentas.log(v_group,auth.uid(),'expense_edited',jsonb_build_object('old',p_expense,'new',v_new));
 return v_new;
end $$;
revoke all on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text) from public, anon;
grant execute on function public.cuentas_expense_edit(uuid,text,bigint,uuid,uuid[],jsonb,text,date,text) to authenticated;
