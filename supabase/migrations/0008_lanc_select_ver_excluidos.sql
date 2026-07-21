-- ============================================================================
-- 0008 — lanc_select passa a enxergar linhas excluídas (deleted_at preenchido).
--
-- Contexto do bug (produção): o soft-delete faz UPDATE deleted_at=now(); a releitura
-- pós-UPDATE (RETURNING) aplica a policy lanc_select, que exigia `deleted_at IS NULL`.
-- A linha recém-excluída deixa de passar nessa SELECT → a operação inteira cai com
-- 42501 "new row violates row-level security policy for table lancamentos".
--
-- Correção: remover o gate `deleted_at IS NULL` do escopo de quem tem direito. Assim
-- dono/autor/gestor/financeiro passam a enxergar TAMBÉM as linhas excluídas da própria
-- empresa (necessário para a releitura pós-delete e para uma futura "lixeira"/restauração).
-- O isolamento por empresa é mantido: todo ramo não-dono continua exigindo
-- `empresa_id in (select empresas_do_usuario())`. O operacional (listas/dashboards) deixa
-- de ver excluídos por um filtro `deleted_at is null` no FRONT (mesma leva), não mais na RLS.
--
-- Idempotente (drop policy if exists + create). Reversível: expressão original em
-- supabase/auditoria/lanc-select-antes-0008.txt. NÃO toca lanc_insert/lanc_update/
-- lanc_delete nem parcelas/comprovantes.
-- ============================================================================

drop policy if exists lanc_select on public.lancamentos;
create policy lanc_select on public.lancamentos for select using (
  public.usuario_e_owner()
  or (empresa_id in (select public.empresas_do_usuario())
      and (user_id = auth.uid() or public.meu_papel(empresa_id) in ('financeiro','gestor')))
);

select 'lanc_select ve excluidos (0008) ok' as status;
