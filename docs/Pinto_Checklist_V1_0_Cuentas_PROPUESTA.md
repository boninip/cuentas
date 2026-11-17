# Checklist hacia la versión 1.0 de Cuentas (PROPUESTA)

Fecha: 15/11/2026 · Estado: propuesta de trabajo, NO aprobada. Nada de acá se ejecuta fuera de DEV sin autorización de Pau.

Orden general acordado: cada app (Cuentas, Juntada, Escapada) llega a 1.0 con su lista; después se mergea todo en orden (Core, Cuentas, Juntada, Escapada) y recién ahí se desarrolla Pintó.

## A. Definiciones de Pau (bloquean)
| # | Tema | Estado |
| --- | --- | --- |
| A1 | Pagos: anulación, corrección y liquidación parcial | **Aprobado por Pau (15/11):** se anula con contramovimiento auditado; corregir = anular y cargar de nuevo; se admite pagar cualquier monto hasta la deuda. Detalle que decidí yo (configurable): el autor anula mientras no esté confirmado; la administración (admin, o coadmin con permiso «anular») lo anula siempre. Migración 0029 (propuesta, aplicada en DEV, 12/12 casos) |
| A2 | Cierre de grupos: quién cierra, reapertura, archivo y eliminación | **Aprobado por Pau (15/11):** cierran admin y coadmin (con permiso «cerrar»); reabre solo admin, auditado. Ya funciona así en DEV. Archivo y eliminación: sigue abierto |
| A3 | Matriz completa de permisos financieros | **Aprobado por Pau (15/11), matriz por rol:** miembro carga gastos y pagos propios y anula lo suyo; coadmin suma editar categorías, pesos y responsables, cerrar y anular lo de otros (según permisos delegados); admin todo, incluido reabrir y delegar. Falta revisar que cada función del servidor la cumpla (ítem B5) |
| A4 | Redondeo por moneda | **Aprobado por Pau (15/11):** cada moneda con sus decimales; el resto del reparto va por mayor fracción. CLP, PYG, JPY, KRW, VND, ISK y UGX sin decimales (lista decidida por mí, configurable). Migración 0029 y pantalla |
| A5 | Avisos esenciales de consentimiento | **Aprobado por Pau (15/11):** no se pueden desactivar los avisos de propuesta que requiere tu consentimiento, de invalidación de una propuesta en curso y de delegación o revocación de coadmin que te afecta. Cierre y reapertura no son esenciales. Falta implementar el aviso |
| A6 | Alcance 1.0 | **Aprobado por Pau (15/11):** el grupo sin conexión entra en la 1.0. Interpreto que OCR, liquidar entre monedas y cotización automática siguen fuera; confirmame si no es así |

## B. Trabajo de Claude
| # | Tarea | Estado |
| --- | --- | --- |
| B1 | Saldar deudas de un miembro con responsable (diseño y prueba) | Verificado en DEV (5/5 casos, `pruebas/responsable_saldos.sql`): el responsable ve y paga el saldo conjunto, no puede pagar de más y no se paga a un invitado sin cuenta. Sin prueba en celulares |
| B8 | Grupo sin conexión (lectura y carga): guardar la última vista del grupo en el aparato, marcar «sin conexión» y sincronizar al volver | Construido (propuesto): última vista guardada por persona y grupo, aviso con la antigüedad, gastos en cola; se borra al cerrar sesión. Probado con servidor simulado; falta probar en celular |
| B9 | Aviso esencial de consentimiento (A5), canal **app + correo** (aprobado por Pau 15/11) | Construido en la app y la base (migración 0030, propuesta, aplicada en DEV): avisos de consentimiento, propuesta invalidada, delegación, revocación y pedido de cuenta compartida; se ven en Actividad con «Entendido». **El correo no sale todavía:** queda en cola hasta que haya SMTP propio y una función de envío autorizada por Pau. Probado en DEV: delegación, revocación, lectura y pedido de cuenta compartida (7/7 y 2/2); los avisos de propuestas se crean por disparadores que no se ejecutaron todavía |
| B2 | Vínculos con Juntada y Escapada de punta a punta | Pendiente |
| B3 | Contratos ADR-010: errores, versiones, reconciliación | Pendiente |
| B4 | Matriz de QA real sobre las áreas P0 (autorización, concurrencia, privacidad entre eventos, idempotencia) | Pendiente |
| B5 | Revisión de seguridad de solo lectura (advisors, políticas, permisos) | Pendiente |
| B6 | Revisión de arquitectura y patrones de diseño para rendimiento (ver sección E) | Pendiente |
| B7 | Migraciones consolidadas con reversa y plan de paso a producción (preparado, no ejecutado) | Pendiente |

## C. Verificación con Pau
Dos celulares reales, TalkBack, invitado reclamado por link, instalación de la app, foto del ticket con Storage real, cola sin señal, CSV real de Splitwise, SMTP propio, revisión de migraciones 0024 a 0028.

## D. Documentos
Recuperar GF-01 a 16, QA-F01 a 112 y ADR-QA 01 a 72 (o aprobar reconstruirlos); reescribir ADR-010; cotejar el PRD con la Arquitectura y el Core.

## E. Revisión de arquitectura y rendimiento (aplica a Cuentas, Juntada, Escapada y Core)
Es revisión estática primero; toda medición se hace en DEV y se informa como medida, no como supuesto.
- Consultas: planes de ejecución de las RPC más usadas, índices que faltan o sobran, N+1 dentro de funciones.
- Saldos: evaluar cálculo incremental o vista materializada frente a recalcular desde el libro (patrón de agregado derivado, sin perder el libro append-only como fuente de verdad).
- Carga inicial de la app: hoy `openGroup` pide varias RPC en paralelo; evaluar una sola RPC de lectura agregada (patrón fachada) y paginación de movimientos.
- Idempotencia y reintentos: revisar el patrón de bandeja de salida (outbox) y la clave idempotente en todas las escrituras.
- Seguridad y rendimiento de RLS: políticas simples y con índices de apoyo; evitar funciones costosas por fila.
- Código del cliente: hoy es un solo archivo; evaluar separar módulos y carga diferida sin perder la simplicidad de despliegue.
- Gastos repetidos y actividad: generación por lotes y límites de lectura.
- Límites y observabilidad: tamaños máximos, paginación, registros de errores y medición en DEV.

## Decisiones de Juntada (Pau, 15/11) para las etapas D y E
- **Reclamar un evento si se filtra el token del organizador:** lo reclama el primero que llega con su Pinto ID y se avisa al organizador local, que puede recuperarlo con su código. Aprobado.
- **Nombre de un invitado sin Pinto ID:** se muestra el que escribió al responder; si después reclama su cuenta, se le ofrece vincularlo. Aprobado.
- **Funciones viejas `juntada_gastos_*`:** se retiran después de la 1.0 de las tres apps, con autorización expresa de Pau. Aprobado.
