-- Auditoria (SOMENTE LEITURA) — estado estrutural DEPOIS da 0010.
select
  (select json_build_object('existe', count(*)>0, 'default', max(column_default), 'nullable', max(is_nullable))
     from information_schema.columns
    where table_schema='public' and table_name='lancamentos' and column_name='numero_nota_extraido') as coluna,
  (select coalesce(json_agg(indexname order by indexname), '[]'::json)
     from pg_indexes where schemaname='public' and tablename='lancamentos'
       and indexname in ('idx_lanc_dup_doc','idx_lanc_dup_logica')) as indices_dedup,
  (select coalesce(json_agg(json_build_object('policy', policyname, 'cmd', cmd, 'roles', roles::text)), '[]'::json)
     from pg_policies where schemaname='public' and tablename='lancamentos' and policyname='lanc_sys_sel') as policy_sistema,
  (select coalesce(json_agg(json_build_object(
       'nome', p.proname, 'security_definer', p.prosecdef, 'dono', pg_get_userbyid(p.proowner),
       'guarda_pertencimento', (p.prosrc ilike '%meu_papel(p_empresa)%' and p.prosrc ilike '%sem acesso%'))
       order by p.proname), '[]'::json)
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('checar_duplicata_documento','checar_duplicata_hash')) as rpcs,
  (select p.prosrc ilike '%btrim(l.numero_nota_extraido) <> %'
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='checar_duplicata_documento') as forte_exige_numero;
