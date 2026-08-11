-- ============================================================================
-- 0012 — Storage (bucket "comprovantes"): leitura por EMPRESA para gestão.
--
-- Bug: comp_select só libera o SELECT do arquivo para o PRÓPRIO uploader
-- ((storage.foldername(name))[1] = auth.uid()). Assim gestor/financeiro/dono não
-- conseguem abrir o comprovante de DESPESA de um operador (ERR-1500 no app).
--
-- Correção (aditiva): amplia comp_select para também liberar quem é gestor/financeiro
-- da MESMA empresa do uploader, e o dono do SaaS. Consistente com a RLS de lancamentos
-- (0008), que já deixa gestor/financeiro ver a empresa inteira. NÃO remove o acesso do
-- próprio uploader e NÃO toca comp_insert/comp_delete.
--
-- Idempotente (create or replace function; drop policy if exists + create).
-- Registro do "antes": supabase/auditoria/storage-comprovantes-policies-antes-2026-08-11.txt
-- Não altera dados; muda apenas expressões de policy (RLS) de storage.objects.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PARTE 1 — comp_select por empresa (corrige o bug do ERR-1500)
-- ---------------------------------------------------------------------------
-- Helper SECURITY DEFINER (padrão dos helpers de RLS: empresas_do_usuario/meu_papel):
-- roda como o dono, então ignora a RLS de empresa_usuarios ao avaliar dentro da policy.
-- Recebe a 1a pasta do path (uid do uploader, em texto) e diz se o LEITOR (auth.uid())
-- pode ver: (a) é o próprio uploader; (b) é dono do SaaS; (c) é gestor/financeiro ativo
-- de alguma empresa em que o uploader também é membro ativo.
create or replace function public.pode_ver_comprovante(p_pasta text)
returns boolean
language sql stable security definer set search_path = public as $$
  select
    p_pasta = (auth.uid())::text                                  -- (a) próprio uploader (mantém o atual)
    or public.usuario_e_owner()                                   -- (b) dono do SaaS vê tudo
    or exists (                                                   -- (c) gestor/financeiro da MESMA empresa
      select 1
      from public.empresa_usuarios eu_up
      join public.empresa_usuarios eu_rd on eu_rd.empresa_id = eu_up.empresa_id
      where eu_up.usuario_id::text = p_pasta        -- dono da pasta = uploader
        and eu_up.ativo
        and eu_rd.usuario_id = auth.uid()           -- leitor logado
        and eu_rd.ativo
        and eu_rd.papel in ('gestor','financeiro')
    );
$$;
grant execute on function public.pode_ver_comprovante(text) to authenticated, anon;

drop policy if exists comp_select on storage.objects;
create policy comp_select on storage.objects for select to authenticated
  using (
    bucket_id = 'comprovantes'
    and public.pode_ver_comprovante((storage.foldername(name))[1])
  );

-- ---------------------------------------------------------------------------
-- PARTE 2 (SEPARADA — aprovar à parte) — endurecer a leitura de pagamentos/
-- ---------------------------------------------------------------------------
-- Hoje comp_pag_select deixa QUALQUER autenticado ler a pasta 'pagamentos/'
-- (inclusive de outra empresa, se souber o path UUID). Como o comprovante de lote é
-- referenciado por lancamentos.comprovante_pagamento (= o próprio nome do objeto),
-- restringimos a leitura a: dono do SaaS, OU gestor/financeiro de uma empresa que tenha
-- um lançamento apontando para aquele arquivo. (O upload/baixa do lote já é só gestão.)
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

select 'storage comprovantes: leitura por empresa (0012) ok' as status;
