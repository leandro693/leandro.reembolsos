-- ============================================================================
-- 0007 — RLS: escrita de logs/metering pelo SISTEMA (não pelo usuário).
--
-- Contexto do bug (produção): tabelas de log têm RLS habilitada mas só policy de
-- SELECT (nenhuma de INSERT). A auditoria roda pelo trigger fn_auditar_lancamento
-- (SECURITY DEFINER, dono `postgres`) a cada INSERT/UPDATE de lancamentos; como o
-- papel `postgres` no Supabase NÃO tem BYPASSRLS, o insert em eventos_auditoria era
-- NEGADO pela RLS, derrubando toda edição e todo soft-delete de lancamentos com
-- "new row violates row-level security policy".
--
-- Correção: policy de INSERT restrita ao papel do sistema (`to postgres`) — o papel
-- efetivo APENAS dentro das funções SECURITY DEFINER (dono confirmado = postgres para
-- fn_auditar_lancamento, fn_lanc_before_insert, registrar_evento_seguranca,
-- registrar_leitura_ia, registrar_alerta). Clientes (authenticated/anon) continuam
-- SEM policy de INSERT nessas tabelas → não conseguem escrever/forjar log direto pela
-- API: o log segue não-adulterável. O `with check (true)` é seguro porque o alcance
-- já está restrito pelo papel, não pelo conteúdo.
--
-- Tabelas cobertas:
--   eventos_auditoria  -> OBRIGATÓRIO (trigger fn_auditar_lancamento)
--   eventos_seguranca  -> defesa em profundidade (registrar_evento_seguranca)
--   uso_ia             -> defesa (registrar_leitura_ia)
--   consumo_mensal     -> defesa (registrar_leitura_ia)
--   alertas            -> defesa (registrar_alerta)
--   contadores         -> defesa (trigger fn_lanc_before_insert)
-- Hoje as tabelas escritas via Edge Function usam service role (ignora RLS) e por
-- isso ainda funcionam; a policy fecha o padrão de vez e é inócua nesses casos.
--
-- ADITIVA e IDEMPOTENTE: cria apenas policies novas `<tabela>_sys_ins` (Postgres não
-- tem CREATE POLICY IF NOT EXISTS, então drop-if-exists + create). NÃO altera nem
-- remove policies existentes, NÃO toca dados, NÃO mexe em lancamentos, parcelas ou
-- comprovantes.
-- ============================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'eventos_auditoria',
    'eventos_seguranca',
    'uso_ia',
    'consumo_mensal',
    'alertas',
    'contadores'
  ] loop
    -- Garante RLS ligada (já está, por 0001; mantém a migration auto-suficiente).
    execute format('alter table public.%I enable row level security', t);
    -- (Re)cria só a policy de INSERT do sistema, sem tocar nas demais policies.
    execute format('drop policy if exists %I_sys_ins on public.%I', t, t);
    execute format(
      'create policy %I_sys_ins on public.%I for insert to postgres with check (true)',
      t, t);
  end loop;
end $$;

select 'rls insert do sistema (0007) ok' as status;
