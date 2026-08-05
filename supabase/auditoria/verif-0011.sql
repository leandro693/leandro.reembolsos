-- READ-ONLY verificação da 0011.
select json_build_object(
  'tabela_existe', to_regclass('public.motivos_exclusao') is not null,
  'rls_habilitada', (select relrowsecurity from pg_class where oid='public.motivos_exclusao'::regclass),
  'policies', (select json_agg(json_build_object('nome',policyname,'cmd',cmd,'qual',qual,'with_check',with_check) order by policyname)
               from pg_policies where schemaname='public' and tablename='motivos_exclusao'),
  'coluna_motivo_exclusao', (select json_build_object('existe', count(*)>0, 'nullable', max(is_nullable))
     from information_schema.columns
     where table_schema='public' and table_name='lancamentos' and column_name='motivo_exclusao'),
  'seed_por_empresa', (select json_agg(row_to_json(t)) from (
     select empresa_id, count(*) as motivos, bool_and(ativo) as todos_ativos
     from public.motivos_exclusao group by empresa_id order by empresa_id) t),
  'total_empresas', (select count(*) from public.empresas)
) as verif;
