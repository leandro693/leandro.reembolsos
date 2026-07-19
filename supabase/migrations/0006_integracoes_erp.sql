-- ============================================================================
-- 0006 — Integração com ERPs de gestão (Omie hoje; pluggable p/ outros).
-- Guarda as credenciais da API por empresa/provedor. As credenciais só são
-- lidas pelo servidor (Edge Function importar-erp, via service role). No app,
-- apenas o dono do SaaS ou o gestor da empresa administram a integração.
-- Idempotente.
-- ============================================================================

create table if not exists public.integracoes_erp (
  id            uuid primary key default gen_random_uuid(),
  empresa_id    uuid not null references public.empresas(id) on delete cascade,
  provedor      text not null default 'omie',
  app_key       text default '',
  app_secret    text default '',
  secret_set    boolean not null default false,
  ativo         boolean not null default false,
  ultima_sync   timestamptz,
  criado_em     timestamptz not null default now(),
  unique (empresa_id, provedor)
);

alter table public.integracoes_erp enable row level security;

-- Só o dono do SaaS ou o gestor da empresa enxergam/administram a integração.
drop policy if exists integ_sel on public.integracoes_erp;
create policy integ_sel on public.integracoes_erp for select using (
  public.usuario_e_owner() or public.meu_papel(empresa_id) = 'gestor'
);
drop policy if exists integ_ins on public.integracoes_erp;
create policy integ_ins on public.integracoes_erp for insert with check (
  public.usuario_e_owner() or public.meu_papel(empresa_id) = 'gestor'
);
drop policy if exists integ_upd on public.integracoes_erp;
create policy integ_upd on public.integracoes_erp for update using (
  public.usuario_e_owner() or public.meu_papel(empresa_id) = 'gestor'
);
drop policy if exists integ_del on public.integracoes_erp;
create policy integ_del on public.integracoes_erp for delete using (
  public.usuario_e_owner() or public.meu_papel(empresa_id) = 'gestor'
);

select 'integracoes_erp ok' as status;
