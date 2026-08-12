select json_build_object(
  'creditos_operador_existe', to_regclass('public.creditos_operador') is not null,
  'modo_lancamento_existe', exists (select 1 from information_schema.columns
     where table_schema='public' and table_name='empresa_usuarios' and column_name='modo_lancamento'),
  'rpcs_existem', exists (select 1 from pg_proc where proname in ('lancar_credito','set_modo_operador','remover_credito','saldo_operador'))
) as antes;
