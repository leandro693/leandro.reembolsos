-- Auditoria (SOMENTE LEITURA) — captura o estado ANTES da migration 0007.
-- Lista todas as policies atuais das tabelas afetadas, para servir de referência
-- de reversão. Não altera nada.
select tablename, policyname, cmd, roles, qual as using_expr, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('eventos_auditoria','eventos_seguranca','uso_ia',
                    'consumo_mensal','alertas','contadores')
order by tablename, policyname;
