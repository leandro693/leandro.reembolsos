-- Auditoria (SOMENTE LEITURA) — apoio à migration 0007.
-- Descobre o papel dono das funções de trigger/log (SECURITY DEFINER) para que
-- a policy de INSERT restrita-ao-sistema use "to <papel>" exato. Não altera nada.
select proname, proowner::regrole as dono
from pg_proc
where proname in (
  'fn_auditar_lancamento','fn_lanc_before_insert',
  'registrar_evento_seguranca','registrar_leitura_ia','registrar_alerta'
)
order by proname;
