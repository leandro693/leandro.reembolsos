select json_build_object(
  'auth', (select count(*) from auth.users where email='orfa.teste@maradel.com.br'),
  'usuarios', (select count(*) from public.usuarios where email='orfa.teste@maradel.com.br'),
  'empresa_usuarios', (select count(*) from public.empresa_usuarios eu join public.usuarios u on u.id=eu.usuario_id where u.email='orfa.teste@maradel.com.br')
) as res;
