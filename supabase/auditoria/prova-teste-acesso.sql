-- PROVA v55: teste.acesso criado ponta a ponta? (Auth + usuarios + empresa_usuarios + senha_provisoria)
select json_build_object(
  'auth', (select json_agg(row_to_json(a)) from (
     select email, email_confirmed_at is not null as email_confirmado,
            (raw_user_meta_data->>'nome') as nome_meta,
            (raw_user_meta_data->>'senha_provisoria') as senha_provisoria
     from auth.users where lower(email)=lower('teste.acesso@maradel.com.br')) a),
  'usuarios', (select json_agg(row_to_json(u)) from (
     select nome, email, is_owner from public.usuarios where lower(email)=lower('teste.acesso@maradel.com.br')) u),
  'empresa_usuarios', (select json_agg(row_to_json(v)) from (
     select eu.papel, eu.ativo, coalesce(e.nome_fantasia,e.razao_social) as empresa
     from public.empresa_usuarios eu
     left join public.empresas e on e.id=eu.empresa_id
     join public.usuarios u on u.id=eu.usuario_id
     where lower(u.email)=lower('teste.acesso@maradel.com.br')) v)
) as prova;
