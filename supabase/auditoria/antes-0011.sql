-- READ-ONLY "antes" da 0011: confirma que nada existe ainda + count de lancamentos.
select json_build_object(
  'motivos_exclusao_existe', to_regclass('public.motivos_exclusao') is not null,
  'lancamentos_tem_motivo_exclusao', exists (
     select 1 from information_schema.columns
     where table_schema='public' and table_name='lancamentos' and column_name='motivo_exclusao'),
  'lancamentos_total', (select count(*) from public.lancamentos)
) as antes;
