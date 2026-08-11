-- DECISIVO: o service_role IGNORA RLS? E por que o INSERT em usuarios passou mas em
-- empresa_usuarios não? Compara rolbypassrls e o estado de RLS/policies das duas tabelas.
select json_build_object(
  'service_role_bypassa_rls', (select rolbypassrls from pg_roles where rolname='service_role'),
  'authenticated_bypassa_rls', (select rolbypassrls from pg_roles where rolname='authenticated'),
  'usuarios_rls', (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='usuarios'),
  'usuarios_policies', (select json_agg(json_build_object('nome',polname,'cmd',polcmd::text,'check',pg_get_expr(polwithcheck,polrelid)))
     from pg_policy where polrelid='public.usuarios'::regclass),
  'empresa_usuarios_rls', (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='empresa_usuarios')
) as diag;
