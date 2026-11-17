# Traspaso: un chat por app (15/11/2026)

Estado: guía de trabajo, NO oficial. Orden acordado: cada app llega a su 1.0; después se mergea todo (Core, Cuentas, Juntada, Escapada) y recién ahí se desarrolla Pintó.

## Reglas que valen en todos los chats (resumen; mandan las Instrucciones del Proyecto)
- Español rioplatense, breve. Separar aprobado, propuesto y pendiente. «Aprobado» es solo una decisión explícita de Pau.
- Solo DEV (Supabase «Pinto Core», `sswgtcpaayisecwxxskp`). Nunca pedir ni usar claves o tokens.
- No mergear sin un «mergeá» explícito. No renombrar identificadores técnicos existentes.
- Lo irreversible o que necesita una decisión de Pau se prepara, no se ejecuta.
- Las definiciones clave se le preguntan con opciones (recomendada primero); lo menor se decide y se anota.
- Cada chat cierra con: decisiones, pendientes y documentos a actualizar.

## Chat 1 · Cuentas (este chat, hasta cerrar la 1.0)
- Repo `boninip/cuentas`, rama `feat/cuentas-ui-v0` (PR #1 sin mergear). App publicada en boninip.github.io/cuentas.
- Documentos: `Pinto_Checklist_V1_0_Cuentas_PROPUESTA.md` (lista de la 1.0), `Cuentas_PRD_V0_2_borrador.md`, anexo del 15/11, migraciones 0007 a 0030.
- Falta: vínculos con Juntada y Escapada de punta a punta (lado Cuentas), contratos del ADR-010, matriz de QA real, revisión de seguridad, revisión de arquitectura y rendimiento, plan de paso a producción, envío de correo (necesita SMTP de Pau).

## Chat 2 · Juntada
- Repo `boninip/juntada`; rama `feat/pinto-id-mis-eventos` (PR #5 en borrador, apilado sobre #4); PR #1 a #5 sin mergear.
- Documento: `Pinto_Plan_Juntada_con_Pinto_ID_BORRADOR.md`; migraciones 0017 (dueño por Pinto ID) y 0018 (viajes organizables).
- Hecho: etapa C en vista previa (panel «Mis juntadas» con Pinto ID, reclamar eventos locales).
- Decidido por Pau (15/11): reclama el primero con su Pinto ID y se avisa al organizador local, que puede recuperarlo; el invitado sin Pinto ID muestra el nombre que escribió; las funciones `juntada_gastos_*` se retiran después de la 1.0 de las tres apps.
- Falta: etapas D y E del plan, vínculo con Cuentas (lado Juntada), asistencia «Voy / No voy / Aún no sé» en los prototipos V1.4 y V1.5, eliminar y restaurar eventos, auditoría técnica del repo y checklist de 1.0 propio.

## Chat 3 · Escapada
- Repos `boninip/escapada-preview` (pruebas) y `boninip/escapada` (producción: no tocar sin autorización).
- Documentos: PRD de Escapada V1.2, Auditoría de Escapada y la base (Fase 2), migraciones 0005 y 0006, `pruebas/smoke_escapada.sql`.
- Falta: checklist de 1.0 propio, confirmar un grupo de Cuentas por viaje, vínculo con Cuentas (lado Escapada), eliminar y restaurar viajes, y el paso de `planazo-auth.js` a `core-auth.js` en un PR aparte (con autorización).

## Chat 4 (cuando toque) · Core y Pintó
- Core: registro de vínculos (0013), viajes organizables (0018), avisos (0030), plan de migración de esquemas (borrador, nada ejecutado).
- Pintó (la app organizadora) arranca después de mergear todo.

## Cómo abrir cada chat
Abrirlo dentro del Proyecto «Pintó» y escribir, por ejemplo: «Este chat es solo para Juntada. Leé `Pinto_Traspaso_chats_por_app_2026-11-15.md` y el plan de Juntada, armá el checklist de la 1.0 y preguntame lo que necesites». Los acuerdos entre apps (vínculos, avisos, permisos) se anotan en el Registro de decisiones del Proyecto para que los otros chats los vean.
