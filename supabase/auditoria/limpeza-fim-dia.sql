-- Fecho do dia: captura se orfa.teste foi ADOTADA (vinculo>0) e remove contas de teste/órfãs.
-- Toca só auth.users (dados de teste), NÃO schema. Protege o dono.
with estado_orfa as (
  select
    (select count(*) from auth.users where lower(email)='orfa.teste@maradel.com.br') as auth,
    (select count(*) from public.usuarios where lower(email)='orfa.teste@maradel.com.br') as usuarios,
    (select count(*) from public.empresa_usuarios eu join public.usuarios u on u.id=eu.usuario_id
       where lower(u.email)='orfa.teste@maradel.com.br') as vinculo
),
orfas as (
  select au.id from auth.users au
  where not exists (select 1 from public.empresa_usuarios eu where eu.usuario_id=au.id)
    and coalesce((select is_owner from public.usuarios u where u.id=au.id), false) = false
),
alvo as (
  select id from auth.users where lower(email) in
    ('orfa.teste@maradel.com.br','teste.acesso@maradel.com.br','teste.acesso@maradel.com','leandrolfsg@gmail.com')
  union
  select id from orfas
),
del as (delete from auth.users u using alvo a where u.id=a.id returning u.email)
select json_build_object(
  'orfa_teste_antes', (select row_to_json(e) from estado_orfa e),
  'removidas', (select json_agg(email order by email) from del),
  'total_removidas', (select count(*) from del)
) as res;
