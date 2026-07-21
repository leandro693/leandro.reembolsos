-- Auditoria (SOMENTE LEITURA) — captura o estado ANTES da migration 0008.
-- Guarda a expressão atual da policy lanc_select para servir de reversão.
select policyname, cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public' and tablename = 'lancamentos'
order by policyname;
