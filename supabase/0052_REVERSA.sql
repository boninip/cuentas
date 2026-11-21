-- Reversa de 0052: quita los códigos CUE_* (deja los mensajes como estaban).
do $mig$
declare f record; v_def text; v_new text; v_changed int:=0;
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname ~ '^cuentas_(payment|group_set_status|group_archive|proposal|delegate|pair)' loop
  v_def:=pg_get_functiondef(f.oid);
  v_new:=regexp_replace(v_def,'\s+using detail=''CUE_[A-Z_]+''','','g');
  if v_new<>v_def then execute v_new; v_changed:=v_changed+1; end if;
 end loop;
 raise notice 'funciones revertidas: %',v_changed;
end $mig$;
