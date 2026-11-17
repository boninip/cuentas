# Cuentas · PRD V0.2 (borrador para revisión)

Fecha: 12/11/2026 · Actualizado 15/11/2026 (integra la adenda del 15/11 y la importación de Splitwise) · Estado: borrador de trabajo, NO oficial · Copia de la versión del documento en Docs

Este borrador junta el PRD de Cuentas V0.1, GF-17 y ADR-010 en un solo texto. Nada de lo nuevo es oficial hasta que lo apruebes; cada choque con el Core o la Arquitectura está marcado en la sección 7. Cuentas es el nombre nuevo de Gastos; las fuentes todavía dicen Gastos.

Estados usados: **Aprobada** (ya figura en un documento oficial), **Aprobada en conversación** (GF-17 y ADR-010, nunca cotejada con los documentos oficiales), **Aprobada por Pau (fecha)** (decisión explícita tuya en una conversación posterior), **Propuesta** y **Pendiente**.

Las decisiones y migraciones técnicas del 14/11 (miembros y pagos, delegaciones, propuestas y consentimientos, vínculos, datos de cobro, cuenta compartida) están detalladas en los anexos de decisiones del proyecto y no se repiten acá.

## 1. Alcance y límites

Cuentas es una app independiente de Pinto para administrar gastos compartidos, con identidad Verde Menta e Inicio V1 centrado en Grupos. Funciona sola y también vinculada a Juntada y Escapada.

- Es la única autoridad sobre movimientos, balances, liquidaciones y conversiones.
- Ningún rol de evento o viaje da acceso financiero, ni al revés.
- Juntada y Escapada guardan solo referencias, nunca copias editables de importes, deudas o pagos.
- Desvincular un evento o viaje no borra movimientos.
- Toda operación remota exige autorización, clave de idempotencia y conciliación.

## 2. Funcionalidad base (PRD V0.1, aprobada)

- Crear grupos financieros independientes e invitar participantes con la identidad e infraestructura de Pinto Core; las membresías financieras son propias de Cuentas.
- Registrar gastos y pagadores; dividir por partes iguales, importes específicos o porcentajes.
- Consultar balances, deudas y acreedores.
- Registrar pagos, liquidaciones e historial de movimientos.
- Soportar varias monedas (alcance acotado aprobado el 15/11, ver sección 6).
- Vincularse en ambos sentidos con Juntada y Escapada mediante referencias.

## 3. Vinculación con eventos y viajes (ADR-010)

Todas estas reglas son **Aprobadas en conversación**. El ADR-010 completo sigue siendo borrador y no está aprobado para implementación.

| ID | Regla | Observación |
| --- | --- | --- |
| ADR-010-01 | Un grupo de Cuentas se puede reutilizar entre eventos | Un evento vincula un solo grupo (C-04, resuelto) |
| ADR-010-02 | Visibilidad contextual por evento | Necesita contrato de consulta filtrada |
| ADR-010-03 | Desvincular un evento preserva historial y obligaciones | Coincide con el PRD V0.1 y el Core |
| ADR-010-04 | Incorporación asistida: invitaciones confirmadas, sin acceso automático | Coincide con ADR-004 |
| ADR-010-05 | Doble permiso para vincular (evento y Cuentas) | Coincide con ADR-005 (autorización bilateral) |
| ADR-010-06 | Eliminación lógica de evento con referencia histórica mínima | Regla de Cuentas aprobada; eliminar y restaurar queda pendiente en Juntada y Escapada (C-05) |
| ADR-010-07 | Un gasto en varios contextos: una sola obligación, referencias separadas | Sin duplicar deudas ni abrir la visibilidad de otro evento |
| ADR-010-08 | El administrador principal y el coadministrador con delegación expresa autorizan vincular | El rol se suma al Core (C-01, resuelto) |

### Roles y permisos de vinculación

| Permiso en el evento | Permiso en Cuentas | Resultado |
| --- | --- | --- |
| Organizador o coorganizador habilitado | Administrador principal | Vinculación directa si es la misma persona; si no, autorización bilateral |
| Organizador o coorganizador habilitado | Coadministrador con delegación vigente | Igual; delegación explícita, revocable y auditable |
| Organizador habilitado | Miembro común o no miembro | Solicitar aprobación financiera |
| Participante común | Administrador financiero | Solicitar autorización del evento |
| Invitado pendiente o exmiembro financiero | Cualquier rol | Sin facultad para nuevas vinculaciones |

Los permisos se revalidan al ejecutar. El permiso para invitar miembros (GF-02, documento que falta) no equivale al de vincular eventos.

## 4. Cuentas compartidas y compensaciones (GF-17)

GF-17 agrega cuentas compartidas de dos personas y compensaciones consensuadas. Las reglas son **Aprobadas en conversación**; GF-17 está aprobado en decisiones de producto, no para implementación técnica.

| Clave | Regla |
| --- | --- |
| 17-A01 | Cuenta compartida con compensación autorizada |
| 17-A02 | Cada compensación necesita el consentimiento individual de todas las personas afectadas |
| 17-A03 | Vinculación opcional, sugerida al crear el grupo o desde Participantes |
| 17-A04 | Exactamente dos integrantes por cuenta compartida |
| 17-A05 | Máximo una cuenta compartida activa por persona y grupo |
| 17-A06 | Cualquiera puede desvincularse sin permiso del otro; efecto inmediato para operaciones nuevas |
| 17-A07 | Desvincular no borra obligaciones, compensaciones aplicadas ni historial |
| 17-A08 | Revertir una compensación: la pide un afectado, la aprueban todos los afectados y queda un contramovimiento auditable |
| 17-A09 | Administrador y coadministrador no reemplazan el consentimiento individual |

Las claves 17-Axx son locales del documento GF-17; no son numeración oficial.

## 5. Invariantes financieros (GF-17 y ADR-010)

- La deuda original conserva titular, origen, moneda e historial; la cuenta compartida agrupa, no sustituye identidades.
- Un balance compartido en cero no equivale a liquidar las obligaciones individuales.
- No se registra un pago ficticio por una compensación: pago confirmado, compensación y corrección son cosas distintas.
- Un crédito no se consume dos veces ni por encima del saldo disponible; la operación es atómica e idempotente.
- Cada consentimiento se liga a una versión exacta de personas, obligaciones, importes y monedas; si algo cambia, hace falta aprobar de nuevo.
- Sin compensación automática entre monedas en V1. La liquidación con tipo de cambio explícito (GF-14, documento que falta) es otra operación.
- Los exmiembros ven solo sus obligaciones y las dependencias mínimas para entenderlas; los comprobantes tienen control de acceso propio.
- Grupo cerrado: sin gastos nuevos; las liquidaciones históricas continúan.
- Un gasto en varios contextos tiene un único asiento.

## 6. Lo que sigue abierto

Según el PRD V0.1, estas decisiones **no estaban aprobadas**; ADR-010 y GF-17 no las cierran. Estado al 15/11:

| Tema | Estado |
| --- | --- |
| Tipos de cambio | **Aprobado por Pau (15/11), alcance acotado:** la cotización se fija al cargar el gasto y es editable a mano; los saldos quedan en la moneda del gasto; la cotización solo se usa para totales y gráficos. Abierto: fuente automática, redondeo por moneda y liquidación entre monedas (GF-14, documento que falta) |
| Permisos financieros | **Aprobado por Pau (15/11), parcial:** categorías, pesos y responsables los cambian administrador y coadministrador (mismo permiso que invitar; delegable y auditable). La matriz completa sigue abierta |
| Precisión y redondeo por moneda | Abierto |
| Liquidaciones parciales, correcciones, anulaciones y reversión de pagos | Abierto |
| Archivo y eliminación de grupos, y conservación de historial | Abierto |
| Notificaciones específicas y escenarios de QA financieros | Abierto |

GF-18 (carga de comprobantes con OCR) es solo una propuesta; no tiene alcance aprobado y no se incluye en V0.2. La foto del comprobante sin OCR sí está en la sección 10.

## 7. Conflictos y cotejos (estado al 13/11/2026)

| ID | Tema | Qué dicen las fuentes | Estado |
| --- | --- | --- | --- |
| C-01 | Rol de coadministrador | El PRD Core (sección 7) solo lista administrador del grupo y participante financiero. ADR-010 agrega coadministrador con delegación | Resuelto: se suma al Core el rol de coadministrador, con delegación expresa, revocable y auditable |
| C-02 | Nombre «cuenta compartida» | Con el cambio de Gastos a Cuentas, «cuenta compartida» se confunde con el nombre de la app | Resuelto: se mantiene «cuenta compartida» |
| C-03 | Reversión con dependencias | GF-17 deja el algoritmo «por auditar»; ADR-010 la da por resuelta (coordinada, consentida y atómica) | Resuelto: queda pendiente hasta tener el diseño técnico; lo aprobado se mantiene (consentimiento de todos los afectados y contramovimiento) |
| C-04 | Cantidad de grupos por evento | ADR-010-01 permite reutilizar un grupo entre eventos; no dice si un evento puede tener varios grupos | Resuelto: un grupo por evento y varios eventos por grupo (falta confirmar lo mismo para los viajes de Escapada) |
| C-05 | Eliminación lógica de eventos | ADR-010-06 la presupone; el PRD de Juntada solo define cancelar y suspender, y no hay restauración | Resuelto para Cuentas: eliminar un evento nunca borra obligaciones, pagos ni historial. Eliminar y restaurar eventos queda pendiente en Juntada y Escapada |
| C-06 | Qué es un grupo cerrado | ADR-010 y GF-17 lo usan; el PRD V0.1 deja el archivo y la eliminación de grupos como pendiente | Resuelto: grupo cerrado = sin gastos nuevos; liquidaciones, pagos y reversiones anteriores continúan. Pendiente: quién puede cerrar, si se reabre, archivo y eliminación |
| C-07 | Notificaciones de consentimiento | GF-17 las marca como pendiente P1; el Core entrega notificaciones y cada dominio elige destinatarios | Resuelto: leer un aviso no es consentir; el consentimiento es una acción explícita, validada en servidor y ligada a la versión exacta. Pinto Core entrega y aplica preferencias; Cuentas decide destinatarios y guarda el consentimiento. Pendiente: qué avisos son esenciales |
| C-08 | Reglas «por ratificar» | GF-17 deja sin ratificar qué pasa con propuestas pendientes cuando alguien se desvincula | Resuelto: la propuesta se invalida y no se ejecuta sin reevaluar; para seguir se crea una propuesta nueva con el consentimiento de todos los afectados |
| C-09 | Documentos que faltan | GF-01 a GF-16, QA-F01 a 112 y la serie ADR-QA 01 a 72 se citan pero no están en el paquete | Abierto. Revisado el zip «Todos los archivos disponibles» (12/11): no aparecen. Los únicos localizados son GF-17 y ADR-010, idénticos a los ya leídos (mismo hash). Siguen pendientes: recuperar los originales desde los chats de ChatGPT o reconstruirlos con aprobación. Mientras tanto no se puede verificar la cobertura de QA |
| C-10 | IDs de QA | Conviven 17-Axx, QA-GF17-xx, ADR-QA-xx y QA-F-xx | Resuelto: prefijo de dominio (PIN, COR, JUN, ESC, CUE) + tipo (RF, QA, AC) + número, por ejemplo CUE-QA-001. Los IDs viejos no se renumeran; se mapean en una tabla de equivalencias |

## 8. QA

Las matrices de GF-17 (20 escenarios, QA-GF17-01 a 20) y de ADR-010 (13 criterios AC-01 a 13 y la serie ADR-QA 01 a 72) siguen siendo diseños locales, y el propio ADR-010 advierte que los rangos de referencia son orientativos. Las áreas P0 a cubrir primero son autorización (doble permiso, delegación, revocación en curso), participantes, finanzas (asiento único, reversión, concurrencia), privacidad entre eventos y sincronización (idempotencia, mensajes fuera de orden).

Pruebas ejecutadas hasta el 15/11, todas en DEV: pruebas de base de datos con rollback para las migraciones de Cuentas (por ejemplo categorías, pesos y responsables: 18 casos; gastos repetidos: 15; foto del comprobante: 13) y una prueba de pantalla con servidor simulado (`smoke.js`). No equivalen a la matriz de QA de arriba ni a una prueba con personas reales (ver sección 12).

## 9. Puerta para pasar a desarrollo

Ninguna de estas condiciones está cumplida hoy:

1. Cotejar GF-17 y ADR-010 con la Arquitectura, el Core y los PRDs oficiales (la sección 7 es el primer paso).
2. Resolver los bloqueantes P0: modelo de asientos y balance por moneda, redondeo, consentimiento verificable con versiones, concurrencia, idempotencia y reversión con dependencias.
3. Ratificar las reglas operativas que siguen como propuesta.
4. Aprobar el ADR-010 oficial con contratos, errores, versiones y reconciliación.
5. Aprobar la matriz de QA y la UX.

No se autoriza ningún cambio en GitHub ni en Supabase fuera de DEV. Las migraciones 0024 a 0028 están aplicadas solo en DEV y son propuestas.

## 10. Funcionalidad agregada el 15/11 (todo PROPUESTO salvo lo marcado)

1. **Categorías por grupo.** Siete base que se crean al primer uso (comida y bebida, transporte, alojamiento, salidas y ocio, hogar y servicios, compras y regalos, otros); se pueden crear, editar y ocultar (nunca borrar: los gastos viejos las conservan). Se sugieren solas al escribir la descripción (primero por el historial del grupo, después por palabras clave) y se pueden cambiar a mano. Decisión de Claude; no se puede apagar.
2. **Peso por miembro (familia).** **Aprobado por Pau (15/11):** adulto 1, niño/a ½, bebé 0 por defecto; configurable por miembro (0 a 5). Con pesos distintos, el reparto en partes iguales sale proporcional (el resto se asigna por mayor fracción). Un gasto con importes o porcentajes explícitos no cambia.
3. **Responsable de pago.** Un miembro (por ejemplo un hijo) puede tener un responsable; su saldo se suma al del responsable en Saldos. La deuda original conserva su titular: es una vista, no un asiento nuevo. Sin ciclos ni auto-asignación. Pendiente de definir y probar: cómo se saldan y pagan esas deudas en la práctica.
4. **Actividad del grupo.** Lista de lo que pasó (solo lectura sobre la auditoría), visible solo para miembros activos.
5. **Gastos repetidos (0027).** Alquiler, expensas, suscripciones: semanal o mensual, con fin opcional, pausa y terminar. Los genera el servidor al abrir el grupo, con clave única por ocurrencia (sin duplicados); cada uno es un gasto común del libro. Cualquier miembro activo crea; pausa o termina quien lo creó o la administración. Valores por defecto decididos por Claude. Concurrencia real sin probar.
6. **Foto del comprobante (0028).** Una foto por gasto, achicada a ~1 MB en el celular, en un bucket privado. **Aprobado por Pau (15/11):** la ven los miembros activos del grupo (no los ex miembros) y se conserva si el gasto se anula (libro append-only). Al editar un gasto la foto se vincula al nuevo. Sin OCR.
7. **Experiencia:** buscar y exportar movimientos (CSV), app instalable, y carga de gastos sin señal con envío automático después (solo alta de gastos, con la misma clave de idempotencia; no hay vista del grupo sin conexión).
8. **Importar de Splitwise (CSV).** Solo administración (decisión menor de Claude, configurable). Vista previa con emparejamiento de personas por nombre o alta como invitados, cotización por moneda extranjera (si falta, el gasto no se importa), hasta 500 gastos. No importa pagos («Payment»), gastos con varios pagadores, sin pagador o inválidos, y lo informa; por eso los saldos reflejan solo gastos. Idempotente por huella del archivo y línea. Sin migración nueva (usa `cuentas_expense_add`).

## 11. Contratos nuevos para el ADR-010 (borrador, propuestos)

| RPC | Entrada | Salida | Permiso |
| --- | --- | --- | --- |
| `cuentas_categories_list(p_group)` | grupo | lista de categorías (crea las base si no hay) | miembro activo |
| `cuentas_category_save(p_group,p_key,p_name,p_icon,p_color)` | clave nula = crear | clave | invitar |
| `cuentas_category_archive(p_group,p_key,p_archived)` | — | — | invitar |
| `cuentas_member_set_weight(p_group,p_user,p_weight)` | 0 a 5 | — | invitar |
| `cuentas_member_set_guardian(p_group,p_user,p_guardian)` | nulo = sin responsable | — | invitar; rechaza ciclos y auto-asignación |
| `cuentas_expense_add` / `cuentas_expense_edit` | suman `p_category`, `p_fx` al final | — | sin cambios; `p_fx` se rechaza si la moneda es la del grupo o ≤ 0 |
| `cuentas_recurring_save(...)` / `_list` / `_set_status` / `_run` | regla (frecuencia, inicio, fin) | `_run` devuelve cuántos gastos generó | miembro activo; pausar o terminar: quien creó o administración |
| `cuentas_receipt_register(p_movement,p_size)` / `_copy(p_from,p_to)` / `cuentas_receipts_list(p_group)` | foto subida a `grupo/gasto.jpg` en el bucket `cuentas-receipts` | ruta / lista | miembro activo |
| `cuentas_activity_list(p_group,p_limit)` | límite máx. 100 | acción, quién, monto, descripción, persona afectada, peso | miembro activo |

Errores y versionado de estos contratos: sin definir (puerta 4 sin cumplir).

## 12. Qué no está probado

Dos personas reales contra Supabase desde celulares, TalkBack, reclamar un invitado con un link real, instalar la app, el envío de la cola sin señal contra el servidor real, el flujo de saldar deudas de un miembro con responsable, la subida y bajada de fotos por la API real de Storage, la concurrencia de gastos repetidos, y la importación con un CSV real de Splitwise.
