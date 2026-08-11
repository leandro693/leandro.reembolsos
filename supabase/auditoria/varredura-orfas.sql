-- Varredura de contas ÓRFÃS no Auth (sem vínculo em empresa_usuarios) + remoção.
-- Protege o dono (is_owner nunca é apagado). Mostra data de criação (para saber se é v55).
with orfas as (
  select au.id, au.email, au.created_at,
         coalesce((select u.is_owner from public.usuarios u where u.id=au.id), false) as is_owner,
         (select count(*) from public.usuarios u where u.id=au.id) as tem_usuarios_row
  from auth.users au
  where not exists (select 1 from public.empresa_usuarios eu where eu.usuario_id = au.id)
),
alvo as (select id from orfas where is_owner = false),   -- nunca apaga o dono
del as (delete from auth.users u using alvo a where u.id = a.id returning u.email)
select json_build_object(
  'orfas_encontradas', (select json_agg(json_build_object(
     'email',email,'criada_em',created_at,'is_owner',is_owner,'tem_usuarios_row',tem_usuarios_row) order by created_at) from orfas),
  'removidas', (select json_agg(email order by email) from del),
  'total_removidas', (select count(*) from del)
) as res;
