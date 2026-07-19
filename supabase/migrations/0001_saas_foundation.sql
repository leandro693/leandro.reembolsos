-- ============================================================================
-- 0001 — FUNDAÇÃO SaaS multiempresa (multi-tenant) — Reembolsos Maradel
-- Fonte de verdade: docs/ARQUITETURA.md
--
-- Estratégia: ADITIVA. As tabelas atuais (perfis, lancamentos, fornecedores)
-- continuam funcionando. Adicionamos empresa_id + tabelas SaaS + RLS por empresa.
-- Um DEFAULT (minha_empresa()) e triggers preenchem empresa_id/numero nas
-- inserções do app SEM exigir mudança de front-end. Idempotente.
-- ============================================================================

-- Identificadores fixos da empresa e planos iniciais (para backfill e referência).
--   Empresa Maradel : a1a1a1a1-0000-4000-8000-000000000001
--   Plano Básico    : b1b1b1b1-0000-4000-8000-000000000001

-- ---------------------------------------------------------------------------
-- A) TABELAS DO NÚCLEO SaaS
-- ---------------------------------------------------------------------------

create table if not exists public.planos (
  id                   uuid primary key default gen_random_uuid(),
  nome                 text not null,
  cota_leituras_mensal int  not null default 100,
  preco_mensal         numeric(12,2) not null default 0,
  ativo                boolean not null default true,
  criado_em            timestamptz default now()
);

create table if not exists public.empresas (
  id            uuid primary key default gen_random_uuid(),
  razao_social  text not null,
  nome_fantasia text default '',
  cnpj          text default '',
  plano_id      uuid references public.planos(id),
  taxa_km       numeric(12,2) not null default 1.00,
  ativo         boolean not null default true,
  criado_em     timestamptz default now(),
  deleted_at    timestamptz
);

create table if not exists public.usuarios (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text default '',
  email      text default '',
  is_owner   boolean not null default false,
  criado_em  timestamptz default now(),
  deleted_at timestamptz
);

create table if not exists public.setores (
  id         uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nome       text not null,
  ativo      boolean not null default true,
  criado_em  timestamptz default now(),
  deleted_at timestamptz
);

create table if not exists public.categorias (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid not null references public.empresas(id) on delete cascade,
  nome         text not null,
  tipo_calculo text not null default 'valor',  -- 'valor' | 'km'
  ativo        boolean not null default true,
  criado_em    timestamptz default now(),
  deleted_at   timestamptz
);

create table if not exists public.empresa_usuarios (
  id         uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  papel      text not null default 'operador',  -- 'operador' | 'financeiro' | 'gestor'
  setor_id   uuid references public.setores(id) on delete set null,
  ativo      boolean not null default true,
  criado_em  timestamptz default now(),
  unique(empresa_id, usuario_id)
);
create index if not exists idx_eu_usuario on public.empresa_usuarios(usuario_id) where ativo;

create table if not exists public.contadores (
  empresa_id     uuid primary key references public.empresas(id) on delete cascade,
  proximo_numero int not null default 1
);

create table if not exists public.politicas_limite (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid not null references public.empresas(id) on delete cascade,
  categoria_id uuid references public.categorias(id) on delete cascade,  -- null = geral
  valor_limite numeric(12,2) not null,
  periodo      text not null default 'por_lancamento',  -- 'por_lancamento' | 'mensal'
  ativo        boolean not null default true,
  criado_em    timestamptz default now()
);

create table if not exists public.alertas (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid not null references public.empresas(id) on delete cascade,
  lancamento_id uuid,
  tipo         text not null,   -- 'duplicata' | 'limite'
  detalhe      jsonb default '{}'::jsonb,
  resolvido    boolean not null default false,
  criado_em    timestamptz default now()
);
create index if not exists idx_alertas_empresa on public.alertas(empresa_id) where not resolvido;

create table if not exists public.uso_ia (
  id             uuid primary key default gen_random_uuid(),
  empresa_id     uuid not null references public.empresas(id) on delete cascade,
  usuario_id     uuid,
  lancamento_id  uuid,
  modelo         text default '',
  tokens_entrada int default 0,
  tokens_saida   int default 0,
  custo_estimado numeric(12,6) default 0,
  sucesso        boolean not null default true,
  created_at     timestamptz default now()
);
create index if not exists idx_uso_ia_empresa on public.uso_ia(empresa_id, created_at);

create table if not exists public.consumo_mensal (
  empresa_id          uuid not null references public.empresas(id) on delete cascade,
  ano_mes             text not null,  -- 'YYYY-MM'
  leituras_consumidas int not null default 0,
  primary key (empresa_id, ano_mes)
);

create table if not exists public.eventos_auditoria (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid,
  usuario_id   uuid,
  entidade     text,
  entidade_id  uuid,
  acao         text,
  dados_antes  jsonb,
  dados_depois jsonb,
  created_at   timestamptz default now()
);
create index if not exists idx_audit_empresa on public.eventos_auditoria(empresa_id, created_at);

create table if not exists public.eventos_seguranca (
  id         uuid primary key default gen_random_uuid(),
  empresa_id uuid,
  usuario_id uuid,
  tipo       text,        -- 'injecao_suspeita' | 'saida_fora_schema' | 'padrao_suspeito'
  severidade text default 'media',
  detalhe    jsonb default '{}'::jsonb,
  status     text default 'quarentena',  -- 'quarentena' | 'revisado' | 'liberado' | 'bloqueado'
  created_at timestamptz default now()
);
create index if not exists idx_seg_empresa on public.eventos_seguranca(empresa_id, created_at);

-- Parcelas e comprovantes como tabelas próprias (o app atual segue usando o
-- modelo antigo; estas nascem para a evolução do modelo de dados).
create table if not exists public.parcelas (
  id            uuid primary key default gen_random_uuid(),
  lancamento_id uuid not null,
  empresa_id    uuid not null references public.empresas(id) on delete cascade,
  numero_parcela int not null default 1,
  valor         numeric(12,2) not null default 0,
  vencimento    date,
  status        text not null default 'aberto',  -- 'aberto' | 'pago' | 'em_atraso' | 'estornado'
  pago_em       timestamptz,
  pago_por      uuid,
  deleted_at    timestamptz
);
create index if not exists idx_parcelas_lanc on public.parcelas(lancamento_id);

create table if not exists public.comprovantes (
  id                    uuid primary key default gen_random_uuid(),
  lancamento_id         uuid not null,
  empresa_id            uuid not null references public.empresas(id) on delete cascade,
  storage_path          text not null,
  nome_arquivo_original text default '',
  arquivo_hash          text,
  mime_type             text default '',
  tamanho_bytes         int default 0,
  criado_em             timestamptz default now(),
  deleted_at            timestamptz
);
create index if not exists idx_comprovantes_lanc on public.comprovantes(lancamento_id);
create unique index if not exists idx_comprovante_hash
  on public.comprovantes(empresa_id, arquivo_hash) where deleted_at is null and arquivo_hash is not null;

-- ---------------------------------------------------------------------------
-- B) COLUNAS NOVAS NAS TABELAS EXISTENTES (aditivo)
-- ---------------------------------------------------------------------------

alter table public.lancamentos add column if not exists empresa_id           uuid references public.empresas(id);
alter table public.lancamentos add column if not exists numero_sequencial    int;
alter table public.lancamentos add column if not exists categoria_id         uuid references public.categorias(id);
alter table public.lancamentos add column if not exists setor_id             uuid references public.setores(id);
alter table public.lancamentos add column if not exists situacao             text default 'em_aberto';
alter table public.lancamentos add column if not exists aprovacao            text default 'aprovado';
alter table public.lancamentos add column if not exists ia_lido              boolean default false;
alter table public.lancamentos add column if not exists km_taxa_aplicada     numeric(12,2);
alter table public.lancamentos add column if not exists cnpj_estabelecimento text default '';
alter table public.lancamentos add column if not exists data_extraida        date;
alter table public.lancamentos add column if not exists valor_extraido       numeric(12,2);
alter table public.lancamentos add column if not exists estabelecimento_nome text default '';
alter table public.lancamentos add column if not exists ia_json_bruto        jsonb;
alter table public.lancamentos add column if not exists criado_por           uuid;
alter table public.lancamentos add column if not exists deleted_at           timestamptz;

alter table public.fornecedores add column if not exists empresa_id uuid references public.empresas(id);
alter table public.fornecedores add column if not exists deleted_at timestamptz;

-- ---------------------------------------------------------------------------
-- C) SEEDS + BACKFILL (empresa Maradel + dados atuais)
-- ---------------------------------------------------------------------------

insert into public.planos (id, nome, cota_leituras_mensal, preco_mensal) values
  ('b1b1b1b1-0000-4000-8000-000000000001','Básico',     100, 0),
  ('b1b1b1b1-0000-4000-8000-000000000002','Pro',        300, 0),
  ('b1b1b1b1-0000-4000-8000-000000000003','Enterprise', 500, 0)
on conflict (id) do nothing;

insert into public.empresas (id, razao_social, nome_fantasia, plano_id, taxa_km) values
  ('a1a1a1a1-0000-4000-8000-000000000001','Maradel Assessoria e Consultoria Contábil','Maradel',
   'b1b1b1b1-0000-4000-8000-000000000001', 1.00)
on conflict (id) do nothing;

-- usuarios (espelha auth.users; nome vem do perfil; Leandro é dono do SaaS)
insert into public.usuarios (id, nome, email, is_owner)
select u.id, coalesce(nullif(p.nome,''), split_part(u.email,'@',1)), u.email,
       (lower(u.email) = 'leandro@maradelcontabil.com')
from auth.users u
left join public.perfis p on p.user_id = u.id
on conflict (id) do update set
  email = excluded.email,
  is_owner = excluded.is_owner,
  nome = case when usuarios.nome is null or usuarios.nome='' then excluded.nome else usuarios.nome end;

-- setor padrão
insert into public.setores (empresa_id, nome)
select 'a1a1a1a1-0000-4000-8000-000000000001','Geral'
where not exists (select 1 from public.setores where empresa_id='a1a1a1a1-0000-4000-8000-000000000001');

-- categorias padrão (iguais às do app; Quilometragem = cálculo por km)
insert into public.categorias (empresa_id, nome, tipo_calculo)
select 'a1a1a1a1-0000-4000-8000-000000000001', c.nome,
       case when c.nome='Quilometragem' then 'km' else 'valor' end
from (values
  ('Quilometragem'),('Pedágios'),('Refeições'),('Material de Copa e Cozinha'),('Software/Licença de Uso'),
  ('Construção de imóvel'),('Confraternização e Aniversário'),('Junta Comercial e Outras Taxas - Societário'),
  ('Educação / Capacitação'),('Material de Escritório'),('Material de Limpeza'),('Equipamentos de Informática'),
  ('Correios / Consultas de clientes'),('Despesas de Frete / Motoboy'),('Patrocínios'),('Outros')
) as c(nome)
where not exists (
  select 1 from public.categorias x
  where x.empresa_id='a1a1a1a1-0000-4000-8000-000000000001' and x.nome=c.nome
);

-- vínculo usuário↔empresa (papel: admin->gestor, financeiro->financeiro, resto->operador)
insert into public.empresa_usuarios (empresa_id, usuario_id, papel)
select 'a1a1a1a1-0000-4000-8000-000000000001', u.id,
       case coalesce(p.papel,'operador')
         when 'admin' then 'gestor'
         when 'financeiro' then 'financeiro'
         else 'operador' end
from public.usuarios u
left join public.perfis p on p.user_id = u.id
on conflict (empresa_id, usuario_id) do update set papel = excluded.papel;

-- backfill lancamentos: empresa, situação, categoria, criado_por
update public.lancamentos set empresa_id='a1a1a1a1-0000-4000-8000-000000000001' where empresa_id is null;
update public.lancamentos set situacao = case when status='pago' then 'pago' else 'em_aberto' end where situacao is null or situacao='em_aberto';
update public.lancamentos set criado_por = user_id where criado_por is null;
update public.lancamentos set ia_lido = (comprovante is not null and comprovante <> '') where ia_lido is null;
update public.lancamentos l set categoria_id = c.id
  from public.categorias c
 where c.empresa_id = l.empresa_id and c.nome = l.categoria and l.categoria_id is null;

-- numeração sequencial retroativa (por empresa, ordem de criação)
with numerados as (
  select id, row_number() over (partition by empresa_id order by criado_em, id) as n
  from public.lancamentos where numero_sequencial is null
)
update public.lancamentos l set numero_sequencial = numerados.n
from numerados where numerados.id = l.id;

-- contador começa após o maior número já usado
insert into public.contadores (empresa_id, proximo_numero)
select 'a1a1a1a1-0000-4000-8000-000000000001',
       coalesce((select max(numero_sequencial) from public.lancamentos
                  where empresa_id='a1a1a1a1-0000-4000-8000-000000000001'),0) + 1
on conflict (empresa_id) do nothing;

-- backfill fornecedores
update public.fornecedores set empresa_id='a1a1a1a1-0000-4000-8000-000000000001' where empresa_id is null;

-- ---------------------------------------------------------------------------
-- D) FUNÇÕES AUXILIARES DE ACESSO (RLS)
-- ---------------------------------------------------------------------------

create or replace function public.empresas_do_usuario()
returns setof uuid language sql stable security definer set search_path=public as $$
  select empresa_id from public.empresa_usuarios where usuario_id = auth.uid() and ativo = true;
$$;

create or replace function public.usuario_e_owner()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce((select is_owner from public.usuarios where id = auth.uid()), false);
$$;

create or replace function public.meu_papel(p_empresa uuid)
returns text language sql stable security definer set search_path=public as $$
  select papel from public.empresa_usuarios
   where usuario_id = auth.uid() and empresa_id = p_empresa and ativo = true limit 1;
$$;

-- Empresa "corrente" do usuário (para DEFAULT do empresa_id nas inserções).
create or replace function public.minha_empresa()
returns uuid language sql stable security definer set search_path=public as $$
  select empresa_id from public.empresa_usuarios
   where usuario_id = auth.uid() and ativo = true order by criado_em nulls last limit 1;
$$;

-- Preenche empresa_id/numero_sequencial/criado_por automaticamente na inserção
-- (mantém o front-end atual funcionando sem alterações).
create or replace function public.fn_lanc_before_insert()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_num int;
begin
  if new.empresa_id is null then new.empresa_id := public.minha_empresa(); end if;
  if new.criado_por is null then new.criado_por := auth.uid(); end if;
  if new.empresa_id is not null and new.numero_sequencial is null then
    insert into public.contadores (empresa_id, proximo_numero)
      values (new.empresa_id, 1) on conflict (empresa_id) do nothing;
    update public.contadores set proximo_numero = proximo_numero + 1
      where empresa_id = new.empresa_id returning proximo_numero - 1 into v_num;
    new.numero_sequencial := v_num;
  end if;
  if new.situacao is null then
    new.situacao := case when new.status='pago' then 'pago' else 'em_aberto' end;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_lanc_before_insert on public.lancamentos;
create trigger trg_lanc_before_insert before insert on public.lancamentos
  for each row execute function public.fn_lanc_before_insert();

create or replace function public.fn_forn_before_insert()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.empresa_id is null then new.empresa_id := public.minha_empresa(); end if;
  return new;
end;
$$;
drop trigger if exists trg_forn_before_insert on public.fornecedores;
create trigger trg_forn_before_insert before insert on public.fornecedores
  for each row execute function public.fn_forn_before_insert();

-- Mantém lancamentos.situacao em sincronia com status nas atualizações do app.
create or replace function public.fn_lanc_before_update()
returns trigger language plpgsql set search_path=public as $$
begin
  new.situacao := case when new.status='pago' then 'pago' else
    case when new.vencimento is not null and new.vencimento < current_date then 'em_atraso' else 'em_aberto' end end;
  return new;
end;
$$;
drop trigger if exists trg_lanc_before_update on public.lancamentos;
create trigger trg_lanc_before_update before update on public.lancamentos
  for each row execute function public.fn_lanc_before_update();

-- DEFAULT de empresa_id (aplicado antes da checagem de RLS).
alter table public.lancamentos  alter column empresa_id set default public.minha_empresa();
alter table public.fornecedores alter column empresa_id set default public.minha_empresa();

-- ---------------------------------------------------------------------------
-- E) RLS — isolamento por empresa (+ papel preservando o comportamento atual)
-- ---------------------------------------------------------------------------

-- LANCAMENTOS: operador vê os próprios; financeiro/gestor veem a empresa; owner vê tudo.
alter table public.lancamentos enable row level security;
drop policy if exists lanc_select on public.lancamentos;
drop policy if exists lanc_insert on public.lancamentos;
drop policy if exists lanc_update on public.lancamentos;
drop policy if exists lanc_delete on public.lancamentos;
create policy lanc_select on public.lancamentos for select using (
  deleted_at is null and (
    public.usuario_e_owner()
    or (empresa_id in (select public.empresas_do_usuario())
        and (usuario_id = auth.uid() or public.meu_papel(empresa_id) in ('financeiro','gestor')))
  )
);
create policy lanc_insert on public.lancamentos for insert with check (
  empresa_id in (select public.empresas_do_usuario()) and usuario_id = auth.uid()
);
create policy lanc_update on public.lancamentos for update using (
  public.usuario_e_owner()
  or (empresa_id in (select public.empresas_do_usuario())
      and (usuario_id = auth.uid() or public.meu_papel(empresa_id) in ('financeiro','gestor')))
);
create policy lanc_delete on public.lancamentos for delete using (
  public.usuario_e_owner()
  or (empresa_id in (select public.empresas_do_usuario())
      and (usuario_id = auth.uid() or public.meu_papel(empresa_id) = 'gestor'))
);

-- FORNECEDORES: leitura/inserção pela empresa; edição/exclusão por gestor/owner.
alter table public.fornecedores enable row level security;
drop policy if exists forn_select on public.fornecedores;
drop policy if exists forn_insert on public.fornecedores;
drop policy if exists forn_update on public.fornecedores;
drop policy if exists forn_delete on public.fornecedores;
create policy forn_select on public.fornecedores for select using (
  (deleted_at is null) and (public.usuario_e_owner() or empresa_id in (select public.empresas_do_usuario()))
);
create policy forn_insert on public.fornecedores for insert with check (
  empresa_id in (select public.empresas_do_usuario())
);
create policy forn_update on public.fornecedores for update using (
  public.usuario_e_owner() or (empresa_id in (select public.empresas_do_usuario()) and public.meu_papel(empresa_id) in ('gestor'))
);
create policy forn_delete on public.fornecedores for delete using (
  public.usuario_e_owner() or (empresa_id in (select public.empresas_do_usuario()) and public.meu_papel(empresa_id) in ('gestor'))
);

-- Tabelas de leitura por empresa (dados do próprio tenant + owner).
do $$
declare t text;
begin
  foreach t in array array['empresas','setores','categorias','empresa_usuarios','contadores',
                           'politicas_limite','alertas','uso_ia','consumo_mensal',
                           'eventos_auditoria','eventos_seguranca','parcelas','comprovantes'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- SELECT por empresa nas tabelas que têm empresa_id.
do $$
declare t text;
begin
  foreach t in array array['setores','categorias','empresa_usuarios','contadores',
                           'politicas_limite','alertas','uso_ia','consumo_mensal',
                           'eventos_auditoria','eventos_seguranca','parcelas','comprovantes'] loop
    execute format('drop policy if exists %I_sel on public.%I', t, t);
    execute format($p$create policy %I_sel on public.%I for select using (
      public.usuario_e_owner() or empresa_id in (select public.empresas_do_usuario()))$p$, t, t);
  end loop;
end $$;

-- planos: catálogo global legível por qualquer autenticado (para o app mostrar o plano).
drop policy if exists planos_sel on public.planos;
create policy planos_sel on public.planos for select to authenticated using (true);

-- empresas: vê as suas (ou todas se owner).
drop policy if exists empresas_sel on public.empresas;
create policy empresas_sel on public.empresas for select using (
  public.usuario_e_owner() or id in (select public.empresas_do_usuario())
);

-- usuarios: vê a si mesmo, colegas de empresa, ou tudo se owner.
drop policy if exists usuarios_sel on public.usuarios;
create policy usuarios_sel on public.usuarios for select using (
  public.usuario_e_owner() or id = auth.uid()
  or id in (select usuario_id from public.empresa_usuarios
             where empresa_id in (select public.empresas_do_usuario()))
);

-- Escrita nas tabelas de gestão: apenas gestor da empresa ou owner (via app/Edge).
-- Insert/Update/Delete para gestor/owner nas tabelas de cadastro da empresa.
do $$
declare t text;
begin
  foreach t in array array['setores','categorias','politicas_limite','empresa_usuarios'] loop
    execute format('drop policy if exists %I_ins on public.%I', t, t);
    execute format('drop policy if exists %I_upd on public.%I', t, t);
    execute format('drop policy if exists %I_del on public.%I', t, t);
    execute format($p$create policy %I_ins on public.%I for insert with check (
      public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor')$p$, t, t);
    execute format($p$create policy %I_upd on public.%I for update using (
      public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor')$p$, t, t);
    execute format($p$create policy %I_del on public.%I for delete using (
      public.usuario_e_owner() or public.meu_papel(empresa_id)='gestor')$p$, t, t);
  end loop;
end $$;

-- alertas: gestor/financeiro podem marcar resolvido.
drop policy if exists alertas_upd on public.alertas;
create policy alertas_upd on public.alertas for update using (
  public.usuario_e_owner() or public.meu_papel(empresa_id) in ('gestor','financeiro')
);
-- inserção de alertas/uso_ia/eventos parte da Edge Function (service role, ignora RLS).

-- ---------------------------------------------------------------------------
-- F) Índice de duplicata lógica (valor+data+CNPJ por empresa)
-- ---------------------------------------------------------------------------
create index if not exists idx_lanc_dup_logica
  on public.lancamentos (empresa_id, valor_extraido, data_extraida, cnpj_estabelecimento)
  where deleted_at is null;

-- ---------------------------------------------------------------------------
-- Conferência
-- ---------------------------------------------------------------------------
select
  (select count(*) from public.empresas)          as empresas,
  (select count(*) from public.usuarios)           as usuarios,
  (select count(*) from public.empresa_usuarios)   as vinculos,
  (select count(*) from public.categorias)         as categorias,
  (select count(*) from public.lancamentos where empresa_id is not null) as lanc_com_empresa,
  (select count(*) from public.lancamentos where numero_sequencial is not null) as lanc_numerados;
