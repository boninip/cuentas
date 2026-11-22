# Revisión estática de permisos de Cuentas (B5) · avance del 16/11/2026 (PROPUESTA)

Estado: **revisión estática, NO es prueba ejecutada.** Solo lectura en DEV (Pinto Core, `sswgtcpaayisecwxxskp`). No se cambió nada. Equivalencias: Planazo = Pinto, Gastos = Cuentas. Referencia: matriz por rol aprobada por Pau el 15/11 (A3) y reglas de oro del Proyecto.

## Alcance y límites
- Inventario de las **56 funciones públicas `cuentas_*`**: qué ayudantes de autorización invoca cada una (`cuentas.can`, `cuentas.is_active_member`, verificación de rol directa).
- Lectura en detalle de las líneas de autorización de **24 funciones** (el cuerpo completo solo de `cuentas_expense_edit`). Se leyeron completas las definiciones de `cuentas.can`, `is_active_member`, `eff` y `eff_pay`.
- **Falta leer** (aún solo por inventario): `expense_void`, `group_set_status`, `guest_*`, `invite_*`, `member_set_guardian`, `member_set_weight`, `pair_request`, `pair_respond`, `compensation_*`, `proposal_consent`, `proposal_create`, `category_*`, `group_create`, `group_get`, `group_payouts`, `balances`, `movements_list`, `my_groups*`, `my_pending`, `receipts_list`, `recurring_list`, `cuentas_payout_*` (cuerpo).
- Esto no reemplaza la prueba por rol ejecutada en DEV (etapa 1 del plan).

## Cómo decide la autorización hoy
- `cuentas.can(grupo, usuario, alcance)`: verdadero si es **admin activo**, o **coadmin activo con delegación vigente** que incluya ese alcance.
- Los alcances delegables son solo cuatro (`invite`, `close`, `void`, `link`); `cuentas_delegate_grant` rechaza cualquier otro. Por eso `can(..., '__admin__')` solo se cumple para el admin: así `cuentas_group_archive` queda reservada a la administración principal.
- `cuentas.is_active_member`: miembro con estado `active`.

## Resultado por tipo de regla (lo leído)
| Regla | Funciones |
| --- | --- |
| Solo administración principal | `delegate_grant`, `delegate_revoke`, `member_remove`, `group_archive` (alcance `__admin__`) |
| Admin o coadmin con alcance `void` | `expense_void`, `payment_cancel`, `proposal_create` |
| Admin o coadmin con alcance `close` | `group_set_status` |
| Admin o coadmin con alcance `invite` | `invite_create`, `guest_add`, `guest_remove`, `guest_invite_create`, `category_save`, `category_archive`, `member_set_weight`, `member_set_guardian`, `recurring_set_status` (o quien creó la regla) |
| Solo el autor o la persona involucrada | `proposal_cancel` (autor), `payment_confirm` (destinatario), `pair_end` (integrantes del par), `payment_cancel` (autor solo si no está confirmado) |
| Cualquier miembro activo | `expense_add`, `recurring_save`, `recurring_run`, `receipt_register`, `receipt_copy`, listas de lectura |
| Solo ex miembro con deuda | `exmember_payees` |

## Observaciones
Ninguna es un fallo comprobado. Son puntos a confirmar.

1. **El alcance `invite` cubre siete acciones distintas** (invitar, invitados, categorías, pesos, responsables, estado de gastos repetidos). La matriz aprobada dice que el coadmin edita categorías, pesos y responsables «según permisos delegados»: hoy eso exige el alcance `invite`, y un coadmin con solo `void` o `close` no puede. Decisión menor mía: dejarlo como está y documentarlo. Un alcance propio sería una migración: solo si Pau lo pide.
2. **`cuentas_expense_edit` es segura por composición:** anula con `expense_void` (autor o alcance `void`) y carga con `expense_add` (miembro activo y grupo abierto) en la misma transacción; si cualquiera falla, todo se revierte.
3. **Pagos:** `payment_add` admite a quien figure en el grupo aunque ya no esté activo (es el diseño de la 0015: ex miembro paga su deuda), no bloquea el grupo cerrado (coincide con la regla: los pagos continúan) y bloquea el archivado. `payment_cancel` cumple A1: administración siempre; el autor solo antes de la confirmación.
4. **Comprobantes:** cualquier miembro activo puede adjuntar un comprobante a un gasto del grupo, no solo su autor. **No lo cotejé** con la regla aprobada de la foto del ticket: hay que contrastarla con ese documento.
5. **Actividad:** `activity_list` muestra a cualquier miembro activo toda la auditoría del grupo. La matriz no lo define: pregunta menor para Pau (¿todos ven todo?).
6. **Gastos repetidos:** `recurring_run` lo puede disparar cualquier miembro activo, bloquea las reglas con `FOR UPDATE` y usa clave idempotente `rec-<regla>-<fecha>` bajo el índice único (grupo, autor, clave). Estático: protege contra duplicados. **Sin prueba concurrente ejecutada.**
7. **`cuentas_payout_*`** (alias y CBU propios): solo vi el control de sesión; falta confirmar que filtran por `auth.uid()`.

## Asesores de Supabase (DEV, solo lectura, 16/11 ~00:35)
Seguridad:
- Ninguna función de Cuentas ni `core_link_*` es ejecutable por `anon`. Las que sí lo son son `juntada_*` y `planazo_invite_preview`, ya conocidas (código secreto por diseño; la segunda se retira con la 0033).
- 103 funciones `SECURITY DEFINER` ejecutables por `authenticated`: es el diseño (todo pasa por RPC con validación interna).
- 28 tablas con RLS y sin políticas: a propósito (sin acceso directo).
- Protección contra contraseñas filtradas **sigue desactivada** (la activa Pau).
- No aparece `function_search_path_mutable`.

Rendimiento:
- 45 claves foráneas sin índice. Las que tocan lecturas de Cuentas: `audit_log.group_id`, `proposals.group_id`, `invites.group_id`, `movement_attachments.group_id`, `movements` (`created_by`, `from_user`, `to_user`), `members.user_id`, `movement_shares.user_id`. **A medir con volumen antes de proponer índices.**
- 3 políticas de `core.pinto_profiles` y 2 de `planazo_*` reevalúan `auth.uid()` por fila (arreglo chico: `(select auth.uid())`); no es una migración autorizada.
- Índices sin uso y políticas permisivas múltiples: casi todo en Juntada y Escapada, no en Cuentas.

## Siguiente
Terminar de leer las funciones pendientes y armar la tabla función × rol para ejecutarla en DEV con rollback (etapa 1 del plan). Sin cambios en Supabase.
