-- ============================================================================
-- REEMBOLSOS MARADEL - v3: fornecedor com telefone e e-mail separados.
-- Rode UMA VEZ no SQL Editor, depois do supabase-v2-fundacao.sql.
-- É seguro rodar de novo (idempotente).
-- ============================================================================

alter table public.fornecedores add column if not exists telefone text default '';
alter table public.fornecedores add column if not exists email    text default '';

-- Aproveita o campo "contato" antigo como telefone, quando fizer sentido.
update public.fornecedores
   set telefone = contato
 where (telefone is null or telefone = '')
   and contato is not null and contato <> ''
   and position('@' in contato) = 0;   -- se tinha @, provavelmente era e-mail

update public.fornecedores
   set email = contato
 where (email is null or email = '')
   and contato is not null and position('@' in contato) > 0;

-- Os campos antigos "tipo" e "contato" continuam existindo (sem uso no app),
-- não precisam ser removidos.
