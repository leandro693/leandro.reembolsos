-- ============================================================================
-- REEMBOLSOS MARADEL - papéis de acesso da equipe.
-- Define quem é admin, operador e financeiro, por e-mail. Cria o perfil se
-- ainda não existir, então pode rodar ANTES ou DEPOIS do primeiro login.
-- É seguro rodar de novo (idempotente). Ajuste os e-mails se forem diferentes.
--
--   admin      = vê tudo e gerencia cadastros            (Leandro)
--   operador   = lança e vê apenas os próprios           (Márcio, Adelson)
--   financeiro = vê todos os reembolsos, somente leitura (Eliciane)
-- ============================================================================

insert into public.perfis (user_id, nome, papel)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'nome',''), initcap(split_part(u.email,'@',1))),
       v.papel
from auth.users u
join (values
  ('leandro@maradelcontabil.com',  'admin'),
  ('marcio@maradelcontabil.com',   'operador'),
  ('adelson@maradelcontabil.com',  'operador'),
  ('eliciane@maradelcontabil.com', 'financeiro')
) as v(email, papel) on lower(u.email) = lower(v.email)
on conflict (user_id) do update set papel = excluded.papel;

-- Conferência: lista os papéis já aplicados.
select p.papel, p.nome, u.email
from public.perfis p join auth.users u on u.id = p.user_id
order by p.papel, u.email;
