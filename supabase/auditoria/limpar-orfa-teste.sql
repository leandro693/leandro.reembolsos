with alvo as (select id, email from auth.users where lower(email)=lower('teste.acesso@maradel.com.br'))
delete from auth.users u using alvo a where u.id = a.id returning a.email as removida;
