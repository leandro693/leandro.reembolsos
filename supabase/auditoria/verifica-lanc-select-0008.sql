-- Auditoria (SOMENTE LEITURA) — verifica o estado DEPOIS da 0008.
-- A lanc_select não pode mais conter "deleted_at" na expressão USING.
select policyname, cmd,
       (qual ilike '%deleted_at%') as ainda_filtra_deleted_at,
       qual as using_expr
from pg_policies
where schemaname = 'public' and tablename = 'lancamentos' and policyname = 'lanc_select';
