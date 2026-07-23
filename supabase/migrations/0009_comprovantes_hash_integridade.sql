-- ============================================================================
-- 0009 — Integridade de comprovantes (base da detecção de duplicata por hash).
--
-- Contexto: public.comprovantes tem RLS ligada e SÓ policy de SELECT. O app grava
-- o arquivo no Storage, mas o INSERT do metadado (arquivo_hash) era NEGADO pela RLS
-- e descartado por um try/catch silencioso — por isso o hash nunca era persistido e
-- a duplicata por imagem nunca era detectada. Registro do estado anterior em
-- supabase/auditoria/comprovantes-antes-0009.txt (tabela estava VAZIA: total=0).
--
-- Esta migration:
--  1) FK lancamento_id -> lancamentos(id) ON DELETE CASCADE (não havia FK alguma);
--  2) troca o índice único (empresa_id, arquivo_hash) por
--     (empresa_id, arquivo_hash, lancamento_id) — permite FORÇAR uma duplicata
--     legítima em OUTRO lançamento e continua barrando duplo-envio no MESMO;
--  3) policy comp_ins: usuário grava o metadado, isolado por empresa E só em
--     lançamento que lhe pertence (a FK garante existência, não posse);
--  4) trigger de soft-delete em cascata: ao excluir o lançamento, marca o
--     comprovante (libera o hash para relançamento legítimo), com policy de UPDATE
--     restrita ao sistema (to postgres, padrão da 0007).
--
-- Idempotente. Não apaga dados. A troca de índice é segura: a tabela está vazia.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Chave estrangeira (integridade estrutural que faltava)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'comprovantes_lancamento_fk'
       and conrelid = 'public.comprovantes'::regclass
  ) then
    alter table public.comprovantes
      add constraint comprovantes_lancamento_fk
      foreign key (lancamento_id) references public.lancamentos(id) on delete cascade;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Índice: unicidade por (empresa, hash, LANÇAMENTO)
--    (empresa_id, arquivo_hash) seguem sendo colunas-prefixo, então a busca de
--    duplicata por hash continua usando este índice.
-- ---------------------------------------------------------------------------
drop index if exists public.idx_comprovante_hash;
create unique index if not exists idx_comprovante_hash_lanc
  on public.comprovantes(empresa_id, arquivo_hash, lancamento_id)
  where deleted_at is null and arquivo_hash is not null;

-- ---------------------------------------------------------------------------
-- 3) INSERT do usuário: isolado por empresa E só em lançamento próprio
-- ---------------------------------------------------------------------------
drop policy if exists comp_ins on public.comprovantes;
create policy comp_ins on public.comprovantes for insert with check (
  comprovantes.empresa_id in (select public.empresas_do_usuario())
  and exists (
    select 1 from public.lancamentos l
     where l.id = comprovantes.lancamento_id
       and l.empresa_id = comprovantes.empresa_id
       and ( l.user_id = auth.uid()
             or public.usuario_e_owner()
             or public.meu_papel(l.empresa_id) in ('financeiro','gestor') )
  )
);

-- ---------------------------------------------------------------------------
-- 4) Soft-delete em cascata (lançamento excluído -> comprovante marcado)
--    A função roda como o dono (postgres); a policy abaixo libera SÓ esse papel.
-- ---------------------------------------------------------------------------
drop policy if exists comprovantes_sys_upd on public.comprovantes;
create policy comprovantes_sys_upd on public.comprovantes for update to postgres
  using (true) with check (true);

create or replace function public.fn_lanc_marca_comprovantes()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  -- só quando o lançamento passa a excluído (soft-delete)
  if new.deleted_at is not null and old.deleted_at is null then
    update public.comprovantes
       set deleted_at = new.deleted_at
     where lancamento_id = new.id and deleted_at is null;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_lanc_marca_comprovantes on public.lancamentos;
create trigger trg_lanc_marca_comprovantes
  after update on public.lancamentos
  for each row execute function public.fn_lanc_marca_comprovantes();

select 'comprovantes: FK + indice por lancamento + comp_ins + cascata soft-delete (0009) ok' as status;
