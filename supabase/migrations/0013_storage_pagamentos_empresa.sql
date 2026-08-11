-- ============================================================================
-- 0013 — Storage (bucket "comprovantes"): PARTE 2 — endurecer a pasta pagamentos/.
--
-- SEPARADA da 0012 de propósito: aplicar SÓ depois de validar a Parte 1 (comp_select)
-- e testar a leitura de um comprovante de LOTE como gestor.
--
-- Hoje comp_pag_select deixa QUALQUER autenticado ler 'pagamentos/*' (inclusive de outra
-- empresa, se souber o path UUID). Como o comprovante de lote é referenciado por
-- lancamentos.comprovante_pagamento (= o próprio nome do objeto), restringimos a leitura a:
-- dono do SaaS, OU gestor/financeiro de uma empresa que tenha um lançamento apontando para
-- aquele arquivo. (O upload/baixa do lote já é operação só de gestão.)
--
-- Idempotente. Não altera dados. Registro do "antes": mesmo arquivo da 0012
-- (supabase/auditoria/storage-comprovantes-policies-antes-2026-08-11.txt).
-- ============================================================================

create or replace function public.pode_ver_pagamento(p_name text)
returns boolean
language sql stable security definer set search_path = public as $$
  select
    public.usuario_e_owner()
    or exists (
      select 1
      from public.lancamentos l
      where l.comprovante_pagamento = p_name
        and public.meu_papel(l.empresa_id) in ('gestor','financeiro')
    );
$$;
grant execute on function public.pode_ver_pagamento(text) to authenticated, anon;

drop policy if exists comp_pag_select on storage.objects;
create policy comp_pag_select on storage.objects for select to authenticated
  using (
    bucket_id = 'comprovantes'
    and (storage.foldername(name))[1] = 'pagamentos'
    and public.pode_ver_pagamento(name)
  );

select 'storage pagamentos: comp_pag_select por empresa (0013, Parte 2) ok' as status;
