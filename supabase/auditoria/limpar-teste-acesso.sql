-- LIMPEZA autorizada do teste.acesso@maradel.com.br + captura do estado ANTES de apagar
-- (para sabermos se era órfã de fato, ou se a v54 chegou a criar usuarios/vínculo).
-- Apaga do Auth; o cascade remove public.usuarios e empresa_usuarios.
with estado as (
  select
    (select count(*) from auth.users au where lower(au.email)=lower('teste.acesso@maradel.com.br')) as tinha_auth,
    (select count(*) from public.usuarios u where lower(u.email)=lower('teste.acesso@maradel.com.br')) as tinha_usuarios,
    (select count(*) from public.empresa_usuarios eu
       join public.usuarios u on u.id=eu.usuario_id
       where lower(u.email)=lower('teste.acesso@maradel.com.br')) as tinha_vinculo
),
del as (
  delete from auth.users where lower(email)=lower('teste.acesso@maradel.com.br') returning email
)
select json_build_object(
  'removida',       (select email from del),
  'tinha_auth',     (select tinha_auth from estado),
  'tinha_usuarios', (select tinha_usuarios from estado),
  'tinha_vinculo',  (select tinha_vinculo from estado)
) as res;
