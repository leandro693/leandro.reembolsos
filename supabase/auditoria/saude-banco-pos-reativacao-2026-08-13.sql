-- Verificação de SAÚDE do banco após reativação (pausa por inatividade). READ-ONLY.
-- Confirma: banco responde, migration 0014 aplicada (modo_lancamento, creditos_operador, 4 RPCs),
-- e que os dados seguem lá (contagens + distribuição de modo). Não altera nada.
select json_build_object(
  'agora', now(),
  'empresa_usuarios_linhas', (select count(*) from public.empresa_usuarios),
  'usuarios_linhas',         (select count(*) from public.usuarios),
  'empresas_linhas',         (select count(*) from public.empresas),
  'lancamentos_linhas',      (select count(*) from public.lancamentos),
  'modo_lancamento_existe',  exists(select 1 from information_schema.columns
      where table_schema='public' and table_name='empresa_usuarios' and column_name='modo_lancamento'),
  'creditos_operador_existe', to_regclass('public.creditos_operador') is not null,
  'creditos_operador_linhas', (select count(*) from public.creditos_operador),
  'rpcs_credito', (select array_agg(proname order by proname) from pg_proc
      where proname in ('lancar_credito','set_modo_operador','remover_credito','saldo_operador')),
  'modo_distribuicao', (select json_object_agg(modo_lancamento, c)
      from (select modo_lancamento, count(*) c from public.empresa_usuarios group by modo_lancamento) t)
) as saude;
