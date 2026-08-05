-- ============================================================================
-- 0011 — Motivos de exclusão (cadastráveis por empresa) + coluna de motivo no
-- lançamento (para a auditoria capturar via dados_depois). Aditiva e idempotente.
-- Padrão de RLS igual ao de setores/categorias (0001): SELECT por empresa;
-- INSERT/UPDATE/DELETE apenas gestor da empresa ou dono do SaaS.
-- ============================================================================

-- 1) Tabela de motivos por empresa (mesmo shape de setores/categorias).
create table if not exists public.motivos_exclusao (
  id         uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nome       text not null,
  ativo      boolean not null default true,
  criado_em  timestamptz default now(),
  deleted_at timestamptz
);
create index if not exists idx_motivos_empresa on public.motivos_exclusao(empresa_id);

alter table public.motivos_exclusao enable row level security;

-- SELECT: dono do SaaS ou membros da empresa (todos os papéis escolhem o motivo).
drop policy if exists motivos_exclusao_sel on public.motivos_exclusao;
create policy motivos_exclusao_sel on public.motivos_exclusao for select using (
  public.usuario_e_owner() or empresa_id in (select public.empresas_do_usuario()));

-- INSERT/UPDATE/DELETE: apenas gestor da empresa ou dono (cadastro de config).
drop policy if exists motivos_exclusao_ins on public.motivos_exclusao;
create policy motivos_exclusao_ins on public.motivos_exclusao for insert with check (
  public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor');

drop policy if exists motivos_exclusao_upd on public.motivos_exclusao;
create policy motivos_exclusao_upd on public.motivos_exclusao for update using (
  public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor');

drop policy if exists motivos_exclusao_del on public.motivos_exclusao;
create policy motivos_exclusao_del on public.motivos_exclusao for delete using (
  public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor');

-- 2) Coluna aditiva no lançamento: guarda o motivo da exclusão. A trigger de
-- auditoria (0003) já grava to_jsonb(new) em dados_depois, então o motivo entra
-- em eventos_auditoria.dados_depois->>'motivo_exclusao' SEM alterar a tabela de auditoria.
alter table public.lancamentos add column if not exists motivo_exclusao text;

-- 3) Seed opcional: motivos comuns por empresa existente (idempotente).
insert into public.motivos_exclusao (empresa_id, nome)
select e.id, m.nome
from public.empresas e
cross join (values
  ('Lançamento em duplicidade'),
  ('Valor incorreto'),
  ('Comprovante inválido'),
  ('Cancelado pelo colaborador')
) as m(nome)
where not exists (
  select 1 from public.motivos_exclusao x
  where x.empresa_id = e.id and x.nome = m.nome);

select 'motivos_exclusao ok' as status;
