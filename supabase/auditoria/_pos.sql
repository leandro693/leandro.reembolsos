select json_build_object(
  'modo_lancamento_existe', exists (select 1 from information_schema.columns
     where table_schema='public' and table_name='empresa_usuarios' and column_name='modo_lancamento'),
  'creditos_operador_existe', to_regclass('public.creditos_operador') is not null,
  'rpcs', (select json_agg(proname order by proname) from pg_proc
     where proname in ('lancar_credito','set_modo_operador','remover_credito','saldo_operador')),
  'empresa_usuarios_total', (select count(*) from public.empresa_usuarios),
  'todos_despesa', (select count(*)=count(*) filter (where modo_lancamento='despesa') from public.empresa_usuarios),
  'linhas', (select json_agg(row_to_json(t) order by t.criado_em) from
     (select usuario_id, papel, modo_lancamento from public.empresa_usuarios) t)
) as pos;
