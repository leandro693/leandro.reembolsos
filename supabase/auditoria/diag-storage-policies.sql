-- Policies VIVAS de storage.objects (bucket comprovantes) + bucket público?
select json_build_object(
  'bucket_comprovantes', (select json_agg(row_to_json(b)) from (
     select id, name, public from storage.buckets where id='comprovantes') b),
  'policies_storage_objects', (select json_agg(row_to_json(p)) from (
     select polname,
            case polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' else polcmd::text end as cmd,
            pg_get_expr(polqual, polrelid) as using_expr,
            pg_get_expr(polwithcheck, polrelid) as check_expr
     from pg_policy where polrelid='storage.objects'::regclass) p)
) as diag;
