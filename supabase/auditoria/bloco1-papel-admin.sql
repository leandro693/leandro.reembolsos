-- Auditoria (SOMENTE LEITURA) — Bloco 1: unificar fonte de papel.
-- Lista todos os usuarios com perfis.papel = 'admin' e mostra, para cada um,
-- se e dono (is_owner) e se tem vinculo como gestor em empresa_usuarios.
-- Objetivo: garantir que ninguem perca acesso ao migrar o gate para
-- empresa_usuarios + is_owner. Nao altera nada.
select
  p.user_id,
  u.email,
  p.papel                          as perfil_papel,
  coalesce(us.is_owner, false)     as is_owner,
  exists (
    select 1 from empresa_usuarios eu
    where eu.usuario_id = p.user_id
      and eu.papel = 'gestor'
      and coalesce(eu.ativo, true)
  )                                as gestor_em_empresa
from perfis p
left join auth.users u  on u.id  = p.user_id
left join usuarios    us on us.id = p.user_id
where p.papel = 'admin'
order by u.email;
