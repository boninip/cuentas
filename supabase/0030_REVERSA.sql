drop function if exists public.core_notifications_read(uuid);
drop function if exists public.core_notifications_list(int);
drop trigger if exists shared_accounts_notify on cuentas.shared_accounts;
drop trigger if exists delegations_notify on cuentas.delegations;
drop trigger if exists proposals_status_notify on cuentas.proposals;
drop trigger if exists proposal_required_notify on cuentas.proposal_required;
drop function if exists cuentas.t_notify_pair();
drop function if exists cuentas.t_notify_delegation();
drop function if exists cuentas.t_notify_proposal_status();
drop function if exists cuentas.t_notify_required();
drop function if exists core.notify(uuid,text,text,uuid,uuid,jsonb,boolean);
drop table if exists core.notifications; -- ATENCIÓN: borra los avisos guardados
