-- DIAGNÓSTICO read-only (v52) — achados 1 e 2 da gestão de usuários.
-- Não altera nada. Objetivo: saber o que leandrolfsg@gmail.com REALMENTE é
-- (is_owner? papel? vínculo? qual empresa?) e o mapa de membros por empresa.
select json_build_object(
  'auth_leandrolfsg', (
    select json_agg(row_to_json(a)) from (
      select id, email, created_at, (raw_user_meta_data->>'senha_provisoria') as senha_provisoria
      from auth.users where lower(email) = lower('leandrolfsg@gmail.com')
    ) a),
  'usuarios_leandrolfsg', (
    select json_agg(row_to_json(u)) from (
      select id, email, is_owner, deleted_at from public.usuarios
      where lower(email) = lower('leandrolfsg@gmail.com')
    ) u),
  'vinculos_leandrolfsg', (
    select json_agg(row_to_json(v)) from (
      select eu.empresa_id, eu.papel, eu.ativo as vinculo_ativo,
             coalesce(e.nome_fantasia, e.razao_social) as empresa
      from public.empresa_usuarios eu
      left join public.empresas e on e.id = eu.empresa_id
      join public.usuarios u on u.id = eu.usuario_id
      where lower(u.email) = lower('leandrolfsg@gmail.com')
    ) v),
  'donos_is_owner', (
    select json_agg(row_to_json(d)) from (
      select email, is_owner from public.usuarios where is_owner = true
    ) d),
  'membros_por_empresa', (
    select json_agg(row_to_json(m)) from (
      select coalesce(e.nome_fantasia, e.razao_social) as empresa,
             u.email, u.is_owner, eu.papel, eu.ativo as vinculo_ativo
      from public.empresa_usuarios eu
      join public.usuarios u on u.id = eu.usuario_id
      left join public.empresas e on e.id = eu.empresa_id
      order by 1, 4, 2
    ) m),
  'orfaos_auth_sem_usuarios', (
    select json_agg(row_to_json(o)) from (
      select au.email from auth.users au
      left join public.usuarios pu on pu.id = au.id
      where pu.id is null
    ) o)
) as diag;
