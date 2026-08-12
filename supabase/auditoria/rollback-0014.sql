-- ROLLBACK da 0014 (crédito/saldo). Remove RPCs, tabela nova e a coluna.
-- Tabela creditos_operador é NOVA (sem dados legados) — drop é seguro.
drop function if exists public.lancar_credito(uuid,uuid,numeric,date,text);
drop function if exists public.set_modo_operador(uuid,uuid,text);
drop function if exists public.remover_credito(uuid);
drop function if exists public.saldo_operador(uuid,uuid);
drop table if exists public.creditos_operador;
alter table public.empresa_usuarios drop constraint if exists empresa_usuarios_modo_chk;
alter table public.empresa_usuarios drop column if exists modo_lancamento;
select 'rollback 0014 ok (credito/saldo removido; empresa_usuarios volta ao original)' as status;
