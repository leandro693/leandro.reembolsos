-- Auditoria (SOMENTE LEITURA) — estado ANTES da migration 0009 (duplicata por hash).
-- 1) policies vivas de comprovantes  2) índices vivos  3) contagem de linhas/hash.
-- Não altera nada.
select
  (select coalesce(json_agg(row_to_json(p)), '[]'::json) from (
      select policyname, cmd, roles::text as roles, qual as using_expr, with_check
      from pg_policies
      where schemaname = 'public' and tablename = 'comprovantes'
      order by policyname
   ) p) as policies_comprovantes,
  (select coalesce(json_agg(indexdef), '[]'::json)
     from pg_indexes where schemaname = 'public' and tablename = 'comprovantes') as indices_comprovantes,
  (select json_build_object('total', count(*), 'com_hash', count(arquivo_hash))
     from public.comprovantes) as contagem;
