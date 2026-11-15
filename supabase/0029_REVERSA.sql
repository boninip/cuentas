-- Reversa de 0029: quita los triggers y la función auxiliar y vuelve a las versiones de 0025 (cuentas_expense_add) y 0012 (cuentas_payment_cancel).
-- ATENCIÓN: restaurar cuentas_expense_add y cuentas_payment_cancel desde las migraciones previas (0025 y 0012).
drop trigger if exists movements_unit_check on cuentas.movements;
drop trigger if exists shares_unit_check on cuentas.movement_shares;
drop function if exists cuentas.check_unit_mov();
drop function if exists cuentas.check_unit_share();
drop function if exists cuentas.unit(text);
