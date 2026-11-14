# Cuentas (gastos compartidos) — beta DEV

App web de una sola página (`index.html`) para el dominio Cuentas del ecosistema Pinto.
Usa Pinto ID (login por enlace al email) y llama solo a funciones `public.cuentas_*` del proyecto Supabase de **desarrollo**.

- Crear grupo, invitar por link, cargar gastos (partes iguales), registrar y confirmar pagos, ver saldos, anular gasto, cerrar/reabrir grupo.
- Importes en unidades menores (centavos). Cuentas es la única autoridad sobre saldos.
- `supabase/` guarda las migraciones 0007 (base) y 0008 (listar mis grupos) con sus reversas en el repo de planificación.

Estado: probada con respuestas simuladas en Chromium (render, armado de llamadas, sin scroll horizontal). **No probada contra Supabase real desde un navegador.**
## Estado (14/11/2026, rama `feat/cuentas-ui-v0`, PR #1 sin mergear)
- Pantalla del grupo con pestañas Gastos | Saldos | Más; «+ Agregar gasto» y «+ Agregar personas» a la vista; editar gastos; «Te están esperando» (pagos por confirmar, propuestas, solicitudes); «Mi nombre» (Pinto ID); datos de cobro (alias/CBU); cuenta compartida y compensaciones; vínculos con viajes (Escapada) y eventos (Juntada).
- `supabase/` tiene las migraciones 0007–0022 con reversas. TODAS son propuestas aplicadas solo en DEV. Reversas revisadas por lectura salvo 0017, probada.
- `pruebas/commit_mode_cuentas.sql`: prueba que fuerza los triggers diferidos. Las pruebas con rollback solas NO alcanzan (ver el comentario del archivo).
- Login real verificado desde un celular. Falta: flujo completo entre dos personas reales, concurrencia real, avisos fuera de la app.

Marca provisoria: INPI y dominios pendientes.
