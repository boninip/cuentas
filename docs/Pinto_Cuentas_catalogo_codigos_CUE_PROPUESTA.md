# Cuentas · Catálogo de códigos de error CUE_* — PROPUESTA (21/11/2026)

Estado: **APROBADO por Pau el 21/11/2026** (junto con el texto final del ADR-010). Alcance aprobado por Pau (Q4: pagos, cierre, propuestas, delegaciones). Aplicado en DEV con la migración 0052 (y 0051 y 0053 para los nuevos). Regla de ADR-010 P1: el código va en `DETAIL`; el texto del mensaje puede cambiar y la interfaz no debe compararlo.
En los documentos fuente, «Gastos» = Cuentas.

| Código | Significado | Dónde |
| --- | --- | --- |
| CUE_SIN_SESION | No hay sesión | todas las RPC cubiertas |
| CUE_NO_AUTORIZADO | Sin permiso, o el recurso no existe para esa persona | todas |
| CUE_ALCANCE_INVALIDO | Alcance de delegación inexistente | delegate_grant |
| CUE_AUTODELEGACION | Delegarse a uno mismo | delegate_grant |
| CUE_SIN_DELEGACION | No hay delegación vigente que revocar | delegate_revoke |
| CUE_DECISION_INVALIDA | Decisión distinta de approve/reject | proposal_consent |
| CUE_TIPO_INVALIDO | Tipo de propuesta inválido | proposal_create |
| CUE_MOTIVO_LARGO | Motivo de más de 300 caracteres | proposal_create |
| CUE_MOV_NO_ES_GASTO / CUE_MOV_NO_ES_PAGO | El movimiento no es del tipo esperado | proposal_create |
| CUE_GASTO_YA_ANULADO / CUE_PAGO_YA_REVERTIDO | Ya tiene anulación o reversión | proposal_create |
| CUE_PAGO_NO_CONFIRMADO | La reversión exige un pago confirmado | proposal_create |
| CUE_SOLO_AUTOR_O_ADMIN / CUE_SOLO_PARTES_DEL_PAGO | Quién puede pedirlo | proposal_create |
| CUE_PROPUESTA_DUPLICADA | Ya hay una propuesta abierta (0053) | proposal_create |
| CUE_PROPUESTA_VERSION | El hash no coincide con la versión actual | proposal_consent |
| CUE_PROPUESTA_NO_ABIERTA | La propuesta ya no está abierta | proposal_consent / cancel |
| CUE_NO_ES_PARTE | No es parte afectada por la propuesta | proposal_consent |
| CUE_YA_RESPONDIDO | Ya respondió esta propuesta | proposal_consent |
| CUE_FALTA_CLAVE / CUE_CLAVE_REUSADA | Idempotencia | payment_add |
| CUE_IMPORTE_INVALIDO | Importe o moneda inválidos | payment_add |
| CUE_DESTINATARIO_INVALIDO / CUE_DESTINATARIO_SIN_ACEPTAR / CUE_NO_ES_MIEMBRO | Destinatario no válido | payment_add, pair_* |
| CUE_PAGO_SUPERA_DEUDA / CUE_PAGO_SUPERA_CREDITO | El pago supera lo que se debe o lo que se tiene a favor | payment_add |
| CUE_PAGO_ANULADO / CUE_PAGO_YA_CONFIRMADO | Estado del pago | payment_confirm / cancel |
| CUE_GRUPO_ARCHIVADO | Grupo archivado | varias |
| CUE_GRUPO_NO_CERRADO | Primero hay que cerrar el grupo | group_archive |
| CUE_PAGOS_PENDIENTES | Hay pagos pendientes de confirmar | group_set_status |
| CUE_ESTADO_INVALIDO | Estado inválido | group_set_status |
| CUE_ELEGIR_OTRA_PERSONA | Cuenta compartida con uno mismo | pair_request |
| CUE_SOLICITUD_NO_PENDIENTE | La solicitud ya no está pendiente | pair_respond |
| CUE_TOPE_GRUPOS | Máximo de grupos activos por persona (100, configurable) | group_create, invite_accept (0051) |
| CUE_TOPE_INVITADOS | Máximo de invitados sin cuenta por grupo (50, configurable) | guest_add (0051) |
| CUE_NOMBRE_INVALIDO / CUE_MONEDA_INVALIDA / CUE_INVITADO_DUPLICADO | Validaciones de nombre y moneda | group_create, guest_add (0051) |
| CUE_INVITACION_INVALIDA / CUE_YA_VINCULADO_INVITADO | Invitación vencida o inválida | invite_accept (0051) |
| CUE_GRUPO_CON_HISTORIAL / CUE_GRUPO_CON_VINCULOS / CUE_GRUPO_CON_MIEMBROS | Un grupo solo se elimina si está vacío | group_delete (0054) |
| CUE_NO_ESTA_EN_PAPELERA / CUE_PAPELERA_VENCIDA | Restaurar fuera de la papelera o pasados los 30 días | group_restore (0054) |

**Qué falta (no cubierto):** el resto de las RPC de Cuentas (gastos, recurrentes, comprobantes, categorías, importación, etc.) siguen sin código. Decidir en qué etapa se completan.
**Configuración de topes:** tabla `cuentas.config` (`max_guests_per_group`, `max_groups_per_user`); se cambia con SQL en el servidor, sin pantalla.
**Probado:** en DEV con rollback (delegaciones, pagos, propuestas, cierre y archivo, topes, obsoleta, duplicada). **No probado:** reversas 0051–0053 (ver nota en el PR), concurrencia real, interfaz con los códigos.
