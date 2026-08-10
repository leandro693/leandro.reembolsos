# Status da refundação SaaS multiempresa

> Trabalho autônomo noturno. Este documento registra o que foi feito, como
> reverter e o que falta. Fonte de verdade da arquitetura: `docs/ARQUITETURA.md`.

---

## Estado atual — fim de 10/08/2026 (v47 publicado e estável)

- **Versão no ar: `sw.js` v47 / `APP_VERSION` 47** — publicada e **estável** (site 200; run do Pages
  `completed/success`; commit `205deb8`). Working tree limpo, branch em sincronia.
- **Migrations aplicadas: até `0011`** — **sem mudança de banco** nestas levas (tudo 100% front). Bump
  conjunto `sw.js` + `APP_VERSION` mantido (CLAUDE.md §11.3).

### Feito em 09-10/08
- **Campos pareados no desktop (v43)** — no Novo lançamento/Edição, pares (Ler+Recortar, Fornecedor+CNPJ,
  NºNota+Valor) via CSS `order` (form mais compacto, sem reordenar o DOM; mobile inalterado) + **correção
  da proporção em zoom** do comprovante (`max-width:100%`, sem estourar a coluna).
- **Ajustes finos do par e rótulos (v44)** — alinhamento do par **Ler/Recortar** (via `order`), **respiro
  dos rótulos** (label 6→8px, global) e **dropzone mais compacta** (padding 26→14px, só desktop).
- **Respiro forma de pagamento × datas (v45)** — espaço entre o bloco "À vista/Parcelado" e Data/Vencimento
  no desktop (`body.tela-doc .grid-desk{margin-bottom:14px}`).
- **Redesenho do Fechamento — Parte A (v46, só UX, SEM IA)** — texto de ajuda claro; **seleção múltipla**
  (checkbox + "selecionar todos") **e individual** (botão discreto por linha); **barra de ação** com
  "N selecionados · total", **data única do lote** (hoje, editável) e **comprovante do lote OPCIONAL**;
  botão "Dar baixa nos selecionados"; placeholder **"Conciliação por IA — em breve"** (só visual, sem
  onclick); **gate de gestão** (`veTudo()`); core único **`darBaixa(ids, dp, arquivo)`** reusado por
  **lote, baixa individual E Lançamentos**. **Sem tocar banco** (coluna `comprovante_pagamento` já existia).
- **FIX CRÍTICO (v47)** — o `scEditar` estava **sem o `</section>`** (perdido no refactor do v42), o que
  **aninhava as telas seguintes** (Fechamento/Ajustes/Fornecedores/Administração) **dentro do `scEditar`**
  (oculto), deixando-as **em branco** ao navegar. Corrigido o fechamento + adicionado **guard de regressão**
  no harness que conta `<section>`×`</section>` e valida que nenhuma tela fica aninhada dentro de outra.
  - **LIÇÃO:** teste automatizado de **lógica** não pega **erro de estrutura HTML** nem substitui o **teste
    de olho no aparelho** — principalmente após refactors de layout/estrutura, **clicar por TODAS as telas**,
    não só as que mudaram.

### Feito em 08/08
- **Balancete: tabela de informações + orientação EXIF (v40)** — no PDF "Balancete", a seção do comprovante
  virou **tabela** (cabeçalho "Informações da despesa", `theme:'grid'` + zebra + rótulo em negrito); e a
  **foto entra em pé** (helper `dataUrlOrientado` via `createImageBitmap({imageOrientation:'from-image'})`,
  só no ramo de foto; PDF anexado inalterado; fallback se indisponível). Lib: jsPDF 2.5.1 + autotable 3.8.2.
- **Scroll do comprovante no desktop (v41)** — `.fc-body` deixou de centralizar (era `align-items:center`,
  que escondia o topo de documentos compridos) → `display:block; overflow-y:auto`; documento rola do
  cabeçalho ao rodapé dentro do painel.
- **Grid único de 2 colunas (v42)** — **consolidação**: Novo lançamento (`scForm`) E Edição (`scEditar`)
  usam o MESMO grid `body.tela-doc` **proporcional `minmax(0,1fr) minmax(0,1fr)`**, **alinhado no topo**
  (`align-items:start`, sem `margin-top`). **Removido o mecanismo legado** `#docViewer`/`.docviewer`/
  `has-viewer main` e a coluna fixa de 600px. `abrirViewer`/`fecharViewer` agora enchem **todos os
  `.form-comp`** por classe (`.fc-img`/`.fc-frame`/`.fc-empty`). Scroll interno do v41 mantido.

### Feito em 07/08
- **Memória de categoria por estabelecimento (v35)** — IA em "Outros"/vazio → sugere a categoria mais
  usada do fornecedor (consulta a `lista` em memória; casa por CNPJ→`normNome`; só ativa; empate = mais
  recente; preenche em silêncio).
- **"Por pessoa" vira filtro (v36)** — filtro em `baseLista()` recalcula **dashboard (KPIs/gráficos/últimos)
  e lista**; seletor também no topo do Dashboard (`#dashPessoa`), gated por `veTudo()`; persiste em
  `localStorage['mrd_pessoa']`, validado no load.
- **Modal de input + limpeza (v37)** — `pedirTexto()` (reusa o modal Maradel) substitui os `prompt()` de
  renomear (setor/categoria/motivo no index e o renomear do console); removido o bloco "por pessoa"
  redundante do rodapé do dashboard.
- **Layout desktop (v38)** — Novo lançamento em **2 colunas** (form fixo à esquerda + comprovante à direita,
  `#formComp`, guardado por `body.tela-form`); **cores do filtro de status** ecoam os selos (âmbar/vermelho/
  verde/accent) — **também no mobile**; filtros **agrupados ao lado do seletor de pessoa**; **fornecedores
  em tabela** no desktop (cards no mobile).
- **Ajustes finos (v39)** — comprovante desce `margin-top:84px` (alinha ao 1º campo, ajustável); tabela de
  fornecedores com **Telefone/E-mail/Cidade-Região** (col. `telefone`/`email`/`endereco`; vazio="—"); e o
  lançar **permanece no Novo lançamento** no sucesso (troca `irInicio()` por `irForm('novo')`) + limpa o
  form → **lançar em série**. Erro NÃO limpa; duplicata (hash/documento) barra antes do insert; parcelado ok.

### Fila (grandes — exigem quiz próprio), em ordem sugerida
1. **Conciliação por IA no Fechamento (Parte B)** — **JÁ PLANEJADA E APROVADA** (desenho completo e prompt
   no arquivo de plano). Fluxo: anexa comprovante de **pagamento**, a IA lê **valor + destinatário**, **casa
   combinações de até 3-4 reembolsos** filtrando por **pessoa/período/fornecedor**; **sempre PROPÕE e o
   usuário DECIDE, nunca automático**; **segurança anti-injeção obrigatória** (com teste de injeção); **reusa
   `darBaixa`**; **gate de gestão**.
2. **Produtos proibidos + desconto automático.**
3. **Profissionalizar infra** (Supabase Pro + backup + **banco DEV**) — precisa do Leandro presente.

### Pendências de UX do desktop (adiadas de propósito)
- **Administração** com "muita coisa solta" → organizar em **submenus**.
- **Console de Gestão** sai de perto da Administração e vai para o **rodapé do menu**, em lugar próprio, só
  para o dono (estilo "Sistema de Gestão").
- Organizar o módulo **Ajustes**.

### Ponto aberto (mantido)
- As **59 linhas** em `lancamentos` com `deleted_at` preenchido — confirmar, **logado como a empresa**, se os
  lançamentos ativos esperados aparecem. Registro em `supabase/auditoria/pago-campos.txt`.

---

## Estado anterior — 06/08/2026 (v36)

## Estado anterior — fim de 05/08/2026

### 1. Migrations aplicadas em produção (até a 0011)
Todas em `supabase/migrations/`, **aplicadas** via workflow **Run SQL Migration** (idempotentes).
Registros read-only do "antes/depois" em `supabase/auditoria/`.

| Migration | O que fez |
|---|---|
| `0007_rls_insert_logs_sistema.sql` | Policy de INSERT `to postgres` em `eventos_auditoria` — corrige o soft-delete que violava RLS ao auditar. |
| `0008_lanc_select_ver_excluidos.sql` | `lanc_select` deixa de esconder `deleted_at`; o front filtra excluídos (permite auditar/ver excluídos). |
| `0009_comprovantes_hash_integridade.sql` | Policies de comprovantes + gravação real do hash sha256 (o INSERT era negado em silêncio); integridade da duplicata por arquivo. |
| `0010_duplicata_documento.sql` | `numero_nota_extraido` + RPCs de duplicata **empresa-inteira** (por hash e por documento), `security definer` com guarda de pertencimento. |
| `0011_motivos_exclusao.sql` | Tabela `motivos_exclusao` (por empresa; RLS SELECT por empresa, escrita gestor/dono) + coluna `lancamentos.motivo_exclusao` (motivo vai à auditoria via `dados_depois`). |

### 2. Versão atual
- **`sw.js` v34 / `APP_VERSION` 34.** Regra: **bump CONJUNTO** dos dois a cada release —
  devem sempre bater. O indicador em **Ajustes** mostra ambos e sinaliza "atualizando"
  se divergirem (ver CLAUDE.md §11.3).

### 3. O que foi feito hoje (05/08)
- **Unificação de papel** (perfil do app x papel da empresa) e **navegação única**.
- **Leitura por IA sob ação do usuário** (dispara na ação, não automática) + **recorte manual** do comprovante.
- **Precisão da IA**: categoria restrita às da **empresa** + **consolidação de fornecedor**.
- **Erros amigáveis** com código `ERR-XXXX`.
- **Leva 1 e 1.1 de UI**: valores **sem "R$"** com 2 casas, ordenação por **recência**,
  cards legíveis, **parcelados agrupados**, **últimos 5** no Dashboard, **filtro de status
  unificado**, **ver comprovante na edição**.
- **Modal de confirmação Maradel** (substitui todos os `confirm()` nativos; `aviso/confirmar/escolher`).
- **Exclusão financeiramente segura**: **pago exige estorno** (gate por `status`) +
  **motivo obrigatório** cadastrável (lista por empresa + "Outro"); "todas as parcelas"
  lista só as **não pagas**.
- **Correção do soft-delete/RLS** (0007/0008) e **4 camadas de detecção de duplicata**
  (hash de arquivo + documento extraído + lógica valor/data/CNPJ, tudo empresa-inteira).
- **Botão voltar do Android**: **sentinela única idempotente** (fim do empilhamento 3→5→7);
  modal "Sair do sistema?" em todo `popstate`. **Limite de plataforma documentado**: no
  zero-toque a frio o Chrome standalone descarrega a página sem `popstate` (sem API para
  interceptar) — mitigado pelo item abaixo.
- **Manter a tela no refresh** (`sessionStorage` + `restaurarTela`, whitelist; editar/baixa
  caem para a lista).
- **Indicador de versão** em Ajustes (APP_VERSION x cache do SW).

### 4. Fila para amanhã (06/08), em ordem
1. **(a) Memória de categoria por estabelecimento — JÁ DECIDIDA.** Quando a IA cai em
   "Outros" ou não identifica, **sugerir a categoria mais usada naquele fornecedor**.
   **Não é IA** — é consulta ao histórico. Casa por **CNPJ → nome normalizado**. Preenche
   **silenciosamente**. A IA tem **prioridade quando confiante**.
2. **(b) "Por pessoa" vira filtro** — o dashboard recalcula para a pessoa escolhida.
3. **(c) Modal de input** para trocar os `prompt()` de renomear (setor/categoria/motivo).
- **Grandes (exigem quiz/decisão própria):** produtos proibidos + desconto automático;
  profissionalizar infra (**Supabase Pro** + backup + **banco DEV**).

### 5. Ponto aberto (verificar)
- Em `lancamentos`, as **59 linhas** vistas via `postgres` estavam **todas com
  `deleted_at` preenchido**. **Confirmar, logado como a empresa**, se os lançamentos
  **ativos esperados** aparecem (o `postgres` enxerga todas as empresas + excluídos, então
  pode ser só efeito de visão — mas vale checar). Registro em `supabase/auditoria/pago-campos.txt`.

### 6. Regras/padrões a manter (ver CLAUDE.md §10–§11)
- **Sem banco DEV**: desenvolvimento roda contra **produção** com dados reais; **nenhuma
  migration destrutiva** sem **backup + OK explícito**.
- **Valores sem "R$"**, sempre **2 casas**.
- **Sem travessão "—"** como separador de UI e **sem emoji**.
- **Migration em commit isolado** quando possível.
- **Bump conjunto** `sw.js` (cache `vNN`) **e** `APP_VERSION`.

---

## Backup (feito antes de tudo)
- **Branch** `backup/pre-saas-single-tenant` — código completo do app single-tenant.
- **Zip** enviado no chat (`backup-reembolsos-pre-saas.zip`).
- **Tabelas de backup no banco**: `zz_backup_perfis`, `zz_backup_lancamentos`,
  `zz_backup_fornecedores` (migration `0000_backup_pre_saas.sql`).

## Como as migrations são aplicadas
Versionadas em `supabase/migrations/`. Aplicadas pela Management API via GitHub
Actions (workflow **Run SQL Migration** → input `file`). Nada é editado à mão no
painel. Reaplicar é seguro (todas idempotentes).

## Fundação aplicada — `0001_saas_foundation.sql` ✅ (live)
Conferência: 1 empresa · 4 usuários · 4 vínculos · 16 categorias · 16 lançamentos
migrados e numerados.

Criado (aditivo, sem quebrar o app atual):
- Tabelas: `planos`, `empresas`, `usuarios`(+`is_owner`), `empresa_usuarios`
  (papel+setor no vínculo, N:N), `setores`, `categorias`, `contadores`,
  `politicas_limite`, `alertas`, `uso_ia`, `consumo_mensal`,
  `eventos_auditoria`, `eventos_seguranca`, `parcelas`, `comprovantes`.
- `lancamentos`/`fornecedores` ganharam `empresa_id` + colunas de IA/soft-delete.
- **Empresa Maradel** criada (`a1a1a1a1-…-000000000001`), plano Básico, e todos
  os dados atuais migrados para ela. Leandro = `is_owner` + gestor.
- **RLS por empresa** com funções `empresas_do_usuario()`, `usuario_e_owner()`,
  `meu_papel()`, `minha_empresa()`. Preserva o comportamento atual: operador vê
  os próprios; financeiro/gestor veem a empresa; dono do SaaS vê tudo.
- **Triggers**: numeração sequencial por empresa (#0001…), preenchimento
  automático de `empresa_id`/`criado_por`, rollup de `situacao`.
- Índices de duplicata (lógica valor+data+CNPJ; exata por hash de arquivo).

> Compatibilidade: um `DEFAULT minha_empresa()` e os triggers preenchem
> `empresa_id`/número nas inserções, então o front-end antigo funciona sem
> alteração enquanto evoluímos a interface.

## Mapa de papéis
| App (perfis.papel) | Empresa (empresa_usuarios.papel) | Acesso |
|---|---|---|
| admin (Leandro) | gestor + `is_owner` | tudo |
| financeiro | financeiro | vê a empresa (leitura/baixa) |
| operador (Márcio, Adelson) | operador | os próprios |

## Como reverter
1. Código: `git checkout backup/pre-saas-single-tenant` (ou restaurar o zip).
2. Dados: as tabelas `zz_backup_*` guardam o estado original; a fundação é
   aditiva (não apaga dados), então basta apontar o app para o backup de código.

## Feito nesta noite (além da fundação)
- [x] Fundação multiempresa aplicada e verificada (0001).
- [x] Metering + segurança: funções de cota/registro (0002) e Edge Function
      endurecida (anti-injeção → quarentena, cota do plano, schema estrito,
      vocabulário fechado, teto de sanidade, validação de CNPJ, log de uso_ia).
- [x] Front-end multiempresa: carrega a empresa do usuário; a leitura por IA
      passa empresa/usuário e trata cota/quarentena.
- [x] **Painel de Administração** (gestor/dono, em Ajustes): consumo de IA vs
      cota do plano, usuários e papéis (alteráveis), alertas em aberto e
      quarentena de segurança (marcar revisado).
- [x] Testes: suíte do app (36 verificações) + testes de injeção/CNPJ da IA
      (`supabase/functions/ler-comprovante/seguranca.test.mjs`).

### Acabamentos Fase 1 — feitos
- [x] Número sequencial **#0001** nos cartões e na tabela + selo da empresa no Dashboard.
- [x] **Soft-delete** no Excluir (coluna `deleted_at`; RLS esconde).
- [x] **Auditoria** por trigger (0003): criar/editar/pagar/estornar/excluir.
- [x] **Alerta de duplicata** gravado (`registrar_alerta`) e visível no painel.
- [x] Painel admin: **cadastro de categorias** (add/ativar) e **políticas de limite** (add/remover).

### Fase 2 + acabamentos — feitos
- [x] **Aprovação multinível**: `empresas.exige_aprovacao`; lançamento de operador
      entra `pendente`; gestor/financeiro aprovam/rejeitam (na lista e no painel);
      rejeitado sai do "a pagar"; selos Pendente/Rejeitado. (migration 0004)
- [x] **Setores**: cadastro no painel admin (add/renomear/ativar).
- [x] **Onboarding de empresas** (dono do SaaS): RPC `criar_empresa` (plano +
      categorias + setor) e `vincular_usuario_empresa`; formulário no painel.
- [x] **Duplicata exata por hash**: sha256 do comprovante, checagem em
      `comprovantes` + dual-write dos metadados.
- [x] **Renomear categorias** e formulário usando as categorias da empresa (banco).
- [x] **Categorias/Setores compactos**: lista enxuta (nome ocupa a linha toda) com
      só um botão de renomear e um **liga/desliga** (switch). (migration 0005)
- [x] **Integração com ERP (Omie)**: em vez de coluna manual, a Omie virou uma
      **conexão de API**. No painel admin há a seção "Integração com ERP": informa
      App Key/App Secret, ativa e clica **Importar categorias do ERP**. As
      credenciais ficam no **servidor** (tabela `integracoes_erp`, RLS gestor/dono;
      migration 0006) e a busca roda na Edge Function **`importar-erp`**, que chama
      a API do Omie (`ListarCategorias`), casa por código/nome e cria/atualiza as
      categorias. Estrutura pronta para outros ERPs. O código do ERP aparece como
      selo discreto na categoria (sem coluna). Falta apenas validar com uma conta
      Omie real (App Key/Secret do cliente).

### Ainda aberto (evolução, precisa de infra externa ou é organização interna)
- [ ] Migrar o modelo de **parcelas** para a tabela `parcelas` (hoje parcela é
      uma linha de `lancamentos` com `id_compra`; funciona bem).
- [ ] **E-mails de evolução** e avisos por e-mail (precisa de provedor SMTP/serviço).
- [ ] **Cobrança/assinatura** (gateway de pagamento), **integração Omie**,
      **LGPD** formal e **antifraude avançado** — Fase 3, dependem de contas/credenciais.
- [ ] Criar o **login** do gestor de uma nova empresa direto pelo app (hoje o
      usuário é criado pelo fluxo de convite/painel Supabase e depois vinculado).

## Console de Gestão (desktop) — Fase A ✅
Decisão de produto: **celular = operação**, **computador = gestão**. Nasceu o
`console.html` — um "software" separado, mesmo login/backend Supabase, só para
**gestor/dono** (operador/financeiro são mandados ao app).
- Shell com **menu lateral** e **seletor de empresa** (o dono troca entre clientes).
- Seções: **Empresas** (criar/vincular usuário — dono), **Usuários e papéis**,
  **Categorias e setores**, **Integrações (Omie)**, **Políticas de limite**,
  **Aprovação**, **Consumo de IA**, **Auditoria e segurança**. **Relatórios**
  entra na Fase B (placeholder).
- No app, a tela "Administração" ganhou um atalho **"Console de Gestão"** para o
  computador. `sw.js` v12 cacheia cada documento pela própria URL (corrige o
  cache que sobrescrevia index.html) e inclui o console no shell.
- Testes: nova suíte `console.test.mjs` (9 verificações) verde.

### Navegação por módulos no app (Fase C — em andamento)
- **Fechamento do mês**, **Administração** e **Console de Gestão** saíram de dentro
  de Ajustes e viraram **itens próprios no menu lateral** (aparecem por papel:
  Fechamento p/ quem vê tudo; Administração e Console p/ gestor/dono).
- O menu lateral ganhou **botão hambúrguer**: no **computador** recolhe para uma
  barra só de ícones (estado lembrado); no **celular** o menu virou uma **gaveta**
  que abre/fecha pelo hambúrguer do topo (com fundo escurecido) e fecha ao navegar.
- `sw.js` v14.

### Próximas fases do console
- **B** — Relatórios e indicadores gerenciais amplos + exportação (PDF/XLSX/CSV) e fechamento.
- **C (resto)** — Definir os poucos indicadores que ficam no celular; enxugar o operacional.
- **D** — Onboarding completo de empresas e gestão multiempresa aprofundada.

## Fase 2/3 (do doc) — ainda não iniciado
Aprovação multinível, relatórios customizáveis, e-mails de evolução, onboarding
de empresas, cobrança/assinatura, API genérica (Omie), antifraude avançado.
Os campos de aprovação (`lancamentos.aprovacao`) já nascem no schema.
