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

## 2. Estado atual (migrations aplicadas 0000 → 0014)

**Versão publicada: `sw.js` v60 / `APP_VERSION` 60** — no ar e estável.
Bump conjunto `sw.js` + `APP_VERSION` a cada release (ver §11.3).
**Reorganização de navegação/UX (v58→v60, 100% front, banco intocado):** **v58** Administração em 6 abas
(`Usuários·Cadastros·Controles·Integração·Plano & IA·Empresa`-só-dono; padrão `mostrarAbaAdmin`/`mrd_admin_tab`).
**v59** tela **Saldos** no menu (cartões dos operadores-crédito; financeiro lança crédito direto no modal reusado;
carteira saiu da aba Usuários, ficou só "Definir modo"). **v60** módulo **Financeiro** (`scFinanceiro`) com abas
**Fechamento | Saldos** (padrão `FIN_ABAS`/`mostrarAbaFin`/`restaurarAbaFin`/`mrd_fin_tab`; conteúdo de
scMarcar/scSaldos virou os painéis `fin-fechamento`/`fin-saldos` SEM tocar a lógica — darBaixa, conciliação IA,
renderSaldos, RPCs, modal; `irMarcar`/`irSaldos` viraram atalhos) + **Console de Gestão** ("Sistema de Gestão")
movido para o **rodapé** do menu, gate mudado `ehGestor`→**`isOwner`** (só dono), sem duplicação; manter-tela do
`scFinanceiro` + migração de valores legados (scMarcar/scSaldos→scFinanceiro). **PENDENTE v61 (de-para aprovado):**
Ajustes reorganizado em cartões (`Conta·Preferências·Pagamento` + versão em destaque) — última pendência da
reorganização de navegação/UX.
**Crédito/saldo NO AR (v57, migration 0014 APLICADA):** `empresa_usuarios.modo_lancamento` (default
`'despesa'`) + tabela `creditos_operador` + 4 RPCs security definer (`lancar_credito` com
`lancado_por=auth.uid()`, `set_modo_operador`, `remover_credito`, `saldo_operador`) + RLS. Modo por
operador (despesa/crédito); crédito avulso pela gestão; saldo = créditos − despesas (acumula); negativo
avisa e deixa lançar; **decisão D** (operador-crédito fora do "A receber"/Fechamento — não paga 2x);
**gestão/financeiro lançam crédito** (RPC gate gestor/financeiro/dono), **definir modo é da gestão**
(dono/gestor); operador barrado no banco. Front resiliente (`creditoDisponivel`). Bloco de
**gestão de usuários CONCLUÍDO e validado** (criar limpo, sem órfã). **INFRA — PRIORIDADE:** o Reembolsos
está em plano **SEM backup automático** (a 0014 foi aplicada com dump manual); subir para **Supabase Pro**
(backups + PITR) antes de escalar clientes. **Pendente de aplicar:** Storage Parte 2 (`0013`).
**Edge Functions (4):** `ler-comprovante`, `importar-erp`, `ler-pagamento`, `gestao-usuarios`.
Gestão de usuários (v52-v56): **`gestao-usuarios`** faz criar/editar/ativar-desativar/senha provisória/
gerar link, com **força de troca no 1º acesso** e gate no backend (dono/gestor); saga de bugs corrigida até
a **RAIZ** (`papel` → `papel: perfil`, era ReferenceError mascarado por catch genérico — ver memória
`depurar-edge-function`) + **adoção de órfã** (e-mail já existe sem vínculo → adota) — *adoção pendente de
validação real*. **Storage 0012 Parte 1 APLICADA** (gestor/financeiro/dono leem comprovantes da empresa
inteira; corrigiu o ERR-1500; rollback em `supabase/auditoria/rollback-0012-parte1.sql`). Toasts de sucesso
destacados (verde/check/maior) nos dois fronts (v56).
Identidade visual (v50-v51): **fonte Inter self-hosted** (`fonts/inter-latin.woff2`+`-ext`, no `SHELL` do
`sw.js` → offline; sem CDN; JetBrains Mono removida) com **números tabulares** nos contextos numéricos;
**3º tema "Preto"** (fundo `#000`, texto branco, laranja `#DB8438` mantido, superfícies quase-pretas) —
seletor Claro/Escuro/Preto nos dois fronts, toggle cicla os 3, persiste em `mrd_tema`/`tema`; **linha
divisória** `border-right:var(--border)` na sidebar (desktop, 3 temas) + sidebar `#0A0A0B` no Preto (v51).
Últimas levas (front + 1 Edge Function nova, sem tocar schema): redesenho do Fechamento Parte A
(seleção múltipla/individual, baixa em lote, core único `darBaixa`, gate de gestão) (v46), fix
crítico do `</section>` faltante do v42 que aninhava Fechamento/Ajustes/Fornecedores/Administração
dentro do `scEditar` + guard de regressão de `section` (v47), **Parte B — Conciliação por IA no
Fechamento**: Edge Function nova **`ler-pagamento`** (lê valor+destinatário do comprovante de
pagamento, schema estrito, anti-injeção), casamento + proposta + baixa confirmada via `darBaixa`,
banco intocado (v48); casamento por **SOMA POR DATA DE VENCIMENTO** (aposentou o subset-sum de 4)
+ modal de conferência em **TABELA** (Vencimento·Categoria·Fornecedor·Pessoa·Valor) com recálculo
ao vivo e variante `lg` do modal (920px, resetada por abertura) — validado no aparelho (v49).
**Princípio da Parte B:** IA e casamento sempre PROPÕEM, a pessoa sempre DECIDE (nunca baixa
automática); gate só gestão; comprovante de pagamento é dado não confiável (IA só lê, schema
fechado, destinatário passa por detector de injeção + quarentena; baixa sempre confirmada).
Detalhes e fila em `docs/STATUS-SAAS.md`.

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
| `0007_rls_insert_logs_sistema.sql` | Policy de INSERT `to postgres` em `eventos_auditoria` (corrige o soft-delete que violava RLS ao auditar). |
| `0008_lanc_select_ver_excluidos.sql` | `lanc_select` deixa de esconder `deleted_at`; o front (operacional) filtra excluídos — permite auditar/ver excluídos. |
| `0009_comprovantes_hash_integridade.sql` | Policies de comprovantes + gravação real do hash sha256 (o INSERT era negado silenciosamente); integridade da duplicata por arquivo. |
| `0010_duplicata_documento.sql` | `numero_nota_extraido` + RPCs de duplicata **empresa-inteira** (por hash e por documento), `security definer` com guarda de pertencimento. |
| `0011_motivos_exclusao.sql` | Tabela `motivos_exclusao` (por empresa; RLS SELECT por empresa, escrita gestor/dono) + coluna `lancamentos.motivo_exclusao` (motivo vai à auditoria via `dados_depois`). |

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
- **Testes** — **harness VERSIONADO em `tests/`** (nunca mais no scratchpad: um harness
  cumulativo já se perdeu por viver só no temp). São checagens por regex/estrutura sobre
  `index.html`/`sw.js`, sem segredo: `node tests/<arquivo>.test.mjs`. Semente: `tests/ajustes.test.mjs`
  (Ajustes em cartões, v61); adicionar um arquivo por área conforme for mexida (Fechamento, Saldos,
  crédito, abas, gestão de usuários, IA…). Além disso, `supabase/functions/ler-comprovante/seguranca.test.mjs`
  cobre injeção/CNPJ da IA. Ao criar/alterar UI, adicione/rode o teste da área tocada.
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
  **`ler-comprovante`**, **`importar-erp`** e **`ler-pagamento`** (`supabase functions deploy`).
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
  temas **Claro / Escuro / Preto** (variáveis CSS `--accent`, `--bg-page`, `--surface`…; blocos
  `:root/[data-theme="light"]`, `[data-theme="dark"]`, `[data-theme="black"]`). No Preto o `--accent` se
  mantém. Sidebar (desktop) tem `border-right:var(--border)` como divisória.
- **Tipografia:** **Inter** (texto, self-hosted em `fonts/`), com **números tabulares**
  (`font-variant-numeric: tabular-nums`) nos contextos numéricos. Não usa mais Raleway/JetBrains Mono.
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

### 11.3 Disciplina de versão

- A cada release, fazer bump **CONJUNTO** de `sw.js` (cache `vNN`) **E** da constante
  `APP_VERSION` no `index.html` — os dois devem **sempre bater**. O indicador em
  Ajustes mostra ambos e sinaliza "atualizando" se divergirem.
