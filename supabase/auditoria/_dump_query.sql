select json_build_object(
  'tabelas', (select json_agg(table_name order by table_name) from information_schema.tables
     where table_schema='public' and table_type='BASE TABLE'),
  'colunas', (select json_agg(row_to_json(c)) from (
     select table_name, column_name, data_type, is_nullable, column_default
     from information_schema.columns where table_schema='public'
     order by table_name, ordinal_position) c),
  'policies', (select json_agg(row_to_json(p)) from (
     select tablename, policyname, cmd from pg_policies where schemaname='public'
     order by tablename, policyname) p),
  'funcoes', (select json_agg(proname order by proname) from pg_proc p
     join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')
) as schema;
