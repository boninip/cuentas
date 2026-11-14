-- 0014 Cuentas: datos de cobro (alias / CBU / CVU). PROPUESTA, solo DEV.
-- Cada persona carga sus datos una vez; los ven solo los miembros ACTIVOS de sus grupos, y solo si ella los comparte.
-- Cuentas no mueve plata ni valida que la cuenta exista: solo muestra el dato para que te transfieran.
create table cuentas.payout_info(
  user_id uuid primary key references auth.users(id) on delete cascade,
  alias text,
  cbu text,
  holder_name text,
  bank text,
  shared boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint payout_alias_fmt check (alias is null or alias ~ '^[A-Za-z0-9.-]{6,20}$'),
  constraint payout_cbu_fmt check (cbu is null or cbu ~ '^[0-9]{22}$'),
  constraint payout_holder_len check (holder_name is null or char_length(holder_name) between 2 and 80),
  constraint payout_bank_len check (bank is null or char_length(bank) between 2 and 60),
  constraint payout_any check (alias is not null or cbu is not null)
);
alter table cuentas.payout_info enable row level security;
revoke all on cuentas.payout_info from public, anon, authenticated;

create function public.cuentas_payout_set(p_alias text, p_cbu text, p_holder text default null, p_bank text default null, p_shared boolean default true)
returns void language plpgsql security definer set search_path to '' as $$
declare a text:=nullif(btrim(p_alias),''); c text:=nullif(regexp_replace(coalesce(p_cbu,''),'\s','','g'),'');
begin
 if auth.uid() is null then raise exception 'No autorizado'; end if;
 if a is null and c is null then raise exception 'Cargá un alias o un CBU/CVU'; end if;
 if a is not null and a !~ '^[A-Za-z0-9.-]{6,20}$' then raise exception 'Alias inválido: 6 a 20 caracteres, letras, números, punto o guion'; end if;
 if c is not null and c !~ '^[0-9]{22}$' then raise exception 'CBU/CVU inválido: son 22 números'; end if;
 insert into cuentas.payout_info(user_id,alias,cbu,holder_name,bank,shared,updated_at)
 values(auth.uid(),a,c,nullif(btrim(p_holder),''),nullif(btrim(p_bank),''),coalesce(p_shared,true),now())
 on conflict(user_id) do update set alias=excluded.alias,cbu=excluded.cbu,holder_name=excluded.holder_name,bank=excluded.bank,shared=excluded.shared,updated_at=now();
end $$;

create function public.cuentas_payout_get() returns jsonb language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'No autorizado'; end if;
 return (select to_jsonb(x) from (select alias,cbu,holder_name,bank,shared from cuentas.payout_info where user_id=auth.uid()) x);
end $$;

create function public.cuentas_payout_clear() returns void language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null then raise exception 'No autorizado'; end if;
 delete from cuentas.payout_info where user_id=auth.uid();
end $$;

-- Datos de cobro de los miembros activos que los comparten (solo lo ve un miembro activo del grupo)
create function public.cuentas_group_payouts(p_group uuid) returns jsonb language plpgsql security definer set search_path to '' as $$
begin
 if auth.uid() is null or not cuentas.is_active_member(p_group,auth.uid()) then raise exception 'No autorizado'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'alias',i.alias,'cbu',i.cbu,'holder_name',i.holder_name,'bank',i.bank))
   from cuentas.members m join cuentas.payout_info i on i.user_id=m.user_id
   where m.group_id=p_group and m.status='active' and i.shared),'[]'::jsonb);
end $$;

do $$ declare f text; begin
 foreach f in array array['cuentas_payout_set(text,text,text,text,boolean)','cuentas_payout_get()','cuentas_payout_clear()','cuentas_group_payouts(uuid)'] loop
  execute format('revoke all on function public.%s from public, anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop; end $$;
