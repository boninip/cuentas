# Plan para cerrar la 1.0 de Cuentas (PROPUESTA)

Fecha: 16/11/2026 · Estado: **propuesta, NO aprobada**. Es solo un plan: no ejecuta nada en GitHub ni en Supabase, no mergea, no usa claves. Todo en DEV (Pinto Core, `sswgtcpaayisecwxxskp`). Equivalencias: Planazo = Pinto, Gastos = Cuentas.

## 0. Qué leí y qué falta

**Leído:** checklist V1.0 de Cuentas, equivalencias y pendientes, anexo del vínculo bilateral, anexo de pruebas C / 0036 / reversa por dominio, y además la adenda 2 del PRD, el ADR-010 propuesto y el prompt de cierre.

**No leí (no lo completo de memoria):** el PRD de Cuentas V0.2 base (solo vi su §3 a través de la adenda 2), la Arquitectura Maestra V1.1 y la Matriz Maestra V1.1.

**Faltan en el Proyecto** (los trae Pau): GF-01 a 16, QA-F01 a 112, ADR-QA 01 a 72 e INT07 V6.1.

**Lecturas que hice hoy en DEV, solo lectura, sin cambios:** lista de migraciones, inventario de las 56 funciones `cuentas_*` y de las `core_link*`, e índices de las tablas del vínculo, del libro y de la auditoría.

### Inconsistencias entre documentos (a corregir en la etapa 0)
| Dónde | Dice | Realidad verificada |
| --- | --- | --- |
| Anexo de pruebas C / 0036 | 0036 «NO aplicada» | **Aplicada en DEV** (aparece en la lista de migraciones, junto con la 0037) |
| Adenda 2 §3 | Grupo cerrado «no probado»; vencimiento «sin entrada de auditoría» | Quedó resuelto: 0037 bloquea el vínculo en grupo cerrado (decisión de Pau, 16/11, probada con rollback, 7 comprobaciones) y 0036 audita el vencimiento (7 comprobaciones) |
| Checklist de Cuentas B7 | Paquete de producción de 42 migraciones y «faltan reversas de 22» | Equivalencias: 44 migraciones (con 0036 y 0037); reversa **por dominio** ya decidida (27) y probada con rollback |
| Checklist de Cuentas B2, B4 y B10 | No mencionan 0036, 0037 ni 0038 | Sumarlas; B10 ya tiene fuente para vencida e invalidada (historial) |

### Novedades del Core (16/11, ~09:15) que cambian este plan
Verificado hoy en DEV, solo lectura: `core_link_requests_history(p_group, p_days)` y `core_links_list(p_group)` existen, son `SECURITY DEFINER`, ejecutables solo por `authenticated` (no por `anon`), y la migración 0038 figura aplicada. **No repetí las 10 comprobaciones de prueba del Core**; las tomo como informadas por el chat de Core.
- **Historial de solicitudes** (0038): devuelve aprobadas, rechazadas, canceladas, vencidas e invalidadas de los últimos 30 días (máx. 90, tope 100), sin hash. Antes la interfaz no tenía de dónde sacar «vencida» e «invalidada»: ahora sí. Decisión menor mía: la interfaz pide **7 días** (`p_days = 7`), coherente con mi nota de mostrar las vencidas 7 días más, solo lectura.
- **`core_links_list`** suma `in_trash` (evento o viaje en la papelera). La interfaz debe mostrarlo («en la papelera») sin romper las claves existentes. Un vínculo cuyo evento está en la papelera **no se desvincula solo**: el historial y las obligaciones se conservan.
- **`LNK_GRUPO_CERRADO`** al solicitar o vincular directo; aprobar con el grupo ya cerrado devuelve `invalidated` (no un error).
- **ADR-010 con catálogo de códigos:** el texto final propuesto ya está en el Proyecto; queda pendiente que lo apruebes. El prefijo de Cuentas es `CUE_*`; su catálogo lo tengo que redactar (Q4 aprobada). `core_link_create`, `core_link_remove` y `core_link_for_ref` todavía lanzan errores sin código.
- El pedido de Cuentas al Core (historial para vencida e invalidada) **queda resuelto**.

## 1. Lista ordenada de lo que falta para la 1.0

Tamaño: chico (menos de medio día), medio (alrededor de un día), grande (varios días). «Verifica» distingue prueba **ejecutada** (en DEV, con rollback salvo que se indique) de revisión **estática**.

| # | Ítem | Quién | Tamaño | Lo bloquea | Cómo se verifica |
| --- | --- | --- | --- | --- | --- |
| 1 | Responder las definiciones Q1 a Q5 (sección 2) | Pau | chico | — | Quedan registradas como «aprobado» en el anexo |
| 2 | Corregir las inconsistencias de la tabla de arriba y marcar B2/B4/B7 en el checklist | Yo | chico | — | Estático: relectura cruzada de los documentos |
| 3 | **B5. Revisión de la matriz de permisos financieros** en cada función `cuentas_*` (56). Primero estática, función por función; después ejecutada por rol (miembro, coadmin con y sin delegación, admin, ex miembro, ajeno, invitado, responsable de otro) | Yo | grande | — | Estática: tabla función × rol con la línea de código que valida. Ejecutada: script de rollback que prueba cada combinación y espera error |
| 4 | **B10. Interfaz del vínculo bilateral en Cuentas** (alcance aprobado en Q3). Usa `core_link_requests_list` (pendientes), `core_link_requests_history` con `p_days=7` (vencidas, invalidadas, rechazadas, canceladas), `core_link_request_decide`, `core_link_request_cancel`, `core_link_request_create` (solo para lo que ya organiza) y `in_trash` de `core_links_list` | Yo | grande | Ítem 3 en lo que toque permisos | Ejecutada: smoke de UI con servidor simulado. Real: ítem 18 |
| 5 | Prueba de **dos aprobaciones simultáneas** del vínculo (y dos solicitudes simultáneas) | Yo | medio | Autorización de Pau si deja datos confirmados en DEV (ver sección 3) | Ejecutada: dos llamadas paralelas; resultado esperado: una aprueba, la otra recibe `LNK_NO_PENDIENTE`, un solo vínculo activo |
| 6 | Códigos de error estables (ADR-010 P1) en las RPC de Cuentas que la interfaz necesita distinguir (según Q4) | Yo | medio | Q4 (hoy **no autorizado**) | Ejecutada: rollback que provoca cada error y lee el `DETAIL`. La UI deja de comparar textos |
| 7 | Archivo y eliminación de grupos (Q1 aprobada: archivar siempre; eliminar solo grupos vacíos, con papelera de 30 días) | Yo | medio | Autorización de Pau para aplicar la migración en DEV | Ejecutada: rollback; el historial nunca se borra |
| 8 | **B9. Aviso esencial por correo**: configurar SMTP propio y una función de envío | Pau (autoriza y configura); yo la escribo | medio | Q5; autorización expresa de Pau; SMTP | Ejecutada: un correo de prueba a una casilla de Pau |
| 9 | Probar los **disparadores de avisos de propuestas** (hoy creados pero sin ejecutar) | Yo | chico | — | Ejecutada, con rollback |
| 10 | **E. Revisión de arquitectura y rendimiento** (sección 5 de este plan) | Yo | grande | — | Estática primero; después medición con datos sintéticos en transacción con rollback |
| 11 | Repetir el asesor de seguridad y el de rendimiento de Supabase (después de 0036 y 0037) | Yo | chico | — | Ejecutada: lectura de advisors; sin cambios |
| 12 | Pruebas de regresión de UI: sumar casos del vínculo, grupo cerrado, vencida e invalidada | Yo | medio | Ítem 4 | Ejecutada: `smoke.js` en «todo ok» |
| 13 | Actualizar documentos (sección 6) | Yo; Pau aprueba | medio | Aprobaciones de Pau | Estático |
| 14 | Recuperar GF-01 a 16, QA-F01 a 112, ADR-QA 01 a 72 | Pau | medio | — | Aparecen en el Proyecto; después armo la tabla de equivalencias |
| 15 | Aprobar el texto final del ADR-010 | Pau | chico | — | Registro de decisión |
| 16 | Revisar migraciones 0024 a 0030 y 0036 y 0037 antes de salir de DEV | Pau | medio | — | Registro de decisión |
| 17 | Plan de paso a producción: dejar listo el paquete (con 0036 y 0037), y la prueba en una base descartable cuando Pau la autorice | Yo prepara; Pau autoriza | medio | Autorización y posible costo | Hoy **nunca ejecutado**; la prueba lo verifica |
| 18 | **Pruebas en celulares reales** (sección 3) | Pau, con capturas | grande | Ítems 4, 7, 9 | Capturas y registro |
| 19 | Merge: PR #1 de `cuentas`, y los de `pinto-core` (#15 a #18) | Pau (solo con «mergeá») | chico | Todo lo anterior en verde | Orden de merge: Core, Cuentas, Juntada, Escapada |

**Fuera de la 1.0, anotado** (no incluye OCR, cotización automática ni liquidar entre monedas: entran por Q2): retiro de `juntada_gastos_*` (después de la 1.0 de las tres apps), 0033 (retiro de `planazo_groups`), renombre de RPC públicas, outbox de eventos (P4), importar gastos viejos de Juntada.

## 2. Preguntas de definición para Pau (de a una, por prioridad)

**Q1. Archivo y eliminación de grupos** (A2 abierto). **APROBADA por Pau el 16/11: «Archivar siempre; eliminar solo vacíos».** Detalle que decido yo (configurable): papelera de 30 días; un grupo con gastos o pagos nunca se elimina. Texto original de la pregunta: Hoy existen `cuentas_group_archive` y `cuentas_group_set_status` en DEV; no leí qué hace cada una al detalle.
- Recomendada: **archivar siempre** (reversible, el grupo sale de la lista y conserva todo); **eliminar solo grupos sin gastos ni pagos**, con papelera de 30 días configurable; un grupo con historial nunca se elimina.
- Otras: solo archivar, sin eliminar; permitir eliminar todo con papelera.

**Q2. Alcance de la 1.0.** **APROBADA por Pau el 16/11, distinta de mi recomendación: «Entran las 3»** (OCR de comprobantes, liquidar entre monedas y cotización automática entran en la 1.0). Mi recomendación era dejarlos fuera; queda registrado el cambio y sus consecuencias en la sección 2b.
- Recomendada: **confirmar que quedan fuera.**

**Q3. Alcance de la interfaz del vínculo en Cuentas.** **APROBADA por Pau el 16/11: ver pendientes, aprobar, rechazar, cancelar las propias, mostrar vencida e invalidada, manejar grupo cerrado, y solicitar solo para eventos o viajes que ya organiza.** Solicitar a un evento ajeno queda fuera de la 1.0. Texto original:
- Recomendada: **ver pendientes, aprobar, rechazar, cancelar las propias, mostrar vencida e invalidada, y solicitar solo cuando quien lo pide ya organiza el evento o viaje** (lo que ya ofrece la lista de organizables). Las solicitudes que arrancan del lado de Cuentas hacia un evento ajeno quedan para después.
- Otra: también permitir solicitar a un evento ajeno pegando un enlace o código. Requiere que cada app exponga el identificador del evento, y hoy no sé cómo se obtendría; lo preguntaría al chat de Juntada y al de Escapada.

**Q4. Códigos de error estables en Cuentas.** **APROBADA por Pau el 16/11: solo las RPC críticas (pagos, cierre, propuestas, delegaciones y vínculos), con reversa.** Autoriza a redactar la migración; aplicarla en DEV sigue necesitando tu orden expresa. Texto original: El ADR-010 P1 está aprobado, pero aplicarlo al resto de las RPC **no está autorizado**.
- Recomendada: **autorizar solo las RPC de pagos, cierre, propuestas, delegaciones y vínculos** (las que la UI necesita distinguir), con reversa.
- Otras: todas las RPC de Cuentas; o después de la 1.0.

**Q5. Correo en la 1.0.** **APROBADA por Pau el 16/11: la 1.0 sale con el aviso en la app y el correo se enciende después**, cuando haya SMTP y se autorice la función de envío. No bloquea el cierre. Texto original: El canal «app + correo» está aprobado, pero el correo depende de SMTP propio y de una función de envío que debés autorizar.
- Recomendada: **la 1.0 sale con el aviso en la app y el correo se enciende cuando haya SMTP**, sin bloquear el cierre. Los avisos esenciales quedan siempre visibles en Actividad.
- Otras: bloquear la 1.0 hasta que el correo funcione.

## 2b. Consecuencias de Q2 («entran las 3»)

Esto agranda la 1.0: son tres piezas grandes y cada una necesita su definición antes de construirse. Lo que decido yo (cambiable): se construyen **al final de las etapas, detrás de interruptores configurables**, para que un problema en una no frene el resto del cierre.

| Pieza | Qué hay hoy | Lo que falta definir (se pregunta a Pau, de a una) | Riesgo principal |
| --- | --- | --- | --- |
| Cotización automática | Cotización fija y editable a mano por gasto (aprobada el 15/11) | Cómo se usa (precargada y editable, u obligatoria); de dónde sale; cada cuánto; qué pasa si falla la fuente | Fuente externa: disponibilidad y costo. **Si una fuente requiere clave, la configurás vos como secreto en el panel y yo no la veo ni la uso** |
| Liquidar entre monedas | Un pago es en una sola moneda; no se admite crédito a favor ni pagar de más | Cómo se salda una deuda en otra moneda: con qué cotización, quién la fija, cómo queda en el libro y en los saldos, qué pasa al anular | **P0:** toca saldos y redondeo, y Cuentas es la única autoridad de saldos. Un error de cálculo es un error de plata |
| OCR de comprobantes | Foto del ticket guardada en Storage, sin lectura de texto | Qué se extrae (importe, fecha, comercio); si se lee en el aparato o en un servicio; qué se hace si no coincide; privacidad de las fotos | Privacidad de datos personales en los tickets; precisión; costo si es un servicio externo |

**Q2a. APROBADA por Pau el 16/11 (liquidar entre monedas):** la cotización del día se **fija al pagar**; se precarga, se puede editar, queda guardada en el pago y **la confirma quien cobra junto con el pago**. La deuda baja por el equivalente en su moneda original. Sin revaluación posterior. Decisiones menores mías (cambiables): se guardan ambos importes y la cotización en el libro; anular el pago revierte ambos con la misma cotización; el redondeo usa los decimales de cada moneda (regla A4); si quien cobra no confirma, se aplica la regla de pagos pendientes que ya existe.

**Q2b. APROBADA por Pau el 16/11 (cotización automática):** se **precarga** la cotización del día en cada gasto y pago en otra moneda y **siempre se puede editar**. Si la fuente falla, se carga a mano y el grupo sigue funcionando. Decisiones menores mías (cambiables): la fuente la investigo y la propongo antes de construir; se guarda la fuente y la hora de cada cotización precargada; si la cotización editada se aparta mucho de la sugerida, se muestra un aviso (umbral configurable, 10% por defecto).

**Q2c. APROBADA por Pau el 16/11 (OCR):** se lee **en el celular** y **sugiere importe y fecha**; la persona confirma o corrige antes de guardar. La foto no sale del aparato para leerse (sin claves ni costo por uso). Decisiones menores mías (cambiables): nunca se guarda un importe sin confirmación; si la lectura falla o es dudosa, el formulario queda vacío como hoy; el motor de lectura se elige y se prueba en DEV antes de construir (revisión estática primero), y su carga es diferida para no pesar en el arranque de la app.

**Documentos que faltan y no completo de memoria:** GF-14 (liquidación entre monedas, citado en `Pinto_Equivalencias_de_nombres_y_pendientes.md`) y GF-18 (OCR de comprobantes): ninguno de los dos está en el Proyecto. Hay que traerlos o aprobar que se reconstruyan.

**Ítems nuevos en la lista de la sección 1:**
| # | Ítem | Quién | Tamaño | Lo bloquea | Cómo se verifica |
| --- | --- | --- | --- | --- | --- |
| 20 | Cotización automática (diseño, migración propuesta con reversa, pantalla) | Yo | grande | Definiciones de Pau; GF-14 | Ejecutada: rollback en DEV con una fuente simulada; real: Pau en celular |
| 21 | Liquidar entre monedas (diseño del libro, saldos, anulación; pruebas) | Yo | grande | Definiciones de Pau; GF-14; ítem 20 | Ejecutada: rollback con casos de redondeo y anulación; los saldos de antes y después deben cuadrar al centavo |
| 22 | OCR de comprobantes | Yo | grande | Definiciones de Pau; GF-18 | Ejecutada: fotos de ejemplo; real: Pau con tickets reales |

**Etapa nueva en la sección 6:** «4b. Monedas y OCR» (ítems 20 a 22), después de la etapa 4 y antes de la verificación real. **Listo cuando:** cada pieza tiene su definición aprobada, pruebas ejecutadas en DEV y un interruptor configurable. La 1.0 sale con las tres **encendidas** solo si Pau lo confirma después de verlas probadas.

Decisiones **menores que tomo yo y anoto** (cambiables): la interfaz vuelve a pedir la lista antes de aprobar para usar el hash vigente; si el servidor responde `invalidated` o `LNK_VERSION`, muestra el motivo y ofrece reintentar; las solicitudes vencidas se muestran 7 días más, solo lectura.

## 3. Pruebas

### Se pueden correr en DEV sin Pau (rollback, sin residuos)
- Matriz de permisos por rol, función por función (ítem 3).
- Vínculo: dos aprobaciones simultáneas y dos solicitudes simultáneas (ítem 5). **La herramienta usa una sola sesión por llamada**: la prueba necesita dos llamadas paralelas con datos confirmados y limpieza posterior. Eso deja datos transitorios en DEV, así que lo dejo **preparado y pido tu autorización antes de correrlo**. Evidencia estática hoy: `core_link_request_decide` y `core_link_request_cancel` usan bloqueo de fila (`FOR UPDATE`) y hay índices únicos parciales (`links_one_active_per_ref`, `link_requests_one_pending`). `core_link_request_create` no bloquea, pero lo cubre el índice único: falta probar qué error devuelve la segunda llamada.
- Grupo cerrado y vínculo (ya probado: 7 comprobaciones); sumar el caso «cerrar con una solicitud pendiente y después aprobar» en la interfaz.
- Disparadores de avisos de propuestas (ítem 9).
- Códigos de error (ítem 6).
- Idempotencia: reintento de un gasto, de un pago y de una solicitud con la misma clave.
- Gastos repetidos: dos ejecuciones a la vez (hoy no verificado).
- Volumen: datos sintéticos en transacción con rollback, y plan de ejecución de las lecturas principales.
- Smoke de UI con servidor simulado (Playwright).
- Asesores de Supabase (solo lectura).

### Requieren celulares reales (Pau)
- Flujo de dos personas: solicitar desde Juntada o Escapada, aprobar desde Cuentas.
- Aviso en la app y correo (cuando haya SMTP).
- TalkBack.
- Invitado reclamado por enlace.
- Instalación como app.
- Foto del ticket con Storage real.
- Cola y grupo sin conexión en un aparato real, incluida la sincronización al volver la señal.
- CSV real de Splitwise.
- Pago con «Pagar» desde Saldos y la pantalla de Nuevo gasto (las mejoras de hoy).

## 4. Riesgos

### P0
| Riesgo | Estado |
| --- | --- |
| **Fuga de acceso financiero** por una función que no valida el rol (regla de oro: la autorización se valida siempre en servidor) | **Avance 16/11:** leí en detalle las líneas de autorización de 24 de las 56 funciones; ninguna muestra un hueco comprobado, con 7 puntos a confirmar. Detalle en `Pinto_Revision_estatica_permisos_Cuentas_B5_avance.md`. Faltan unas 30 por leer y toda la prueba ejecutada por rol |
| **Aprobaciones simultáneas del vínculo** (doble aprobación, vínculo duplicado) | Estático: bloqueo de fila e índices únicos. **Sin prueba ejecutada** |
| **Aprobar sobre una versión vieja** desde la interfaz (consentimiento ligado al hash equivocado) | El servidor ya lo cubre con `LNK_VERSION`. Falta que la UI lo maneje; prueba en el ítem 12 |
| **Paquete de producción nunca ejecutado**, ni siquiera en una base descartable | Preparado, sin probar. Es P0 para salir a producción, no para el cierre en DEV |
| **Grupo cerrado y consistencia**: que un movimiento o una aprobación se cuele después del cierre | Vínculo: probado (0037). Gastos nuevos bloqueados con el grupo cerrado y pagos que siguen permitidos: es regla aprobada, pero **no la verifiqué en esta lectura**; probarla en la matriz (ítem 3) |

### P1
- **Liquidar entre monedas entra en la 1.0 (Q2):** es P0 para la corrección de saldos (ver sección 2b); hasta que tenga definición no se puede estimar bien.
- **Cotización automática y OCR** dependen de servicios externos: disponibilidad, costo y privacidad de los tickets.
- Lecturas sin paginación (ver sección 5): con muchos movimientos se degradan.
- Errores con texto libre en casi todas las RPC: la UI es frágil ante un cambio de texto (ítem 6).
- Correo esencial sin salida: el consentimiento queda cubierto en la app, pero la persona que no abre la app no se entera.
- Cola de escrituras sin conexión sin probar contra un servidor real.
- Gastos repetidos con ejecuciones concurrentes: sin probar.
- Migraciones 0024 a 0030, 0036 y 0037 sin revisión de Pau.
- Documentos oficiales faltantes (GF, QA-F, ADR-QA): la cobertura de QA es provisoria.
- Protección de contraseñas filtradas desactivada en Auth (Pau, en el panel).
- Todo el cliente en un solo archivo: aumenta el costo de cada cambio.
- Marca y dominios sin resolver antes de producción.

## 5. Revisión de arquitectura y rendimiento (sección E)

Hallazgos **estáticos** de hoy (lectura de DEV, sin medición):
- `cuentas_movements_list(p_group)` no tiene `p_limit` ni paginación.
- `cuentas_balances(p_group)` recalcula desde el libro en cada llamada.
- `cuentas.audit_log` tiene solo el índice de clave primaria. `cuentas_activity_list` lee por grupo y probablemente hace recorrido completo: **a medir** antes de afirmar.
- `cuentas.movements` tiene índices únicos (clave idempotente y seguimiento); no vi un índice pensado para listar por grupo y fecha. **A medir.**
- `openGroup` pide 12 RPC en paralelo al abrir un grupo.
- `core.notifications`, `core.links` y `core.link_requests` tienen los índices que sus consultas necesitan, a primera vista.

Patrones propuestos, de menor a mayor costo (todos preservan el libro append-only como única fuente de verdad):
1. **Paginación por cursor** (keyset) en movimientos y actividad, con tope por llamada. Patrón: paginación + límite.
2. **Índices de apoyo** donde la medición los justifique, por ejemplo `(group_id, created_at desc)`.
3. **Fachada de lectura**: una RPC que devuelve la vista inicial del grupo (patrón fachada / agregado), en lugar de 12 llamadas. Reduce viajes y latencia en celulares.
4. **Saldos derivados**: cacheados o materializados y recalculables desde el libro (agregado derivado con reconciliación). Solo si la medición lo pide.
5. Outbox y clave idempotente: revisar que **toda** escritura la use (hoy es el patrón del cliente).
6. RLS y funciones: sin trabajo por fila costoso; ya se accede por RPC con `SECURITY DEFINER`.
7. Cliente: separar módulos y carga diferida **sin** perder el despliegue de un solo paso.

Método: primero estático; después medir en DEV con datos sintéticos dentro de una transacción con rollback, y **informar la medida, no un supuesto**. No hay cambios de migración sin tu autorización.

## 6. Etapas y criterio de «listo»

| Etapa | Contenido (ítems) | Listo cuando |
| --- | --- | --- |
| 0. Alineación | 1, 2 | Q1 a Q5 respondidas y registradas; documentos sin inconsistencias |
| 1. Seguridad del servidor | 3, 6, 11 | Tabla función × rol completa; ejecutada en DEV sin desvíos; asesores sin hallazgos nuevos |
| 2. Vínculo bilateral en la UI | 4, 7, 12 | La UI cubre todos los estados (pendiente, aprobada, rechazada, cancelada, vencida, invalidada, grupo cerrado); `smoke.js` en «todo ok» |
| 3. Concurrencia y avisos | 5, 9 | Dos aprobaciones simultáneas: una sola gana y queda un vínculo; disparadores probados |
| 4. Rendimiento | 10 | Medidas informadas; mejoras elegidas por vos, aplicadas o descartadas con motivo |
| 5. Correo | 8 | Correo esencial entregado, o decisión de Q5 de salir sin correo |
| 6. Documentos | 13 a 16 | PRD, ADR-010 y checklists actualizados; los faltantes recuperados o su reconstrucción aprobada |
| 7. Verificación real | 18 | Lista de la sección 3 hecha con capturas, sin P0 abiertos |
| 4b. Monedas y OCR | 20 a 22 | Cada pieza con su definición aprobada, pruebas en DEV y un interruptor |
| 8. Cierre | 17, 19 | Paquete de producción preparado; merges en orden y con «mergeá» de Pau |

**Cuentas es «1.0» cuando:** etapas 0 a 4, 4b y 6 hechas, 7 sin P0 abiertos, y Pau lo marca como aprobado. El correo no es condición (Q5).

## 7. Documentos a actualizar
- **PRD de Cuentas V0.2 §3** (adenda 2): vínculo bilateral, grupo cerrado bloquea (0037), vencimiento auditado (0036). Pau decide si se incorpora.
- **Checklist V1.0 de Cuentas:** B2, B4, B7 y B10; sumar este plan.
- **Equivalencias y pendientes:** archivo y eliminación (Q1); alcance 1.0 (Q2): la fila de OCR («sin alcance aprobado») y la de tipos de cambio quedan desactualizadas.
- **Checklist V1.0 de Cuentas:** A6 dice que OCR, liquidar entre monedas y cotización automática siguen fuera; ahora entran.
- **Anexo de pruebas C / 0036:** nota de que 0036 ya está aplicada.
- **ADR-010:** texto final y estado de P1 en Cuentas (según Q4).
- **Matriz Maestra (AL-12):** solo cuando haya ADR-010 oficial.
- **Checklist de merge y arranque:** pasos de la etapa 8.
- **Tabla de equivalencias de IDs de QA:** cuando se recuperen GF, QA-F y ADR-QA.

## Resumen
- **Aprobado (decisión de Pau):** vínculo bilateral entra en la 1.0 (23); desvincular solo con permiso en Cuentas (24); grupo cerrado bloquea vínculos (0037); ADR-010 P1 a P7; matriz de permisos por rol; grupo sin conexión en la 1.0; canal «app + correo»; reversa por dominio (27).
- **Propuesto por mí (sin aprobar):** este plan; Q1 a Q5 con su recomendación; las decisiones menores de la sección 2; los patrones de la sección 5.
- **Pendiente:** Q1 a Q5; autorización para la prueba de concurrencia con datos confirmados; SMTP y función de envío; GF-01 a 16, QA-F01 a 112, ADR-QA 01 a 72; texto final del ADR-010; revisión de migraciones; pruebas en celulares; merges.
