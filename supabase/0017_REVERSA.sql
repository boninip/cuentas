-- Reversa de 0017. Restaura can_organize original y quita lo agregado.
do $m$ declare d text; n text:='return (p_organizer is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.organizer_token_hash=encode(extensions.digest(p_organizer::text,''sha256''),''hex''))) or (p_user is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.owner_user_id=p_user));';
begin
 d:=pg_get_functiondef('core.can_organize(text,uuid,uuid,uuid)'::regprocedure);
 if position(n in d)>0 then d:=replace(d,n,'return p_organizer is not null and exists(select 1 from juntada.juntadas j where j.id=p_ref_id and j.organizer_token_hash=encode(extensions.digest(p_organizer::text,''sha256''),''hex''));'); execute d; end if;
end $m$;
drop function if exists public.juntada_reclamar(uuid,uuid);
drop function if exists public.juntada_mis_eventos();
alter table juntada.juntadas drop column if exists owner_user_id;
