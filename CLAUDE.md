# CLAUDE.md — Reembolsos Maradel

Guia para o Claude Code (e humanos) trabalharem neste repositório. Leia antes de
alterar código, banco ou deploy.

## 1. Visão do produto

Aplicativo web instalável (PWA) de **gestão de reembolsos corporativos**,
**multiempresa (SaaS)**, com leitura de comprovantes por **IA**. O usuário
fotografa a nota/cupom/comprovante de maquininha; a IA lê os dados e pré-preenche
o lançamento. O sistema controla o que há a pagar/receber, vencimentos,
aprovações e o fechamento (baixa em lote) com anexo de comprovante.

Dois níveis de negócio:
- **Dono do SaaS (`is_owner`)** — a Maradel. Cria empresas, define planos/cotas,
  acompanha consumo. Enxerga todas as empresas.
- **Empresa contratante** — o cliente. Papéis internos: **gestor** (admin),
  **financeiro**, **operador**.

Dois front-ends, mesmo backend e mesmo login:
- **`index.html`** — App Operacional (mobile-first): lançar, anexar, dar baixa,
  acompanhar. É PWA (service worker `sw.js`, cache offline).
- **`console.html`** — Console de Gestão (desktop-first): empresas, usuários,
  cadastros, integrações, aprovação, consumo, auditoria, relatórios (em breve).
  Acesso restrito a gestor/dono.

Documento de referência mais amplo: `docs/ARQUITETURA.md`, `docs/STATUS-SAAS.md`
e `docs/Reembolsos-Maradel-Detalhamento-Tecnico.docx`.

## 2. Estado atual (migrations aplicadas 0000 → 0006)

Todas versionadas em `supabase/migrations/` e **já aplicadas** no Supabase:

| Migration | Conteúdo |
|---|---|
| `0000_backup_pre_saas.sql` | Tabelas de backup `zz_backup_*` (perfis/lançamentos/fornecedores). |
| `0001_saas_foundation.sql` | Fundação multiempresa: tabelas do SaaS, RLS por `empresa_id`, funções auxiliares, triggers de numeração/`empresa_id`/auditoria. |
| `0002_metering_seguranca.sql` | Cota/metering de IA (`tem_cota_ia`, `consumo_ia`, `registrar_leitura_ia`) e registro de segurança/alertas. |
| `0003_auditoria.sql` | Trigger `fn_auditar_lancamento` → `eventos_auditoria` (criar/editar/pagar/estornar/excluir). |
| `0004_aprovacao_onboarding.sql` | `empresas.exige_aprovacao`; RPC `criar_empresa` e `vincular_usuario_empresa`. |
| `0005_categoria_codigo_externo.sql` | `codigo_externo` em `categorias` e `setores` (mapeia ao ERP). |
| `0006_integracoes_erp.sql` | Tabela `integracoes_erp` (credenciais de ERP por empresa) + RLS gestor/dono. |

Funcionalidades no ar: fundação SaaS + RLS, leitura por IA endurecida (com
detecção de parcelado), aprovação multinível, políticas de limite, alertas,
onboarding de empresas, categorias/setores, integração Omie (aguarda validação
com credenciais reais), Console de Gestão, navegação por módulos com menu
recolhível/gaveta, fechamento em lote com comprovante.

Roadmap aberto: Relatórios do console (Fase B), enxugar o app (Fase C),
multiempresa aprofundada (Fase D), cobrança/assinatura, e-mails, LGPD formal,
antifraude, migração do modelo de parcelas, criar login de gestor pelo app.

## 3. Estrutura do repositório

- `index.html` — app operacional inteiro (HTML/CSS/JS puro, sem framework).
- `console.html` — console de gestão (mesma stack).
- `sw.js` — service worker (rede-primeiro para o documento; **suba a versão do
  cache** `reembolsos-maradel-vN-saas` a cada release de UI).
- `manifest.webmanifest`, `icons/` — PWA.
- `supabase/migrations/NNNN_*.sql` — **fonte de verdade** do schema (aplicar em ordem).
- `supabase/functions/<nome>/index.ts` — Edge Functions (Deno/TypeScript).
- `.github/workflows/` — automação (migração, deploy de função, criação de usuários).
- `docs/` — arquitetura, status e detalhamento técnico.
- `*.sql` na raiz (`supabase-setup.sql`, `-v2/-v3/-v4`, `supabase-usuarios.sql`)
  são scripts **legados** anteriores às migrations versionadas; não são a fonte de
  verdade do schema (exceção: `supabase-usuarios.sql` ainda é usado pelo workflow
  de criação de usuários para aplicar papéis). Prefira sempre `supabase/migrations/`.

## 4. Convenções de código

- **Sem framework, sem build.** HTML/CSS/JS puro; bibliotecas via CDN (Supabase,
  Lucide, jsPDF, SheetJS, PDF.js). Nada de bundler.
- **Idioma:** todo texto de interface, comentário e mensagem de commit em
  **português**. Sem emoji. Sem travessão “—” como separador de UI.
- **Funções globais** para os `onclick` inline (script clássico, não módulo).
  Cuidado com colisão de nomes (ex.: já existe `toggleMenu` para menu suspenso;
  a gaveta usa `toggleGaveta`).
- **Acesso a dados** sempre via `sb` (cliente Supabase); nunca embutir chave de
  serviço no front. Ler/escrever respeitando RLS (empresa atual).
- **Dinheiro:** `1.234,56` (sem prefixo "R$", ver §11.2). **Datas:** `DD/MM/AAAA`.
  Use os helpers `money()`,
  `brDate()`, `esc()`, `el()`, `icons()`, `toast()`, `carregando()`.
- **Ícones** Lucide (`data-lucide=...`); após injetar HTML novo, chame `icons()`
  (`lucide.createIcons()`), senão o ícone fica em branco.
- **Testes** (harness Playwright no scratchpad, fora do repo): `stub.js` mocka o
  Supabase; `test.mjs` cobre o app; `console.test.mjs` cobre o console;
  `seguranca.test.mjs` cobre injeção/CNPJ. Rodar com `node` do Playwright.
- Ao mexer na UI, **suba o cache do `sw.js`**.

## 5. Convenções de migrations

- **Versionadas** em `supabase/migrations/NNNN_descricao.sql`, em ordem crescente.
- **Idempotentes e re-executáveis**: `create table if not exists`,
  `add column if not exists`, `create or replace function`,
  `drop policy if exists` antes de `create policy`, `on conflict do nothing/update`.
  Reaplicar uma migration não pode quebrar nada nem duplicar dados.
- **Aditivas**: preservar compatibilidade com o front atual (defaults e triggers
  preenchem `empresa_id`/numeração para inserts antigos).
- **RLS**: toda tabela por empresa usa as funções auxiliares
  `empresas_do_usuario()`, `usuario_e_owner()`, `meu_papel(empresa_id)`,
  `minha_empresa()`. Atenção: `empresa_usuarios` usa a coluna `usuario_id`;
  `lancamentos` usa `user_id`.
- **Aplicação**: nunca editar o schema à mão no painel. Rodar pela Action
  “Run SQL Migration” (ver §7). Terminar a migration com um `select '... ok'`.

## 6. Segurança de IA (obrigatória, não é remendo)

A Edge Function `ler-comprovante` trata o conteúdo do comprovante como **dado não
confiável**. Regras que devem ser mantidas em qualquer alteração:

- **Anti-injeção**: detector de padrões (PT/EN) roda **antes** da IA; suspeita vai
  para **quarentena** (`eventos_seguranca` via `registrar_evento_seguranca`) e não
  chega ao modelo.
- **Schema estrito**: a saída do Gemini é forçada a um `responseSchema` JSON.
- **Vocabulário fechado**: a categoria só pode ser uma da lista permitida — a IA
  não inventa categoria.
- **Validações**: dígito verificador do **CNPJ** e **teto de sanidade** de valor
  (acima do teto → revisão manual).
- **Metering/cota**: checar cota do plano antes (`tem_cota_ia`) e registrar cada
  leitura (`registrar_leitura_ia`); **lançamento manual nunca consome cota**.
- **Segredos no servidor**: `GEMINI_API_KEY` e `SUPABASE_SERVICE_ROLE_KEY` só
  existem na Edge Function; o app nunca os recebe. Idem credenciais de ERP em
  `importar-erp` (lidas com service role, nunca devolvidas ao cliente).

## 7. Deploy (tudo via GitHub Actions)

Projeto Supabase (`PROJECT_ID`): **`fwoupyqojfxpipvidvsx`**
(`https://fwoupyqojfxpipvidvsx.supabase.co`). O front é servido pelo **GitHub Pages**.

Workflows em `.github/workflows/`:

- **`run-sql-migration.yml`** — aplica uma migração SQL via Supabase Management API
  (`POST /v1/projects/{ref}/database/query`).
  Dispara por **workflow_dispatch** (input `file`, ex.:
  `supabase/migrations/0006_integracoes_erp.sql`) e por **push** que altere
  `supabase-v3-fornecedor.sql` ou o próprio workflow. Segredo: `SUPABASE_ACCESS_TOKEN`.
  → Para aplicar uma migration nova: Actions → “Run SQL Migration” → Run workflow →
  informar o caminho do arquivo.
- **`deploy-supabase-function.yml`** — publica as Edge Functions
  **`ler-comprovante`** e **`importar-erp`** (`supabase functions deploy`).
  Dispara por **push** nas branches `claude/app-opinion-u93e9u` e `main`, e por
  **workflow_dispatch**. Segredo: `SUPABASE_ACCESS_TOKEN`.
- **`create-users.yml`** — cria os logins da equipe no Supabase Auth (já
  confirmados) e aplica papéis (`supabase-usuarios.sql`). Dispara por
  **workflow_dispatch** e por push que altere o próprio workflow. Segredos:
  `SUPABASE_ACCESS_TOKEN` e `TEAM_INITIAL_PASSWORD` (se o segundo não existir, o
  job sai sem fazer nada).

Segredos ficam em **GitHub → Settings → Secrets and variables → Actions**
(`SUPABASE_ACCESS_TOKEN`, `TEAM_INITIAL_PASSWORD`). As Edge Functions recebem
`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` automaticamente do Supabase; o
`GEMINI_API_KEY` é configurado como secret da função no Supabase.

> Nenhum passo depende de segredo/ambiente local: banco, funções e usuários são
> aplicados pelas Actions. Rodar os testes Playwright localmente não exige segredo
> (usa stub). O deploy do front é o próprio GitHub Pages.

## 8. Identidade visual (design system Maradel)

- **Cor de marca:** terracota **`#DB8438`** (hover `#B96C28`) sobre neutros;
  temas **claro e escuro** (variáveis CSS `--accent`, `--bg-page`, `--surface`…).
- **Tipografia:** **Raleway** (texto) e **JetBrains Mono** (números/códigos,
  `font-variant-numeric: tabular-nums`).
- **Ícones:** Lucide. **Sem emojis.**
- **Formatos:** dinheiro `1.234,56` (sem "R$", ver §11.2); datas `DD/MM/AAAA`.
- **Padrões de UI:** cartões (`.card`/`.chart`), tabelas (`.tbl`), selos de status
  (`.st`), menu lateral, alternadores (`.switch`), listas compactas (`.crow`).

## 9. Fluxo de trabalho de git

- Desenvolver na branch designada; **não** commitar direto na `main` nem forçar
  push nela. Abrir PR só quando solicitado.
- Commits em português, descritivos. Ao terminar uma tarefa de UI, subir a versão
  do cache do `sw.js`.
- Manter `docs/STATUS-SAAS.md` atualizado ao concluir fases.

## 10. Rotina: aplicar uma migration nova

As migrations **não** sobem no push — precisam ser disparadas manualmente. Sempre
que criar ou alterar um arquivo em `supabase/migrations/`:

1. Commit e push do arquivo na branch atual.
2. Leia o `.github/workflows/run-sql-migration.yml` para pegar o **nome exato** do
   input e dispare o workflow com `gh`
   (`gh workflow run run-sql-migration.yml -f <input>=<caminho>`).
3. Acompanhe com `gh run watch` até concluir com sucesso.
4. Confirme no banco que aplicou (as migrations são idempotentes).

Nunca editar o banco pela interface do Supabase — a fonte de verdade é
`supabase/migrations/`. Os `.sql` na raiz (`supabase-setup.sql`, `-v2/-v3/-v4`) são
**legado**, ignorar. Exceção: `supabase-usuarios.sql` não é legado — ainda é usado
pelo workflow de criação de usuários (`create-users.yml`).

## 11. Regras permanentes (produção e exibição)

### 11.1 Proteção de produção (não temos banco DEV)

- **Não existe banco DEV.** O desenvolvimento roda contra o Supabase de
  **produção** (`fwoupyqojfxpipvidvsx`), que tem **dados reais de cliente**.
- **Nenhuma migration destrutiva** (`drop`, `truncate`, `delete` em massa, `alter`
  que remova coluna com dado) roda sem: (a) **backup confirmado** e (b) **meu OK
  explícito**.
- **Antes de qualquer migration que altere dados existentes**, avise e espere minha
  aprovação. Migrations de criação/adição idempotentes seguem o fluxo normal
  (seção 10).

### 11.2 Padrão de exibição de valores (marca Maradel)

- Valores monetários são exibidos **sem o prefixo "R$"**, só o número formatado
  (ex.: `7.578,26`). Alinhado ao padrão geral da marca. Vale para **telas,
  relatórios e exportações**.
