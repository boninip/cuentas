-- 0010b/0010c (DEV): un exmiembro no reingresa con un link creado antes de su baja; al reingresar vuelve como 'member' (no recupera rol de admin).
do $m$
declare d text; a1 text:=$a$ if cuentas.is_active_member(v_inv.group_id,v_user) then return v_inv.group_id; end if;$a$; a2 text:=$a$do update set status='active', left_at=null;$a$;
begin
 d:=pg_get_functiondef('public.cuentas_invite_accept(text)'::regprocedure);
 if position(a1 in d)=0 or position(a2 in d)=0 then raise exception 'patrón no encontrado'; end if;
 d:=replace(d,a1,a1||$b$
 -- 0010b:begin
 if exists(select 1 from cuentas.members where group_id=v_inv.group_id and user_id=v_user and status='former' and left_at>v_inv.created_at) then raise exception 'Invitación vencida o inválida'; end if;
 -- 0010b:end$b$);
 d:=replace(d,a2,$c$do update set status='active', left_at=null, role='member';$c$);
 execute d;
end $m$;
