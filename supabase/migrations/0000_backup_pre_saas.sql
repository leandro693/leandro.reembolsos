-- ============================================================================
-- 0000 — BACKUP em banco antes da refundação SaaS (multiempresa).
-- Cria cópias das tabelas atuais. Idempotente (só cria se não existir).
-- Para restaurar: os dados originais ficam em zz_backup_*.
-- ============================================================================
create table if not exists public.zz_backup_perfis        as select * from public.perfis;
create table if not exists public.zz_backup_lancamentos    as select * from public.lancamentos;
create table if not exists public.zz_backup_fornecedores   as select * from public.fornecedores;
