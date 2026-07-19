-- ============================================================================
-- 0005 — Código de sistema externo (ex.: Omie) na categoria (e no setor).
-- Permite mapear a categoria para o código do ERP/contábil. Manual por enquanto;
-- a integração automática (Omie etc.) é Fase 3. Idempotente.
-- ============================================================================
alter table public.categorias add column if not exists codigo_externo text default '';
alter table public.setores    add column if not exists codigo_externo text default '';
select 'codigo_externo ok' as status;
