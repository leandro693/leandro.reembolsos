-- LIMPEZA autorizada (Achado 2): remove a conta ÓRFÃ leandrolfsg@gmail.com do Auth.
-- Guarda de segurança: só apaga se NÃO houver linha em public.usuarios (i.e., é órfã de fato)
-- e NÃO houver vínculo em empresa_usuarios. Não toca schema nem dados de reembolsos.
with alvo as (
  select au.id, au.email
  from auth.users au
  left join public.usuarios pu on pu.id = au.id
  where lower(au.email) = lower('leandrolfsg@gmail.com')
    and pu.id is null
    and not exists (select 1 from public.empresa_usuarios eu where eu.usuario_id = au.id)
)
delete from auth.users u
using alvo a
where u.id = a.id
returning a.email as removida;
