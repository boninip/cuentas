# Permisos de Cuentas (B5) · resultado del 19/11/2026 (PROPUESTA)

Equivalencias: Gastos = Cuentas. Solo DEV (Pinto Core, `sswgtcpaayisecwxxskp`). Reemplaza al avance del 16/11. Estado: **propuesta, sin aprobar**. No se cambió nada en Supabase ni en GitHub; las pruebas se corrieron en una transacción que termina en error a propósito (rollback) y después se verificó que no quedó ningún residuo.

## 1. Qué se hizo
- **Revisión estática de las 56 funciones públicas `cuentas_*`** (las 56 leídas; antes 24), más `cuentas.can`, `balances_raw`, `apply_proposal`, `comp_has_dependents` y los índices únicos de movimientos, propuestas y cuentas compartidas.
- **Prueba ejecutada por rol, 63 comprobaciones, todas pasaron.** Roles: administración, coadmin con solo `void`, con solo `invite`, con solo `close`, miembro, ex miembro y ajeno al grupo. Grupo abierto, cerrado y archivado. Cada negativa tiene su control positivo (por ejemplo, el miembro sí puede cargar un gasto), para que un «rechazado» no sea un error de la prueba.
- **Privilegios, ejecutada (consulta de solo lectura):** `anon` y `authenticated` no tienen uso del esquema `cuentas` ni permisos sobre ninguna tabla; todas las tablas tienen RLS; las 56 funciones son `SECURITY DEFINER` con `search_path` vacío, ejecutables solo por `authenticated`.

## 2. Resultado: ningún hueco de autorización comprobado
| Regla | Prueba ejecutada |
| --- | --- |
| Solo la administración delega; el coadmin no delega ni usa un alcance inválido | delegate_grant: miembro, coadmin y alcance `__admin__` rechazados |
| Anular gasto: autor, administración o coadmin con `void` | otro miembro, coadmin con `invite` y ajeno rechazados; coadmin con `void` y autor aceptados |
| Categorías, invitaciones, invitados, pesos, responsables: administración o coadmin con `invite` | miembro, coadmin con `void` y ajeno rechazados |
| Cerrar: administración o coadmin con `close`; reabrir y archivar: solo administración | miembro y coadmin sin `close` no cierran; coadmin no reabre ni archiva |
| Archivar exige cerrar primero | rechazado con el grupo abierto |
| Grupo cerrado: no admite gastos nuevos; pagos y consentimientos siguen | expense_add rechazado; payment_add y proposal_consent aceptados |
| Grupo archivado: nada nuevo | gasto, pago, reabrir e invitar rechazados |
| Lecturas (saldos, movimientos, actividad, grupo, comprobantes, propuestas, delegaciones, cuentas de cobro) | ajeno y ex miembro rechazados en todas; miembro acepta |
| Pagos: confirma solo el destinatario; cancelar tras confirmar solo la administración | quien pagó, ajeno y tercero rechazados |
| Propuestas: solo los afectados consienten; versión exacta; solo autor o administración las piden | no afectado, hash viejo y ajeno rechazados |
| Carga de gasto: pagador y participantes deben ser miembros activos | ajeno, ex miembro, pagador ajeno y participante ajeno rechazados |
| Cuenta compartida: una persona no queda en dos pares | segundo par rechazado (mi sospecha estática, por la forma de los índices, **quedó refutada**) |
| Cobro propio (`payout_*`) | filtra por `auth.uid()`; resuelve el punto 7 del avance |

## 3. Observaciones (ninguna es un hueco de seguridad comprobado)
1. **Propuesta aprobada sobre algo que ya se anuló o revirtió (P2, estática):** `apply_proposal` no revisa si el objetivo ya tiene su anulación o reversión. El índice único `movements_one_followup` evita el doble movimiento (los saldos no se corrompen), pero el que consiente recibe un error crudo de base de datos, el consentimiento se deshace y la propuesta queda abierta. **Corrección propuesta:** marcarla «obsoleta» (`stale`) como ya se hace con las compensaciones. Entra en la migración de códigos `CUE_*`.
2. **Invitados sin tope (P1, estática):** `cuentas_guest_add` crea usuarios en `auth.users` sin límite por grupo; un administrador o coadmin con `invite` podría crear miles. **Propuesta:** tope configurable (por defecto 50 por grupo) y que `guest_remove` respete el archivado.
3. **Grupos sin tope por persona (P2, estática):** cualquier usuario puede crear grupos sin límite. **Propuesta:** tope configurable.
4. **El alcance `invite` cubre siete acciones** (invitar, invitados, categorías, pesos, responsables, gastos repetidos y su estado). Decisión mía: se deja como está y queda documentado (matriz aprobada: «según permisos delegados»).
5. **Comprobantes:** cualquier miembro activo puede adjuntar y ver el comprobante de cualquier gasto del grupo. Falta cotejarlo con la regla aprobada de la foto del ticket (documento no localizado: GF-18).
6. **Actividad:** todos los miembros ven toda la auditoría del grupo. La matriz no lo define. **Pregunta menor para Pau.**
7. **Anular un gasto con el grupo cerrado:** está permitido (coincide con «las reversiones anteriores continúan»). No lo probé con el grupo cerrado; entra en la próxima corrida.
8. **Mensajes de error** distintos para lo mismo («No autorizado», «No sos miembro de este grupo», «Iniciá sesión»): la interfaz no puede distinguir; es el motivo de la migración `CUE_*` (Q4).
9. **Cuentas de cobro compartidas:** quien activa «compartir» expone alias y CBU a todos los miembros activos. Es el diseño; la interfaz lo dice.

## 4. No probado
- Concurrencia real (dos llamadas a la vez): la herramienta usa una sola sesión por llamada. Evidencia estática de bloqueos e índices únicos; la prueba paralela necesita tu autorización (ver plan, ítem 5).
- Gastos repetidos (`recurring_*`), comprobantes con Storage real, `pair_*` y `compensation_*` más allá de lo indicado, invitaciones por enlace con un usuario real.
- Cliente: la interfaz no es barrera de seguridad; no se probó con un cliente real distinto del propio.
- Un ataque dirigido (fuzzing); esto es una matriz de roles, no una auditoría de penetración.

## 5. Decisiones de Pau (19/11/2026)
- **Aprobado: todos los miembros ven toda la actividad del grupo** (como hoy). Se anota en la matriz; sin cambios en el servidor.
- **Aprobado: topes por defecto de 50 invitados por grupo y 100 grupos por persona, configurables.** Queda por redactar (migración propuesta con reversa, entra junto con los códigos `CUE_*` y la corrección de la observación 1). **Aplicarla en DEV necesita tu orden expresa.**

## 6. Documentos a actualizar
Checklist V1.0 de Cuentas (B5 hecho en lo estático y en la matriz por rol), plan de cierre (ítem 3), `Pinto_Revision_estatica_permisos_Cuentas_B5_avance.md` (queda reemplazado), ADR-010 (el caso `stale` sin código), tabla de QA (cuando se recuperen los IDs).
