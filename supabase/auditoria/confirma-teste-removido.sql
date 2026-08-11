-- Confirma que teste.acesso@maradel.com.br sumiu de tudo (Auth + usuarios + empresa_usuarios).
select json_build_object(
  'auth',            (select count(*) from auth.users where lower(email)=lower('teste.acesso@maradel.com.br')),
  'usuarios',        (select count(*) from public.usuarios where lower(email)=lower('teste.acesso@maradel.com.br')),
  'empresa_usuarios',(select count(*) from public.empresa_usuarios eu join public.usuarios u on u.id=eu.usuario_id where lower(u.email)=lower('teste.acesso@maradel.com.br')),
  'orfaos_auth_sem_usuarios',(select count(*) from auth.users au left join public.usuarios pu on pu.id=au.id where pu.id is null)
) as res;
