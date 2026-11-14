-- 0019 Cuentas: el chequeo de reparto (trigger diferido) corre al confirmar la transacción, FUERA de la función
-- SECURITY DEFINER, o sea con el rol de quien llama (authenticated), que no tiene acceso al esquema cuentas.
-- Resultado: «permission denied for schema cuentas» y NINGÚN gasto se guardaba desde la app.
-- Corrección: la función del trigger pasa a SECURITY DEFINER con search_path vacío. PROPUESTA, solo DEV.
alter function cuentas.check_shares() security definer set search_path to '';
