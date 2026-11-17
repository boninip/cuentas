do $m$
declare d text;
begin
 d:=pg_get_functiondef('public.cuentas_invite_accept(text)'::regprocedure);
 d:=regexp_replace(d,E'\\n *-- 0010b:begin.*?-- 0010b:end','','s');
 d:=replace(d,'left_at=null, role=''member'';','left_at=null;');
 execute d;
end $m$;
