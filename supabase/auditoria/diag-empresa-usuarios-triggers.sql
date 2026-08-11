-- DIAGNÓSTICO read-only: por que o INSERT de empresa_usuarios falha pela Edge Function
-- (service_role via PostgREST) mas passa no SQL direto (superusuário)?
-- Olha triggers, RLS e policies da tabela.
select json_build_object(
  'triggers', (select json_agg(row_to_json(t)) from (
     select tg.tgname, p.proname as funcao,
            pg_get_triggerdef(tg.oid) as definicao
     from pg_trigger tg
     join pg_class c on c.oid = tg.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
     join pg_proc p on p.oid = tg.tgfoid
     where n.nspname='public' and c.relname='empresa_usuarios' and not tg.tgisinternal) t),
  'rls_habilitada', (select c.relrowsecurity
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relname='empresa_usuarios'),
  'policies', (select json_agg(row_to_json(pol)) from (
     select polname, polcmd::text,
            pg_get_expr(polqual, polrelid) as using_expr,
            pg_get_expr(polwithcheck, polrelid) as check_expr
     from pg_policy where polrelid = 'public.empresa_usuarios'::regclass) pol),
  'grants_service_role', (select json_agg(row_to_json(g)) from (
     select grantee, privilege_type from information_schema.role_table_grants
     where table_schema='public' and table_name='empresa_usuarios'
       and grantee in ('service_role','authenticated','anon')) g)
) as diag;
