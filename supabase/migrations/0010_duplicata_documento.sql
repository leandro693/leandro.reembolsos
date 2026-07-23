-- ============================================================================
-- 0010 — Duplicata por DOCUMENTO EXTRAÍDO + checagem empresa-inteira via RPC.
--
-- Problema: hash pega só o MESMO arquivo; a checagem lógica compara campos do
-- FORMULÁRIO (editáveis) -> alterar valor/número engana. Solução: comparar os
-- dados EXTRAÍDOS pela IA (vêm do documento, não do que o usuário digita).
--
-- Também fecha uma limitação de RLS: pelo front, a checagem consulta lancamentos,
-- que o operador só enxerga os PRÓPRIOS -> não pegaria o reenvio do documento de um
-- colega. Duas RPCs security definer rodam em escopo de EMPRESA para todos os papéis,
-- devolvendo só o RESUMO do lançamento conflitante (nunca a linha inteira/alheia).
--
-- Como o papel `postgres` está sujeito à RLS neste projeto (ver 0007), a leitura da
-- empresa inteira dentro das RPCs é habilitada por uma policy de SELECT restrita ao
-- sistema (lanc_sys_sel, to postgres). O isolamento entre empresas é garantido pela
-- GUARDA DE PERTENCIMENTO + o WHERE empresa_id da própria RPC.
--
-- Idempotente e aditivo. Não altera dados. Registro do "antes" em
-- supabase/auditoria/documento-antes-0010.txt.
-- ============================================================================

-- 1) Coluna do número da nota EXTRAÍDO — default NULL (não '') para a camada forte
--    não casar dois recibos SEM número (ambos ficariam iguais e dariam falso positivo).
alter table public.lancamentos add column if not exists numero_nota_extraido text;

-- 2) Índice da camada forte (só linhas com número presente).
create index if not exists idx_lanc_dup_doc
  on public.lancamentos (empresa_id, cnpj_estabelecimento, numero_nota_extraido)
  where deleted_at is null and numero_nota_extraido is not null;

-- 3) Leitura do sistema: permite às RPCs (security definer, dono postgres) ler a
--    empresa inteira. NÃO afeta clientes (authenticated/anon seguem na lanc_select).
drop policy if exists lanc_sys_sel on public.lancamentos;
create policy lanc_sys_sel on public.lancamentos for select to postgres using (true);

-- 4) RPC: duplicata por DOCUMENTO EXTRAÍDO (camada forte + fallback).
create or replace function public.checar_duplicata_documento(
  p_empresa uuid, p_cnpj text, p_numero text, p_data date, p_valor numeric)
returns table(numero_sequencial int, status text, valor_total numeric,
              data_emissao text, vencimento text, aprovacao text)
language plpgsql security definer set search_path=public as $$
declare
  v_cnpj text := regexp_replace(coalesce(p_cnpj,''), '\D', '', 'g');
  v_num  text := btrim(coalesce(p_numero,''));
  v_id   uuid;
begin
  -- Pertencimento: dono do SaaS OU membro da empresa. Bloqueia empresa_id arbitrário.
  if not public.usuario_e_owner() and public.meu_papel(p_empresa) is null then
    raise exception 'sem acesso a esta empresa';
  end if;
  if v_cnpj = '' then return; end if;  -- sem CNPJ extraído, nenhuma camada roda

  -- Camada FORTE: CNPJ + número. Exige número NÃO vazio dos DOIS lados.
  if v_num <> '' then
    select l.id into v_id
      from public.lancamentos l
     where l.empresa_id = p_empresa and l.deleted_at is null
       and regexp_replace(coalesce(l.cnpj_estabelecimento,''),'\D','','g') = v_cnpj
       and l.numero_nota_extraido is not null
       and btrim(l.numero_nota_extraido) <> ''
       and btrim(l.numero_nota_extraido) = v_num
     limit 1;
    if v_id is not null then
      return query select l.numero_sequencial, l.status, l.valor_total::numeric,
                          l.data_emissao::text, l.vencimento::text, l.aprovacao
                     from public.lancamentos l where l.id = v_id;
      return;
    end if;
  end if;

  -- Camada FALLBACK: CNPJ + data + valor (cobre comprovantes SEM número).
  if p_data is not null and p_valor is not null then
    select l.id into v_id
      from public.lancamentos l
     where l.empresa_id = p_empresa and l.deleted_at is null
       and regexp_replace(coalesce(l.cnpj_estabelecimento,''),'\D','','g') = v_cnpj
       and l.data_extraida = p_data
       and l.valor_extraido = p_valor
     limit 1;
    if v_id is not null then
      return query select l.numero_sequencial, l.status, l.valor_total::numeric,
                          l.data_emissao::text, l.vencimento::text, l.aprovacao
                     from public.lancamentos l where l.id = v_id;
    end if;
  end if;
  return;
end $$;

-- 5) RPC: duplicata por HASH (mesma cobertura empresa-inteira, fecha o vetor do colega).
create or replace function public.checar_duplicata_hash(p_empresa uuid, p_hash text)
returns table(numero_sequencial int, status text, valor_total numeric,
              data_emissao text, vencimento text, aprovacao text)
language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if not public.usuario_e_owner() and public.meu_papel(p_empresa) is null then
    raise exception 'sem acesso a esta empresa';
  end if;
  if coalesce(btrim(p_hash),'') = '' then return; end if;
  select c.lancamento_id into v_id
    from public.comprovantes c
    join public.lancamentos l on l.id = c.lancamento_id and l.deleted_at is null
   where c.empresa_id = p_empresa and c.arquivo_hash = p_hash and c.deleted_at is null
   limit 1;
  if v_id is not null then
    return query select l.numero_sequencial, l.status, l.valor_total::numeric,
                        l.data_emissao::text, l.vencimento::text, l.aprovacao
                   from public.lancamentos l where l.id = v_id;
  end if;
  return;
end $$;

-- 6) Execução só para usuários logados (nunca anon).
revoke all on function public.checar_duplicata_documento(uuid,text,text,date,numeric) from public;
revoke all on function public.checar_duplicata_hash(uuid,text) from public;
grant execute on function public.checar_duplicata_documento(uuid,text,text,date,numeric) to authenticated;
grant execute on function public.checar_duplicata_hash(uuid,text) to authenticated;

select 'duplicata por documento + RPCs empresa-inteira (0010) ok' as status;
