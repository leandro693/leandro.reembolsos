-- Cria uma ÓRFÃ controlada para testar a ADOÇÃO do v56: conta no Auth + usuarios,
-- SEM vínculo em empresa_usuarios e SEM senha (não loga; é só alvo do teste).
with novo as (
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'orfa.teste@maradel.com.br', now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{"nome":"Orfa Teste"}'::jsonb)
  returning id
),
ins as (
  insert into public.usuarios (id, nome, email)
  select id, 'Orfa Teste', 'orfa.teste@maradel.com.br' from novo returning id
)
select json_build_object(
  'criada', (select id from ins),
  'auth', (select count(*) from auth.users where email='orfa.teste@maradel.com.br'),
  'usuarios', (select count(*) from public.usuarios where email='orfa.teste@maradel.com.br'),
  'empresa_usuarios', (select count(*) from public.empresa_usuarios eu join public.usuarios u on u.id=eu.usuario_id where u.email='orfa.teste@maradel.com.br')
) as res;
