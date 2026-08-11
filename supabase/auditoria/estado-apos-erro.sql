-- O que a tentativa v54 (que deu "erro ao processar") deixou? Diz onde o fluxo parou.
select json_build_object(
  'auth',            (select count(*) from auth.users where lower(email)=lower('teste.acesso@maradel.com.br')),
  'usuarios',        (select count(*) from public.usuarios where lower(email)=lower('teste.acesso@maradel.com.br')),
  'empresa_usuarios',(select count(*) from public.empresa_usuarios eu join public.usuarios u on u.id=eu.usuario_id where lower(u.email)=lower('teste.acesso@maradel.com.br')),
  'eventos_seguranca_recentes', (select json_agg(row_to_json(e)) from (
     select tipo, severidade, created_at from public.eventos_seguranca order by created_at desc limit 3) e)
) as res;
