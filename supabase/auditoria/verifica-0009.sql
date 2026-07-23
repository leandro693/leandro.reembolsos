-- Auditoria (SOMENTE LEITURA) — verifica o estado DEPOIS da migration 0009.
select
  (select coalesce(json_agg(indexdef), '[]'::json)
     from pg_indexes where schemaname='public' and tablename='comprovantes') as indices,
  (select coalesce(json_agg(row_to_json(p)), '[]'::json) from (
      select policyname, cmd, roles::text as roles, with_check
      from pg_policies where schemaname='public' and tablename='comprovantes'
      order by policyname) p) as policies,
  (select json_build_object(
      'nome', c.conname,
      'on_delete', case c.confdeltype when 'c' then 'CASCADE' when 'r' then 'RESTRICT'
                                      when 'a' then 'NO ACTION' when 'n' then 'SET NULL' else c.confdeltype::text end,
      'referencia', cl.relname)
     from pg_constraint c join pg_class cl on cl.oid = c.confrelid
    where c.conname = 'comprovantes_lancamento_fk') as fk,
  (select json_agg(tgname) from pg_trigger
    where tgrelid = 'public.lancamentos'::regclass and not tgisinternal) as triggers_lancamentos;
