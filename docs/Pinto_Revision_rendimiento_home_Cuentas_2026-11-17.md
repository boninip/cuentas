# Revisión de rendimiento · home de Cuentas · 17/11/2026 (PROPUESTA)
Equivalencias: Gastos = Cuentas. Revisión de solo lectura; no se cambió nada.

## Cómo se arma hoy el home (revisión estática de `index.html`, main 2bffe45)
1. `start()` espera `fresh()` (renueva token si le quedan <60 s) y recién ahí llama `home()`.
2. `home()` lanza en paralelo: `cuentas_payout_get`, `cuentas_my_pending`, `core_profile_get`, y espera `cuentas_my_groups_all`.
3. Después, en una segunda tanda: `core_notifications_list` (espera a `my_pending`) y un `cuentas_balances` **por grupo** (N+1).
4. La lista de grupos no se dibuja hasta que vuelve `my_groups_all`; el total del encabezado y los saldos, hasta que vuelven todos los `cuentas_balances`.
5. La copia guardada (`rpcC`, localStorage) solo se usa si no hay red; no se usa para pintar rápido.

## Medido (ejecutado, Playwright con servidor simulado; NO es Supabase real)
Con 1 grupo: 6 pedidos, 2 tandas encadenadas. Con 200 ms por pedido: primera tanda a ~230 ms, segunda a ~450 ms; saldos visibles ~460 ms. Con N grupos serían 4 + N pedidos.
**No medido:** latencia real a Supabase DEV desde Argentina, tiempo de cada RPC en el servidor, celular real con red móvil.

## Hallazgos
- H1. Cascada de 2 tandas + N+1 de saldos.
- H2. Pantalla vacía hasta la primera respuesta: no hay esqueleto ni se pinta la última copia guardada.
- H3. `fresh()` no deduplica: si el token vence, varios pedidos simultáneos pueden pedir renovación a la vez con el mismo refresh token. Riesgo de «sesión vencida» espurio. (Revisión estática, sin reproducir.)
- H4. `payout_get` y `core_profile_get` no hacen falta para el primer pintado.
- H5. Imagen de encabezado de 97 KB en base64 dentro del HTML (el HTML pesa 264 KB sin comprimir); además hay `assets/hero-cuentas.png` (414 KB) y `assets/hero.jpg` (140 KB) en el repo, sin uso verificado.
- H6. El service worker pide el HTML a la red en cada visita (el arranque espera al servidor).

## Patrones propuestos (de menor a mayor costo)
A. Solo interfaz, sin Supabase:
 1. Stale-while-revalidate al arrancar: pintar al instante lo último guardado (grupos y saldos) y refrescar atrás. Con la marca «actualizando».
 2. Esqueleto (placeholders) en grupos y en el total del encabezado.
 3. Paralelizar: `notifications_list` junto con `my_pending`; diferir `payout_get` y `core_profile_get` hasta que se abra Cuenta (el nombre del avatar sale de la copia guardada).
 4. Deduplicar `fresh()` con una sola promesa en vuelo (single-flight).
 5. Service worker: shell con stale-while-revalidate (arranque instantáneo desde el segundo uso) + cache:'no-store' en la revalidación para no ver versiones viejas.
 6. Imagen del encabezado: archivo aparte, WebP/JPG comprimido, con `preload`; sacar el base64 del HTML.
B. Requiere migración (solo con autorización de Pau):
 7. RPC de resumen `cuentas_home_summary` (fachada/agregación): devuelve grupos + mi saldo por grupo + pendientes en **un** pedido. Pasa de 4+N a 1–2 pedidos. Con reversa y prueba en DEV.
 8. Índices o consultas más baratas, una vez medido el tiempo real de cada RPC en DEV.

## Recomendación
Hacer A1–A6 primero (un PR, borrador); medir en el celular; recién ahí decidir B7 con números reales.

## Pendiente de Pau
Autorizar medir tiempos reales en DEV (solo lectura) y, si hace falta, la RPC de resumen (B7).
