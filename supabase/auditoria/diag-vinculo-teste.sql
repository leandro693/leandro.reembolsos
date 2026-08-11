-- DIAGNÓSTICO: por que o vínculo (empresa_usuarios) do teste.acesso falhou na Edge Function?
-- Tenta o mesmo insert que a função faz. Se der certo, o problema é o on_conflict via PostgREST;
-- se der erro, a mensagem revela a causa (constraint/trigger/schema).
insert into public.empresa_usuarios (empresa_id, usuario_id, papel, ativo)
select e.id, u.id, 'operador', true
from public.empresas e
cross join public.usuarios u
where u.email = 'teste.acesso@maradel.com.br'
  and e.id = (select id from public.empresas order by criado_em limit 1)
on conflict (empresa_id, usuario_id) do update set papel = excluded.papel, ativo = true
returning empresa_id, usuario_id, papel, ativo;
