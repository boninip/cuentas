-- 0023 (PROPUESTA, aplicada solo en DEV): vista previa de invitación sin consumirla.
create or replace function public.cuentas_invite_preview(p_token text)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare v_inv cuentas.invites%rowtype; g cuentas.groups%rowtype;
begin
 if auth.uid() is null then raise exception 'Iniciá sesión'; end if;
 if coalesce(p_token,'') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('valid',false); end if;
 select * into v_inv from cuentas.invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 if not found or v_inv.revoked_at is not null or v_inv.expires_at<=now() or v_inv.uses>=v_inv.max_uses then return jsonb_build_object('valid',false); end if;
 select * into g from cuentas.groups where id=v_inv.group_id;
 if g.status='archived' then return jsonb_build_object('valid',false); end if;
 return jsonb_build_object('valid',true,'group_id',g.id,'name',g.name,
   'invited_by',(select p.display_name from core.planazo_profiles p where p.user_id=v_inv.created_by),
   'members',(select count(*) from cuentas.members m where m.group_id=g.id and m.status='active'),
   'already_member',cuentas.is_active_member(g.id,auth.uid()));
end $function$;
revoke all on function public.cuentas_invite_preview(text) from public, anon;
grant execute on function public.cuentas_invite_preview(text) to authenticated;
