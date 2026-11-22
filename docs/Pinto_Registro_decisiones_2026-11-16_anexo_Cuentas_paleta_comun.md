# Registro de decisiones · 16/11/2026 · Anexo: paleta común de Pinto aplicada en Cuentas (PROPUESTA)

Equivalencias: Planazo = Pinto, Gastos = Cuentas. Solo presentación; sin cambios de lógica, Supabase ni migraciones. PR: `boninip/cuentas` **#2** (`feat/cuentas-paleta-pinto`, commit `a392727`), **sin mergear**.

## Aprobado (decisión de Pau, 16/11)
- Paleta común «Mar» ajustada para todas las apps; en pantalla «Pintó» con acento («Pintó ID»); aplicarla en Cuentas con rama, pruebas de interfaz y PR, sin mergear.

## Hecho (ejecutado, simulado; no en celular real)
- `smoke.js`: «todo ok», con 8 comprobaciones nuevas de paleta.
- `contraste.js` (nuevo): cálculo WCAG sobre los tokens reales de `index.html`. Texto normal ≥ 4,5 en todos los pares (peor caso 4,53 claro, 4,84 oscuro); gráficos y foco ≥ 3.
- «A favor» frente al primario: matiz 56° (claro) y 60° (oscuro), ΔE 45; «en contra» a 352°, coral a 12°. «A favor» y «en contra» no dependen solo del color: las pantallas ya traen texto («te deben», «debés», «debe»).
- Capturas a 390 px en claro y oscuro: inicio, grupo, Saldos, gasto y login.

## Decisiones menores mías (anotadas, cambiables)
- Mapeo: `--accent` es el fondo de botón; `--accent-text` es texto, bordes y foco (en oscuro `#6FB8C4`). Tokens nuevos: `--accent-text`, `--warm-text`, `--bad-solid`.
- `--outer` (fuera de la columna, solo en escritorio): `#E6F1F0` claro y `#0E1A19` oscuro (**este último no está en la tabla**, es un paso más oscuro del fondo).
- Semánticos propios, no de la marca: a favor `#2D7A3E` / `#7FD08A`; en contra `#A82A3A` / `#F08A97`; fondos `#E3F1E5` / `#1F3A27` y `#F8E4E6` / `#4A2430`.
- Colores de categorías de gasto (`--k1..k6`) y avatares de grupo (`--a1..a3`): derivados de la paleta, con contraste verificado; **no están en la tabla de referencia**.
- El amarillo del logo queda solo en el punto del logo y la viñeta del encabezado. Foco y barra elegida pasaron a otros tokens (foco = `--accent-text`; barra elegida = coral como texto).
- Se quitó el degradado decorativo del `.hero`; queda el velo de legibilidad sobre la foto.
- Íconos de la app recoloreados (`#1F5F6B` con el símbolo en `#FAF8F4`). `manifest.webmanifest`: tema y fondo `#FAF8F4`.
- El PR se apila sobre `feat/cuentas-ui-v0` porque `main` solo tiene el README (la app vive en la rama del PR #1).
- Hallazgo propio, corregido: al quitar `--h1..h3` desaparecía la foto del encabezado (su fondo de reserva usaba `--h2`).

## No verificado
- Celular real y lectores de pantalla. Contraste del texto blanco sobre la foto del encabezado: depende de la foto; solo revisión visual en capturas.

## Pendiente
- **Pau:** revisar el PR #2 en el celular y decir «mergeá» cuando corresponda (el PR #1 va antes, o se reapunta a `main`); aprobar la Apariencia compartida entre apps (propuesta, sin aprobar); confirmar si los colores derivados (categorías, avatares, `--outer` oscuro) están bien.
- **Después de la 1.0 (idea de Pau, sin aprobar):** temas opcionales como un eje aparte de la Apariencia.

## Documentos a actualizar
- `Pinto_Propuesta_paleta_comun_Pinto_PROPUESTA.md`: Cuentas pasa de «sin tocar» a «aplicada en PR #2 (sin mergear)»; sumar la tabla de semánticos y categorías, que no estaba.
- Checklist V1.0 de Cuentas y plan de cierre: sumar el PR de paleta.
- README de Cuentas, si menciona los colores.
