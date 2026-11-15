# Pinto · Equivalencias de nombres y pendientes abiertos

Fecha: 12/11/2026 · Actualizado 15/11/2026 · Las instrucciones del proyecto están en `00_INSTRUCCIONES_DEL_PROYECTO.md` (no se repiten acá).

## Equivalencias de nombres

La columna «En documentos» es lo que se escribe en PRDs y chats; «En código y base de datos» va siempre sin acento. Los identificadores técnicos que ya existen no se tocan hasta confirmar la marca (INPI y dominios).

| Nombre viejo | En documentos | En código y base de datos | En logotipo e imágenes |
| --- | --- | --- | --- |
| Planazo (ecosistema y app organizadora) | Pinto | pinto | Pintó |
| Planazo ID | Pinto ID | pinto-id, pinto_id | Pintó ID |
| Planazo Core | Pinto Core | core (esquema, ver abajo) | Pintó Core |
| Pinto Core (nombre visible de Supabase, según el LEEME) | Pinto Core | core | Pintó Core |
| 00 · Planazo (chat de coordinación) | 00 · Pinto | — | — |
| Gastos | Cuentas | cuentas | Cuentas |
| Juntada | Juntada | juntada | Juntada |
| Escapada | Escapada | escapada | Escapada |
| Cuenta compartida (GF-17) | cuenta compartida (se mantiene) | — | — |

## Nombres técnicos neutros por dominio (13/11)

Criterio aprobado en conversación el 13/11: los nombres técnicos van por dominio (`core`, `juntada`, `escapada`, `cuentas`) y no llevan prefijo de marca; «Pinto» queda para lo visible. La alternativa con prefijo `pinto_` puede reconsiderarse cuando se confirme la marca. Nada de esto se ejecuta sin autorización explícita: es el destino propuesto en el plan de migración (borrador).

| Hoy (existente) | Destino propuesto | Estado |
| --- | --- | --- |
| planazo_* (tablas y funciones en public) | core.* | Propuesto, no ejecutado (en DEV ya existen los esquemas y las tablas nuevas de core; ver anexos del 14 y 15/11) |
| escapada_* (en public) | escapada.* | Propuesto, no ejecutado |
| juntada_* (en public) | juntada.* | Propuesto; nombres de tablas por definir |
| cuentas.* | cuentas.* | Existe en DEV (migraciones 0007 a 0028, propuestas) |
| planazo_groups | Por decidir: grupos generales de Pinto o base de grupos de Cuentas | Definición pendiente de Pau |

### Identificadores técnicos que existen hoy y no se renombran todavía

| Identificador | Dónde aparece | Estado |
| --- | --- | --- |
| planazo-id.js | Juntada (PRD V1.1, sección 6) | Renombrar solo con plan de migración aprobado |
| planazo-auth.js | Escapada V59 (PRD V1.2, sección 9) | Igual; el plan prevé core-auth.js en un PR aparte |
| escapada_trips, escapada_members, escapada_invitations, escapada_invite_links | Escapada, Supabase | Pasan a esquema escapada con el plan; sin cambio hasta autorizar |
| Supabase «Pinto Core» (id sswgtcpaayisecwxxskp) | Proyecto de desarrollo, confirmado por Pau | Es DEV |
| Repos: escapada-preview / escapada | GitHub boninip | escapada-preview = pruebas, escapada = producción |
| Repos: juntada, cuentas | GitHub boninip | Cuentas: rama `feat/cuentas-ui-v0` (PR #1 sin mergear); Juntada: PR #1 a #5 sin mergear |

### Equivalencias de IDs de requisitos

Los IDs viejos se conservan en los documentos fuente. Para los nuevos se usa el esquema prefijo + tipo + número. La tabla completa se arma cuando se recuperen las series GF-01 a 16, QA-F01 a 112 y ADR-QA 01 a 72; hoy solo se puede adelantar el patrón (ver también `Pinto_Equivalencias_QA_GF17.md`):

| ID viejo | ID nuevo | Observación |
| --- | --- | --- |
| RF-P01 a RF-P18 | PIN-RF-001 a PIN-RF-018 | Reglas de la app Pinto |
| RF-C01 a RF-C10 | COR-RF-001 a COR-RF-010 | Reglas del Core |
| RF-E01 a RF-E08 | ESC-RF-001 a ESC-RF-008 | Reglas de Escapada |
| 17-A01 a 17-A09 | CUE-RF-017-01 a CUE-RF-017-09 | Reglas de GF-17; clave local del documento |
| ADR-010-01 a ADR-010-08 | CUE-RF-ADR010-01 a 08 | Pendiente de decidir si pasan a ser reglas oficiales |
| QA-P01 a QA-P24 | PIN-QA-001 a PIN-QA-024 | QA-P15 está repetido en la fuente: hay que resolverlo al migrar |
| QA-E01 a QA-E15 | ESC-QA-001 a ESC-QA-015 | En la Auditoría, QA-E01 a E04 significan otra cosa: no migrar sin revisar |
| QA-01 a QA-20 (Juntada) | JUN-QA-001 a JUN-QA-020 | Corregir el QA-10 («Indeciso») al migrar |
| QA-GF17-01 a 20 | CUE-QA-017-01 a 20 | Locales y no ejecutados |

## Pendientes abiertos (al 15/11)

Lo único que bloquea cerrar el PRD de Cuentas es recuperar documentos. El resto son definiciones que todavía no tomamos.

| Tema | Qué falta | Quién lo resuelve |
| --- | --- | --- |
| Documentos faltantes (C-09) | GF-01 a GF-16, QA-F01 a 112, ADR-QA 01 a 72 e INT07 V6.1. No están en ninguno de los zips | Pau, desde los chats de ChatGPT (copiar el texto si no hay archivos) |
| Prototipos de Juntada V1.4 y V1.5 | Usan «Voy / Tal vez / No puedo» en lugar de «Voy / No voy / Aún no sé». Propuesta: cambiar solo etiquetas, mantener valores guardados | Avisar a ChatGPT antes de cerrar la versión |
| Tipos de cambio y redondeo en Cuentas | **Parcial:** cotización fija editable, aprobada el 15/11. Falta fuente automática, redondeo por moneda y liquidación entre monedas (GF-14) | Definición clave: se le consulta a Pau |
| Liquidaciones parciales, correcciones y anulaciones | Reglas de Cuentas | Definición clave: se le consulta a Pau |
| Matriz completa de permisos financieros | **Parcial:** categorías, pesos y responsables, aprobados el 15/11 (administrador y coadministrador). Falta el resto | Definición clave: se le consulta a Pau |
| Cierre de grupos | Quién cierra, si se reabre, archivo y eliminación | Se propone una opción recomendada configurable |
| Avisos esenciales de consentimiento | Cuáles no se pueden desactivar | Se propone una lista recomendada |
| Eliminar y restaurar eventos y viajes | Ciclo de vida en Juntada y Escapada | Cada dominio, con aprobación de Pau |
| Un grupo por viaje en Escapada | Confirmar la misma cardinalidad que en Juntada | Lo decide Claude y lo deja anotado |
| Reversión con operaciones dependientes | Diseño técnico | Pendiente hasta la fase de contratos |
| ADR-010 oficial | Contratos, errores, versiones, payloads y reconciliación. Los contratos nuevos del 15/11 están en la sección 11 del PRD V0.2; el documento ADR-010 (.docx) no se reescribió | Borrador de contratos avanzado; falta aprobación de Pau |
| Revisión de migraciones 0024 a 0028 (Cuentas) y 0017/0018 (Juntada/Core) | Revisión de Pau antes de salir de DEV | Pau |
| Juntada etapas D y E | Quién puede reclamar un evento si se filtra el token del organizador, nombre visible del invitado, retiro de `juntada_gastos_*` | Definición clave de Pau |
| OCR de comprobantes (GF-18) | Sin alcance aprobado | Definición clave de Pau |
| Saldar deudas de un miembro con responsable | Diseñar y probar el flujo | Claude propone, Pau aprueba |
| Pruebas con personas reales | Dos celulares, TalkBack, invitado reclamado, instalación de la app, Storage real, cola sin señal, importación con CSV real | Pau, con capturas |
| SMTP propio | Configurar según `Cuentas_Guia_SMTP_propio_PROPUESTA.md` | Pau |
| Merge de PRs | Cuentas #1 y Juntada #1 a #5 sin mergear; solo con «mergeá» de Pau | Pau |
| Auditoría técnica de solo lectura | Hecha para Escapada, la base (Fase 2) y la primera pasada de Juntada | Claude, a pedido |
| H-13 (invitaciones fallan por `digest` sin esquema) | Corregido en DEV con la migración 0001 (propuesta) | Pau revisa antes de otro entorno |
| Qué son `planazo_groups` | Grupos generales de Pinto o base de Cuentas | Definición clave de Pau |
| Marca | INPI (clases de software y servicios online), dominios y redes | Pau |
