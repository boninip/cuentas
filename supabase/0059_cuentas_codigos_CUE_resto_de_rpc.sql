-- 0059 (Cuentas): código CUE_* en el DETAIL de los errores de las RPC que todavía no lo tenían.
-- Solo cambia las excepciones simples (mensaje sin parámetros); el texto del mensaje no cambia. Autorizado por Pau el 22/11/2026.
do $mig$
declare r record; f record; v_def text; v_new text; n int:=0;
begin
 for f in select p.oid from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in ('cuentas_balances','cuentas_categories_list','cuentas_category_archive','cuentas_category_save','cuentas_compensation_reverse_propose','cuentas_delegations_list','cuentas_exmember_payees','cuentas_expense_edit','cuentas_expense_void','cuentas_group_get','cuentas_group_payouts','cuentas_guest_invite_create','cuentas_guest_remove','cuentas_invite_create','cuentas_member_leave','cuentas_member_remove','cuentas_member_set_guardian','cuentas_member_set_weight','cuentas_movements_list','cuentas_my_balance','cuentas_payout_clear','cuentas_payout_get','cuentas_payout_set','cuentas_receipt_copy','cuentas_receipt_register','cuentas_receipts_list','cuentas_recurring_list','cuentas_recurring_run','cuentas_recurring_set_status','cuentas_activity_list','cuentas_invite_preview','cuentas_my_groups','cuentas_my_groups_all','cuentas_my_pending','cuentas_expense_add','cuentas_recurring_save','cuentas_compensation_propose') loop
  v_def:=pg_get_functiondef(f.oid); v_new:=v_def;
  for r in select * from (values
  ($m$No autorizado$m$,$c$CUE_NO_AUTORIZADO$c$),
  ($m$Iniciá sesión$m$,$c$CUE_SIN_SESION$c$),
  ($m$No es miembro activo$m$,$c$CUE_NO_ES_MIEMBRO$c$),
  ($m$El grupo está archivado$m$,$c$CUE_GRUPO_ARCHIVADO$c$),
  ($m$Esa persona ya aceptó o no existe$m$,$c$CUE_INVITADO_NO_DISPONIBLE$c$),
  ($m$La categoría no existe$m$,$c$CUE_CATEGORIA_NO_EXISTE$c$),
  ($m$Parámetros inválidos$m$,$c$CUE_PARAMETROS_INVALIDOS$c$),
  ($m$Alias inválido: 6 a 20 caracteres, letras, números, punto o guion$m$,$c$CUE_ALIAS_INVALIDO$c$),
  ($m$Cargá un alias o un CBU/CVU$m$,$c$CUE_COBRO_FALTA_DATO$c$),
  ($m$CBU/CVU inválido: son 22 números$m$,$c$CUE_CBU_INVALIDO$c$),
  ($m$Color inválido$m$,$c$CUE_COLOR_INVALIDO$c$),
  ($m$El nombre va de 1 a 30 letras$m$,$c$CUE_NOMBRE_INVALIDO$c$),
  ($m$El peso va de 0 a 5$m$,$c$CUE_PESO_INVALIDO$c$),
  ($m$El responsable no es miembro activo$m$,$c$CUE_RESPONSABLE_INVALIDO$c$),
  ($m$El responsable ya tiene un responsable$m$,$c$CUE_RESPONSABLE_INVALIDO$c$),
  ($m$Esa persona ya es responsable de otras$m$,$c$CUE_RESPONSABLE_INVALIDO$c$),
  ($m$Una persona no puede ser su propio responsable$m$,$c$CUE_RESPONSABLE_INVALIDO$c$),
  ($m$Ese gasto ya fue anulado o editado$m$,$c$CUE_GASTO_YA_ANULADO$c$),
  ($m$Estado inválido$m$,$c$CUE_ESTADO_INVALIDO$c$),
  ($m$Este gasto ya tiene comprobante$m$,$c$CUE_COMPROBANTE_YA_EXISTE$c$),
  ($m$Hay movimientos posteriores de los mismos afectados en esa moneda: resolvelos primero$m$,$c$CUE_MOVIMIENTOS_POSTERIORES$c$),
  ($m$Hay pagos confirmados en el grupo: para anular hay que crear una propuesta que aprueben todos los afectados$m$,$c$CUE_PAGOS_CONFIRMADOS$c$),
  ($m$Ícono inválido$m$,$c$CUE_ICONO_INVALIDO$c$),
  ($m$La compensación ya fue revertida$m$,$c$CUE_COMPENSACION_YA_REVERTIDA$c$),
  ($m$La foto es demasiado grande$m$,$c$CUE_FOTO_GRANDE$c$),
  ($m$La foto no llegó al servidor$m$,$c$CUE_FOTO_NO_LLEGO$c$),
  ($m$Las dos personas tienen que ser miembros activos$m$,$c$CUE_NO_ES_MIEMBRO$c$),
  ($m$Motivo demasiado largo$m$,$c$CUE_MOTIVO_LARGO$c$),
  ($m$No sos miembro de este grupo$m$,$c$CUE_NO_AUTORIZADO$c$),
  ($m$Para salir usá la opción de salir del grupo$m$,$c$CUE_USAR_SALIR$c$),
  ($m$Solo el autor o un administrador puede anular$m$,$c$CUE_SOLO_AUTOR_O_ADMIN$c$),
  ($m$Solo quien lo creó o la administración puede cambiarlo$m$,$c$CUE_SOLO_AUTOR_O_ADMIN$c$),
  ($m$Sos el único administrador: nombrá a otro antes de salir$m$,$c$CUE_UNICO_ADMIN$c$),
  ($m$Ya terminó$m$,$c$CUE_REPETIDO_TERMINADO$c$),
  ($m$Ya tiene gastos en el grupo: no se puede quitar$m$,$c$CUE_INVITADO_CON_GASTOS$c$),
  ($m$Cotización inválida$m$,$c$CUE_COTIZACION_INVALIDA$c$),
  ($m$Descripción demasiado larga$m$,$c$CUE_DESCRIPCION_LARGA$c$),
  ($m$El fin es anterior al inicio$m$,$c$CUE_FECHAS_INVALIDAS$c$),
  ($m$La fecha de inicio es inválida o muy vieja$m$,$c$CUE_FECHAS_INVALIDAS$c$),
  ($m$El grupo está cerrado: no admite gastos nuevos$m$,$c$CUE_GRUPO_CERRADO$c$),
  ($m$El importe supera lo que se puede compensar ahora (deuda o saldo a favor disponibles)$m$,$c$CUE_COMPENSACION_SUPERA$c$),
  ($m$El pagador no es miembro activo$m$,$c$CUE_NO_ES_MIEMBRO$c$),
  ($m$El reparto no suma el importe$m$,$c$CUE_REPARTO_INVALIDO$c$),
  ($m$Falta la clave de idempotencia$m$,$c$CUE_FALTA_CLAVE$c$),
  ($m$Falta repartir entre al menos una persona$m$,$c$CUE_REPARTO_INVALIDO$c$),
  ($m$Frecuencia inválida$m$,$c$CUE_FRECUENCIA_INVALIDA$c$),
  ($m$Importe o moneda inválidos$m$,$c$CUE_IMPORTE_INVALIDO$c$),
  ($m$La clave de idempotencia ya se usó con otros datos$m$,$c$CUE_CLAVE_REUSADA$c$),
  ($m$La cuenta compartida no está activa$m$,$c$CUE_CUENTA_COMPARTIDA_INACTIVA$c$),
  ($m$No hay una deuda y un saldo a favor entre las dos personas en esa moneda$m$,$c$CUE_SIN_DEUDA_COMPENSABLE$c$),
  ($m$Poné una descripción$m$,$c$CUE_DESCRIPCION_FALTA$c$),
  ($m$Reparto inválido$m$,$c$CUE_REPARTO_INVALIDO$c$),
  ($m$Un participante no es miembro activo$m$,$c$CUE_NO_ES_MIEMBRO$c$)
  ) t(m,c) loop
   v_new:=replace(v_new,'raise exception '''||r.m||''';','raise exception '''||r.m||''' using detail='''||r.c||''';');
  end loop;
  if v_new<>v_def then execute v_new; n:=n+1; end if;
 end loop;
 raise notice 'funciones modificadas: %',n;
end $mig$;
