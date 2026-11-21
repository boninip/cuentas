-- 0052 · Cuentas: códigos estables CUE_* en DETAIL para las RPC críticas (pagos, cierre/archivo,
-- propuestas, delegaciones, cuenta compartida). El texto del mensaje NO cambia.
-- Alcance aprobado (Q4). Reversa: 0052_REVERSA.sql (quita ` using detail='CUE_...'`).
do $mig$
declare m record; f record; v_def text; v_new text; v_pat text; v_changed int:=0;
 map text[][]:=array[
  ['Iniciá sesión','CUE_SIN_SESION'],['No autorizado','CUE_NO_AUTORIZADO'],['Alcance inválido','CUE_ALCANCE_INVALIDO'],
  ['Decisión inválida','CUE_DECISION_INVALIDA'],['Destinatario inválido','CUE_DESTINATARIO_INVALIDO'],
  ['El gasto ya está anulado','CUE_GASTO_YA_ANULADO'],['El grupo está archivado','CUE_GRUPO_ARCHIVADO'],
  ['El movimiento no es un gasto','CUE_MOV_NO_ES_GASTO'],['El movimiento no es un pago','CUE_MOV_NO_ES_PAGO'],
  ['El pago fue anulado','CUE_PAGO_ANULADO'],['El pago no está confirmado: el que pagó puede cancelarlo','CUE_PAGO_NO_CONFIRMADO'],
  ['El pago supera lo que debés: no se admite crédito a favor','CUE_PAGO_SUPERA_DEUDA'],
  ['El pago supera lo que esa persona tiene a favor','CUE_PAGO_SUPERA_CREDITO'],
  ['El pago ya fue confirmado: lo puede anular la administración','CUE_PAGO_YA_CONFIRMADO'],
  ['El pago ya fue revertido','CUE_PAGO_YA_REVERTIDO'],['Elegí a otra persona','CUE_ELEGIR_OTRA_PERSONA'],
  ['Esa persona todavía no aceptó la invitación: no se pueden registrar pagos hacia ella','CUE_DESTINATARIO_SIN_ACEPTAR'],
  ['Estado inválido','CUE_ESTADO_INVALIDO'],['Falta la clave de idempotencia','CUE_FALTA_CLAVE'],
  ['Hay pagos pendientes de confirmar','CUE_PAGOS_PENDIENTES'],['Importe o moneda inválidos','CUE_IMPORTE_INVALIDO'],
  ['La clave de idempotencia ya se usó con otros datos','CUE_CLAVE_REUSADA'],
  ['La otra persona no es miembro activo del grupo','CUE_NO_ES_MIEMBRO'],['La persona no es miembro activo','CUE_NO_ES_MIEMBRO'],
  ['Las dos personas tienen que ser miembros activos','CUE_NO_ES_MIEMBRO'],
  ['La propuesta cambió: revisá la versión actual','CUE_PROPUESTA_VERSION'],
  ['La propuesta ya no está abierta','CUE_PROPUESTA_NO_ABIERTA'],['La propuesta ya no está abierta (%)','CUE_PROPUESTA_NO_ABIERTA'],
  ['La solicitud ya no está pendiente','CUE_SOLICITUD_NO_PENDIENTE'],['Motivo demasiado largo','CUE_MOTIVO_LARGO'],
  ['No hay delegación vigente','CUE_SIN_DELEGACION'],['No podés delegarte a vos mismo','CUE_AUTODELEGACION'],
  ['No sos parte afectada por esta propuesta','CUE_NO_ES_PARTE'],['Primero hay que cerrar el grupo','CUE_GRUPO_NO_CERRADO'],
  ['Solo el autor o quien administra puede pedir la anulación','CUE_SOLO_AUTOR_O_ADMIN'],
  ['Solo quien pagó o quien cobró puede pedir la reversión','CUE_SOLO_PARTES_DEL_PAGO'],
  ['Tipo de propuesta inválido','CUE_TIPO_INVALIDO'],['Ya respondiste esta propuesta','CUE_YA_RESPONDIDO']];
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname ~ '^cuentas_(payment|group_set_status|group_archive|proposal|delegate|pair)' loop
  v_def:=pg_get_functiondef(f.oid); v_new:=v_def;
  if v_def ~ 'detail=' then continue; end if;
  for i in 1..array_length(map,1) loop
   v_pat:='(raise exception '''||regexp_replace(map[i][1],'([\\^$.|?*+()\[\]{}])','\\\1','g')||'''[^;]*?)(\s*;)';
   v_new:=regexp_replace(v_new,v_pat,'\1 using detail='''||map[i][2]||'''\2','g');
  end loop;
  if v_new<>v_def then execute v_new; v_changed:=v_changed+1; end if;
 end loop;
 raise notice 'funciones reescritas: %',v_changed;
end $mig$;
