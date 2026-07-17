-- ============================================================================
-- REEMBOLSOS MARADEL - configuração do banco (Supabase / Postgres)
-- ----------------------------------------------------------------------------
-- Rode este arquivo UMA VEZ no seu projeto Supabase:
--   Supabase > SQL Editor > New query > cole tudo > Run.
-- Ele cria as tabelas, a segurança (RLS) e o armazenamento de comprovantes.
-- A segurança de verdade mora AQUI: cada diretor só enxerga e altera os
-- proprios lançamentos, validado pelo servidor, nao pelo aplicativo.
-- ============================================================================

-- ---------- Tabela de perfis (nome + dados PIX de cada diretor) ----------
create table if not exists public.perfis (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  nome        text not null default '',
  pix_tipo    text default 'CPF',
  pix_chave   text default '',
  pix_nome    text default '',
  pix_banco   text default '',
  atualizado_em timestamptz default now()
);

alter table public.perfis enable row level security;

drop policy if exists perfil_select on public.perfis;
drop policy if exists perfil_insert on public.perfis;
drop policy if exists perfil_update on public.perfis;
create policy perfil_select on public.perfis for select using (auth.uid() = user_id);
create policy perfil_insert on public.perfis for insert with check (auth.uid() = user_id);
create policy perfil_update on public.perfis for update using (auth.uid() = user_id);

-- ---------- Tabela de lançamentos ----------
create table if not exists public.lancamentos (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  usuario       text default '',
  categoria     text not null,
  fornecedor    text default '',
  beneficiario  text default '',
  local         text default '',
  valor_total   numeric(12,2) not null default 0,
  km_total      numeric(12,2) default 0,
  valor_km      numeric(12,2) default 0,
  pedagio       numeric(12,2) default 0,
  estacionamento numeric(12,2) default 0,
  data_emissao  date,
  vencimento    date,
  data_pagamento date,
  status        text not null default 'aberto',   -- 'aberto' ou 'pago'
  observacoes   text default '',
  id_compra     uuid,                             -- agrupa parcelas da mesma compra
  parcela_num   int,
  parcela_total int,
  comprovante   text default '',                  -- caminho do arquivo no Storage
  criado_em     timestamptz default now()
);

create index if not exists idx_lanc_user on public.lancamentos(user_id);
create index if not exists idx_lanc_venc on public.lancamentos(vencimento);

alter table public.lancamentos enable row level security;

drop policy if exists lanc_select on public.lancamentos;
drop policy if exists lanc_insert on public.lancamentos;
drop policy if exists lanc_update on public.lancamentos;
drop policy if exists lanc_delete on public.lancamentos;
create policy lanc_select on public.lancamentos for select using (auth.uid() = user_id);
create policy lanc_insert on public.lancamentos for insert with check (auth.uid() = user_id);
create policy lanc_update on public.lancamentos for update using (auth.uid() = user_id);
create policy lanc_delete on public.lancamentos for delete using (auth.uid() = user_id);

-- ---------- Armazenamento de comprovantes (privado, por usuário) ----------
insert into storage.buckets (id, name, public)
values ('comprovantes', 'comprovantes', false)
on conflict (id) do nothing;

-- Cada usuário só grava/lê arquivos dentro da própria pasta (nome = user_id/arquivo).
drop policy if exists comp_insert on storage.objects;
drop policy if exists comp_select on storage.objects;
drop policy if exists comp_delete on storage.objects;
create policy comp_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy comp_select on storage.objects for select to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy comp_delete on storage.objects for delete to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================================
-- Pronto. Agora crie os 3 usuários (diretores) em Authentication > Users:
--   Add user > informe e-mail e senha. Em "User Metadata" (Raw JSON), coloque:
--     { "nome": "Leandro" }     (troque para Márcio / Adelson em cada um)
--   O nome aparece no topo do app e no rodapé do PDF.
-- ============================================================================
