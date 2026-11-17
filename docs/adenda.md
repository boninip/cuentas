# Adenda 15/11/2026 al PRD de Cuentas V0.2 y al ADR-010 (borrador)

Estado: adenda de trabajo, NO oficial. Complementa `Cuentas_PRD_V0_2_borrador.md` (12/11) sin reemplazarlo: ese documento no se reescribió; esta adenda dice qué cambia o se suma. Detalle técnico y pruebas en `Pinto_Registro_decisiones_2026-11-15_anexo_Cuentas_0024_a_0026_y_UI.md`. Todo en DEV.

## Cambios a la sección 6 («Lo que sigue abierto»)
| Tema | Antes | Ahora |
| --- | --- | --- |
| Fuente, fecha y fijación del tipo de cambio | Abierto | **Aprobado por Pau (15/11), alcance acotado:** la cotización se fija al cargar el gasto y es editable a mano; los saldos quedan en la moneda del gasto; la cotización solo se usa para totales y gráficos. Sigue abierto: fuente automática, redondeo por moneda y liquidación entre monedas (GF-14, documento que falta) |
| Matriz de permisos financieros | Abierto | Se suma, **aprobado por Pau (15/11):** categorías, pesos y responsables los cambian administrador y coadministrador (mismo permiso que invitar; delegable y auditable). La matriz completa sigue abierta |

## Funcionalidad nueva propuesta (todas PROPUESTAS salvo lo marcado como aprobado)
1. **Categorías por grupo.** Siete base que se crean al primer uso (comida y bebida, transporte, alojamiento, salidas y ocio, hogar y servicios, compras y regalos, otros); se pueden crear, editar y ocultar (nunca borrar: los gastos viejos las conservan). La categoría se sugiere sola al escribir la descripción (primero por el historial del grupo, después por palabras clave) y se puede cambiar a mano. Decisión de Claude, sin preguntar; no se puede apagar.
2. **Peso por miembro (familia).** **Aprobado por Pau (15/11):** adulto 1, niño/a ½, bebé 0 por defecto; configurable por miembro (0 a 5). Con pesos distintos, el reparto en partes iguales sale proporcional (el resto se asigna por mayor fracción). Un gasto con importes o porcentajes explícitos no cambia.
3. **Responsable de pago.** Un miembro (por ejemplo un hijo) puede tener un responsable; su saldo se suma al del responsable en Saldos. La deuda original conserva su titular: es una vista, no un asiento nuevo. Sin ciclos ni auto-asignación. Pendiente de definir y probar: cómo se saldan y pagan esas deudas en la práctica.
4. **Actividad del grupo.** Lista de lo que pasó (solo lectura sobre la auditoría), visible solo para miembros activos.
5. **Gastos repetidos (0027).** Alquiler, expensas, suscripciones: semanal o mensual, con fin opcional, pausa y terminar. Los genera el servidor al abrir el grupo, con clave única por ocurrencia (sin duplicados); cada uno es un gasto común del libro. Cualquier miembro activo crea; pausa o termina quien lo creó o la administración. Valores por defecto decididos por Claude sin preguntar. No probada la concurrencia real.
6. **Foto del comprobante (0028).** Una foto por gasto, achicada a ~1 MB en el celular, en un bucket privado. **Aprobado por Pau (15/11):** la ven los miembros activos del grupo (no los ex miembros) y se conserva si el gasto se anula (libro append-only, sin borrado). Al editar un gasto la foto se vincula al nuevo. Sin OCR (GF-18 sigue como propuesta sin alcance aprobado).
7. **Experiencia:** buscar y exportar movimientos (CSV), app instalable, y carga de gastos sin señal con envío automático después (solo alta de gastos, con la misma clave de idempotencia; no hay vista del grupo sin conexión).

## Contratos nuevos para el ADR-010 / contratos (borrador, propuestos)
| RPC | Entrada | Salida | Permiso |
| --- | --- | --- | --- |
| `cuentas_categories_list(p_group)` | grupo | lista de categorías (crea las base si no hay) | miembro activo |
| `cuentas_category_save(p_group,p_key,p_name,p_icon,p_color)` | clave nula = crear | clave | invitar |
| `cuentas_category_archive(p_group,p_key,p_archived)` | — | — | invitar |
| `cuentas_member_set_weight(p_group,p_user,p_weight)` | 0 a 5 | — | invitar |
| `cuentas_member_set_guardian(p_group,p_user,p_guardian)` | nulo = sin responsable | — | invitar; rechaza ciclos y auto-asignación |
| `cuentas_expense_add` / `cuentas_expense_edit` | suman `p_category`, `p_fx` al final | — | sin cambios; `p_fx` se rechaza si la moneda es la del grupo o ≤ 0 |
| `cuentas_recurring_save(...)` / `_list` / `_set_status` / `_run` | regla (frecuencia semanal o mensual, inicio, fin) | `_run` devuelve cuántos gastos generó | miembro activo; pausar o terminar: quien creó o administración |
| `cuentas_receipt_register(p_movement,p_size)` / `_copy(p_from,p_to)` / `cuentas_receipts_list(p_group)` | foto subida a `grupo/gasto.jpg` en el bucket `cuentas-receipts` | ruta / lista | miembro activo |
| `cuentas_activity_list(p_group,p_limit)` | límite máx. 100 | acción, quién, monto, descripción, persona afectada, peso | miembro activo |

Errores y versionado de estos contratos: sin definir (puerta 4 de la sección 9 sigue sin cumplirse).

## Puerta para pasar a desarrollo (sección 9)
Sin cambios: ninguna condición está cumplida. Las migraciones 0024 a 0026 están aplicadas solo en DEV y son propuestas; no se autoriza cambio alguno en producción.

## Qué no está probado
Dos personas reales contra Supabase desde celulares, TalkBack, reclamar un invitado con un link real, instalar la app, el envío de la cola sin señal contra el servidor real, y el flujo de saldar deudas de un miembro con responsable, y la subida y bajada de fotos por la API real de Storage.
