-- ============================================================================
-- 0014 — Sistema de crédito/saldo (conta corrente do operador).
-- Plano aprovado: docs/PLANO-CREDITO-SALDO.md (decisões A-E).
--
-- Aditivo e idempotente. NÃO altera dados existentes:
--  - empresa_usuarios.modo_lancamento default 'despesa' (todos nascem no modo atual);
--  - tabela nova creditos_operador (começa vazia);
--  - 3 RPCs security definer com gate de papel NO SQL (não confia no front);
--  - RLS: operador vê só o próprio crédito; gestão vê a empresa inteira.
-- Registro do "antes": supabase/auditoria/credito-antes-2026-08-12.txt
-- Rollback: supabase/auditoria/rollback-0014.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Modo por operador (na empresa_usuarios; default 'despesa' = comportamento atual)
-- ---------------------------------------------------------------------------
alter table public.empresa_usuarios
  add column if not exists modo_lancamento text not null default 'despesa';
do $$ begin
  if not exists (select 1 from pg_constraint where conname='empresa_usuarios_modo_chk') then
    alter table public.empresa_usuarios
      add constraint empresa_usuarios_modo_chk check (modo_lancamento in ('despesa','credito'));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Tabela de créditos avulsos (conta corrente)
-- ---------------------------------------------------------------------------
create table if not exists public.creditos_operador (
  id          uuid primary key default gen_random_uuid(),
  empresa_id  uuid not null references public.empresas(id) on delete cascade,
  usuario_id  uuid not null references public.usuarios(id) on delete cascade,
  valor       numeric(14,2) not null,
  data        date not null default current_date,
  lancado_por uuid references public.usuarios(id),
  observacao  text,
  criado_em   timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_credito_emp_user
  on public.creditos_operador(empresa_id, usuario_id) where deleted_at is null;

alter table public.creditos_operador enable row level security;

-- RLS: operador vê só o próprio; gestão vê a empresa inteira (espelha lanc_select da 0008).
drop policy if exists cred_select on public.creditos_operador;
create policy cred_select on public.creditos_operador for select using (
  public.usuario_e_owner()
  or (empresa_id in (select public.empresas_do_usuario())
      and (usuario_id = auth.uid() or public.meu_papel(empresa_id) in ('gestor','financeiro')))
);
-- INSERT/UPDATE (soft-delete): só gestão. Defesa em profundidade (a escrita vai por RPC/gate).
drop policy if exists cred_ins on public.creditos_operador;
create policy cred_ins on public.creditos_operador for insert with check (
  empresa_id in (select public.empresas_do_usuario())
  and (public.usuario_e_owner() or public.meu_papel(empresa_id) in ('gestor','financeiro'))
);
drop policy if exists cred_upd on public.creditos_operador;
create policy cred_upd on public.creditos_operador for update using (
  public.usuario_e_owner()
  or (empresa_id in (select public.empresas_do_usuario()) and public.meu_papel(empresa_id) in ('gestor','financeiro'))
);

-- ---------------------------------------------------------------------------
-- 3) RPCs (security definer) — gate de papel NO SQL; operador é barrado no banco.
-- ---------------------------------------------------------------------------
-- LANÇAR CRÉDITO (gestão) — lancado_por = auth.uid() no servidor (não forjável).
create or replace function public.lancar_credito(p_empresa uuid, p_usuario uuid, p_valor numeric, p_data date, p_obs text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if not (public.usuario_e_owner() or public.meu_papel(p_empresa) in ('gestor','financeiro')) then
    raise exception 'sem_permissao';
  end if;
  if p_valor is null or p_valor <= 0 then raise exception 'valor_invalido'; end if;
  if not exists (select 1 from public.empresa_usuarios where empresa_id=p_empresa and usuario_id=p_usuario) then
    raise exception 'usuario_nao_e_da_empresa';
  end if;
  insert into public.creditos_operador(empresa_id, usuario_id, valor, data, lancado_por, observacao)
    values (p_empresa, p_usuario, p_valor, coalesce(p_data, current_date), auth.uid(), nullif(btrim(p_obs),''))
    returning id into v_id;
  return v_id;
end $$;

-- DEFINIR MODO (gestão) — altera SÓ modo_lancamento (não mexe em papel/ativo).
create or replace function public.set_modo_operador(p_empresa uuid, p_usuario uuid, p_modo text)
returns text language plpgsql security definer set search_path=public as $$
begin
  if not (public.usuario_e_owner() or public.meu_papel(p_empresa) in ('gestor','financeiro')) then
    raise exception 'sem_permissao';
  end if;
  if p_modo not in ('despesa','credito') then raise exception 'modo_invalido'; end if;
  update public.empresa_usuarios set modo_lancamento=p_modo where empresa_id=p_empresa and usuario_id=p_usuario;
  if not found then raise exception 'vinculo_nao_encontrado'; end if;
  return 'ok';
end $$;

-- REMOVER CRÉDITO (gestão) — soft-delete, para corrigir lançamento errado (decisão 3).
create or replace function public.remover_credito(p_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare v_emp uuid;
begin
  select empresa_id into v_emp from public.creditos_operador where id=p_id and deleted_at is null;
  if v_emp is null then raise exception 'credito_nao_encontrado'; end if;
  if not (public.usuario_e_owner() or public.meu_papel(v_emp) in ('gestor','financeiro')) then
    raise exception 'sem_permissao';
  end if;
  update public.creditos_operador set deleted_at=now() where id=p_id;
  return 'ok';
end $$;

-- SALDO (próprio operador OU gestão) = Σ créditos − Σ despesas não excluídas/não rejeitadas.
create or replace function public.saldo_operador(p_empresa uuid, p_usuario uuid)
returns numeric language plpgsql security definer set search_path=public stable as $$
begin
  if not (p_usuario = auth.uid() or public.usuario_e_owner()
          or public.meu_papel(p_empresa) in ('gestor','financeiro')) then
    raise exception 'sem_permissao';
  end if;
  return
    coalesce((select sum(valor) from public.creditos_operador
              where empresa_id=p_empresa and usuario_id=p_usuario and deleted_at is null),0)
  - coalesce((select sum(valor_total) from public.lancamentos
              where empresa_id=p_empresa and user_id=p_usuario and deleted_at is null
                and (aprovacao is null or aprovacao <> 'rejeitado')),0);
end $$;

grant execute on function public.lancar_credito(uuid,uuid,numeric,date,text) to authenticated;
grant execute on function public.set_modo_operador(uuid,uuid,text) to authenticated;
grant execute on function public.remover_credito(uuid) to authenticated;
grant execute on function public.saldo_operador(uuid,uuid) to authenticated;

select 'credito/saldo: modo_lancamento + creditos_operador + RPCs + RLS (0014) ok' as status;
