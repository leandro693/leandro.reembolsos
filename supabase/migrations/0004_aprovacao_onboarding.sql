-- ============================================================================
-- 0004 — Aprovação multinível (Fase 2) + onboarding de empresas (dono do SaaS).
-- Idempotente.
-- ============================================================================

-- A empresa pode exigir aprovação dos lançamentos antes de entrarem no fluxo.
alter table public.empresas add column if not exists exige_aprovacao boolean not null default false;

-- Onboarding: o DONO do SaaS cria uma nova empresa já com plano, categorias
-- padrão, setor "Geral" e contador. Devolve o id da empresa criada.
create or replace function public.criar_empresa(p_razao text, p_fantasia text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_plano uuid;
begin
  if not public.usuario_e_owner() then
    raise exception 'apenas o dono do SaaS pode criar empresas';
  end if;
  select id into v_plano from public.planos where ativo order by cota_leituras_mensal limit 1;
  insert into public.empresas(razao_social, nome_fantasia, plano_id, taxa_km)
    values (p_razao, coalesce(nullif(p_fantasia,''), p_razao), v_plano, 1.00)
    returning id into v_id;

  insert into public.setores(empresa_id, nome) values (v_id, 'Geral');
  insert into public.contadores(empresa_id, proximo_numero) values (v_id, 1)
    on conflict (empresa_id) do nothing;
  insert into public.categorias(empresa_id, nome, tipo_calculo)
  select v_id, c.nome, case when c.nome='Quilometragem' then 'km' else 'valor' end
  from (values
    ('Quilometragem'),('Pedágios'),('Refeições'),('Material de Copa e Cozinha'),('Software/Licença de Uso'),
    ('Construção de imóvel'),('Confraternização e Aniversário'),('Junta Comercial e Outras Taxas - Societário'),
    ('Educação / Capacitação'),('Material de Escritório'),('Material de Limpeza'),('Equipamentos de Informática'),
    ('Correios / Consultas de clientes'),('Despesas de Frete / Motoboy'),('Patrocínios'),('Outros')
  ) as c(nome);
  return v_id;
end;
$$;

-- Vincula um usuário JÁ EXISTENTE (por e-mail) a uma empresa, com papel.
-- Usado no onboarding para dar acesso ao gestor da nova empresa. Dono do SaaS.
create or replace function public.vincular_usuario_empresa(p_empresa uuid, p_email text, p_papel text)
returns text language plpgsql security definer set search_path=public as $$
declare v_uid uuid;
begin
  if not public.usuario_e_owner() then raise exception 'apenas o dono do SaaS'; end if;
  select id into v_uid from auth.users where lower(email)=lower(p_email);
  if v_uid is null then return 'usuario_nao_encontrado'; end if;
  insert into public.usuarios(id, nome, email)
    values (v_uid, split_part(p_email,'@',1), p_email) on conflict (id) do nothing;
  insert into public.empresa_usuarios(empresa_id, usuario_id, papel)
    values (p_empresa, v_uid, coalesce(p_papel,'gestor'))
    on conflict (empresa_id, usuario_id) do update set papel=excluded.papel, ativo=true;
  return 'ok';
end;
$$;

select 'aprovacao + onboarding ok' as status;
