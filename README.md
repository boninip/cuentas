# Cuentas (gastos compartidos) — beta DEV

App web de una sola página (`index.html`) para el dominio Cuentas del ecosistema Pinto.
Usa Pinto ID (login por enlace al email) y llama solo a funciones `public.cuentas_*` del proyecto Supabase de **desarrollo**.

- Crear grupo, invitar por link, cargar gastos (partes iguales), registrar y confirmar pagos, ver saldos, anular gasto, cerrar/reabrir grupo.
- Importes en unidades menores (centavos). Cuentas es la única autoridad sobre saldos.
- `supabase/` guarda las migraciones 0007 (base) y 0008 (listar mis grupos) con sus reversas en el repo de planificación.

Estado: probada con respuestas simuladas en Chromium (render, armado de llamadas, sin scroll horizontal). **No probada contra Supabase real desde un navegador.**
Marca provisoria: INPI y dominios pendientes.
