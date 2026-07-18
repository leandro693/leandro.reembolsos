-- ============================================================================
-- REEMBOLSOS MARADEL - v2 Fase 1 (Fundação): perfis de acesso, fornecedores e
-- campos de nota. Rode UMA VEZ no SQL Editor, depois do supabase-setup.sql.
-- É seguro rodar de novo (idempotente).
-- ============================================================================

-- ---------- Papel do usuário (admin / operador / financeiro) ----------
alter table public.perfis add column if not exists papel text not null default 'operador';
-- admin      = vê tudo, gerencia cadastros (Leandro)
-- operador   = lança e vê apenas os próprios (Márcio, Adelson)
-- financeiro = vê todos os reembolsos, para conferência e relatórios (Eliciane)

-- Função que devolve o papel de quem está chamando (sem recursão de RLS).
create or replace function public.papel_do_usuario()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select papel from public.perfis where user_id = auth.uid()), 'operador');
$$;

-- ---------- Cadastro de fornecedores / prestadores ----------
create table if not exists public.fornecedores (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null,
  cnpj       text default '',
  tipo       text default 'fornecedor',   -- 'fornecedor' ou 'prestador'
  contato    text default '',
  endereco   text default '',
  criado_por uuid default auth.uid() references auth.users(id) on delete set null,
  criado_em  timestamptz default now()
);
create index if not exists idx_forn_cnpj on public.fornecedores(cnpj);
create index if not exists idx_forn_nome on public.fornecedores(lower(nome));

alter table public.fornecedores enable row level security;
drop policy if exists forn_select on public.fornecedores;
drop policy if exists forn_insert on public.fornecedores;
drop policy if exists forn_update on public.fornecedores;
drop policy if exists forn_delete on public.fornecedores;
-- Todos os autenticados leem e podem criar (a IA cria com sua confirmação);
-- editar/apagar só admin.
create policy forn_select on public.fornecedores for select to authenticated using (true);
create policy forn_insert on public.fornecedores for insert to authenticated with check (true);
create policy forn_update on public.fornecedores for update to authenticated using (public.papel_do_usuario() = 'admin');
create policy forn_delete on public.fornecedores for delete to authenticated using (public.papel_do_usuario() = 'admin');

-- ---------- Novos campos no lançamento ----------
alter table public.lancamentos add column if not exists numero_nota   text default '';
alter table public.lancamentos add column if not exists chave_nf      text default '';
alter table public.lancamentos add column if not exists cnpj          text default '';
alter table public.lancamentos add column if not exists fornecedor_id uuid references public.fornecedores(id) on delete set null;

-- ---------- Permissões por papel nos lançamentos ----------
-- operador: só os próprios | financeiro e admin: todos | admin também edita/apaga tudo.
drop policy if exists lanc_select on public.lancamentos;
drop policy if exists lanc_insert on public.lancamentos;
drop policy if exists lanc_update on public.lancamentos;
drop policy if exists lanc_delete on public.lancamentos;
create policy lanc_select on public.lancamentos for select using (
  auth.uid() = user_id or public.papel_do_usuario() in ('admin','financeiro')
);
create policy lanc_insert on public.lancamentos for insert with check (auth.uid() = user_id);
create policy lanc_update on public.lancamentos for update using (
  auth.uid() = user_id or public.papel_do_usuario() = 'admin'
);
create policy lanc_delete on public.lancamentos for delete using (
  auth.uid() = user_id or public.papel_do_usuario() = 'admin'
);

-- ============================================================================
-- Definir os papéis. Ajuste os e-mails conforme forem criados os usuários.
-- Leandro é o administrador:
update public.perfis p set papel = 'admin'
  from auth.users u where p.user_id = u.id and u.email = 'leandro@maradelcontabil.com';

-- Quando criar os outros, rode (troque os e-mails reais):
--   update public.perfis p set papel='operador'   from auth.users u
--     where p.user_id=u.id and u.email in ('marcio@maradelcontabil.com','adelson@maradelcontabil.com');
--   update public.perfis p set papel='financeiro' from auth.users u
--     where p.user_id=u.id and u.email = 'eliciane@maradelcontabil.com';
-- ============================================================================
