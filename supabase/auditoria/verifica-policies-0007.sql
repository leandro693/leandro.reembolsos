-- Auditoria (SOMENTE LEITURA) — verifica o estado DEPOIS da migration 0007.
-- Deve listar 1 policy de INSERT (`<tabela>_sys_ins`, to postgres) por tabela.
select tablename, policyname, cmd, roles, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('eventos_auditoria','eventos_seguranca','uso_ia',
                    'consumo_mensal','alertas','contadores')
  and cmd = 'INSERT'
order by tablename, policyname;
