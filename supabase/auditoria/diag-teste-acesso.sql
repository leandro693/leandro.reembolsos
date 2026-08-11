-- DIAGNÓSTICO read-only: estado da conta teste.acesso@maradel.com.br após as tentativas de criar.
-- Diz se a criação foi ponta a ponta (Auth + usuarios + empresa_usuarios) ou parou no meio (órfão).
select json_build_object(
  'auth', (select json_agg(row_to_json(a)) from (
     select id, email, created_at, email_confirmed_at is not null as email_confirmado,
            (raw_user_meta_data->>'nome') as nome_meta,
            (raw_user_meta_data->>'senha_provisoria') as senha_provisoria
     from auth.users where lower(email)=lower('teste.acesso@maradel.com.br')) a),
  'usuarios', (select json_agg(row_to_json(u)) from (
     select id, nome, email, is_owner from public.usuarios
     where lower(email)=lower('teste.acesso@maradel.com.br')) u),
  'empresa_usuarios', (select json_agg(row_to_json(v)) from (
     select eu.empresa_id, eu.papel, eu.ativo, coalesce(e.nome_fantasia,e.razao_social) as empresa
     from public.empresa_usuarios eu
     left join public.empresas e on e.id=eu.empresa_id
     join public.usuarios u on u.id=eu.usuario_id
     where lower(u.email)=lower('teste.acesso@maradel.com.br')) v),
  'orfaos_auth_sem_usuarios', (select json_agg(row_to_json(o)) from (
     select au.email from auth.users au
     left join public.usuarios pu on pu.id=au.id
     where pu.id is null) o)
) as diag;
