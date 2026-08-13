# Status da refundação SaaS multiempresa

> Trabalho autônomo noturno. Este documento registra o que foi feito, como
> reverter e o que falta. Fonte de verdade da arquitetura: `docs/ARQUITETURA.md`.

---

## Estado atual — 12/08/2026 (v60 publicado e estável)

- **Versão no ar: `sw.js` v60 / `APP_VERSION` 60** — publicada e **estável** (site 200; Pages success).
  Working tree limpo, branch em sincronia.
- **Migrations aplicadas: até `0014`** — a **0014 (crédito/saldo) foi APLICADA em produção** (ritual
  completo: dumps + antes + rollback). **0013 (Storage Parte 2) segue NÃO aplicada.** Nada de schema
  mudou desde a 0014: v58→v60 são **100% front** (banco intocado).
- **Edge Functions no ar (4):** `ler-comprovante`, `importar-erp`, `ler-pagamento`, `gestao-usuarios`.

### Feito em 12/08 — Reorganização da navegação/UX da gestão (v58→v60, só front)
- **v58 — Administração em 6 abas:** `Usuários · Cadastros · Controles · Integração · Plano & IA ·
  Empresa (só dono)`, no padrão de abas (`ADM_ABAS`/`mostrarAbaAdmin`/`restaurarAbaAdmin`, lembra a última
  em `mrd_admin_tab`, chips roláveis no mobile). Só reorganização visual; cada seção manteve sua lógica.
- **v59 — Tela Saldos no menu:** cartões dos operadores em modo crédito (saldo via `saldo_operador`,
  crédito recebido, gasto = crédito − saldo; negativo em vermelho). O **financeiro** passou a lançar
  crédito direto (modal reusado com gate `veTudo`). A **carteira saiu da aba Usuários** (só "Definir modo"
  ficou lá). Reusa as RPCs existentes; banco intocado.
- **v60 — Módulo Financeiro + Console no rodapé + navegação reorganizada:**
  - **Financeiro (`scFinanceiro`)** com abas **Fechamento | Saldos** (mesmo padrão do v58:
    `FIN_ABAS`/`mostrarAbaFin`/`restaurarAbaFin`, `mrd_fin_tab`). O conteúdo de scMarcar/scSaldos virou os
    painéis `fin-fechamento`/`fin-saldos` **sem tocar a lógica** (darBaixa, conciliação por IA, renderSaldos,
    RPCs, modal). `irFinanceiro` (gate `veTudo`) prepara os dois painéis; `irMarcar`/`irSaldos` viraram
    **atalhos** que abrem a aba certa.
  - **Console de Gestão** virou **"Sistema de Gestão"** em lugar ÚNICO no **rodapé do menu** (`sb-foot`),
    com gate mudado de `ehGestor` para **`isOwner`** (gestor não-dono não vê mais). Removido da sidebar-nav
    e do card da Administração (fim da duplicação).
  - **Manter-tela:** `scFinanceiro` restaurável no refresh + **migração** de valores legados salvos
    (`scMarcar`→Financeiro/Fechamento, `scSaldos`→Financeiro/Saldos).
- **PENDENTE (próximo, de-para já aprovado) — v61: Ajustes reorganizado em CARTÕES** (`Conta ·
  Preferências · Pagamento` + **versão em destaque**). Independente da navegação (só reagrupa markup),
  valida sozinho. É a **última pendência** da reorganização de navegação/UX (fatiado do v60 a pedido do
  Leandro, para isolar risco: navegação quebrada é pior que tela quebrada).

### Feito em 12/08 — Sistema de crédito/saldo NO AR e validado (v57, migration 0014)
- **Crédito/saldo (conta corrente do operador)** — validado no aparelho. **Migration 0014 APLICADA:**
  `empresa_usuarios.modo_lancamento` (default `'despesa'`), tabela `creditos_operador` (RLS: operador vê o
  próprio, gestão a empresa inteira) e **4 RPCs** `security definer` com gate de papel no SQL:
  `lancar_credito` (`lancado_por=auth.uid()`), `set_modo_operador`, `remover_credito` (soft-delete),
  `saldo_operador`.
- **Como funciona:** modo **por operador** (despesa = atual, padrão; crédito = novo); **crédito avulso**
  lançado pela gestão; **saldo = créditos − despesas** (acumula, não zera no mês); **saldo negativo avisa
  e deixa lançar**; **decisão D** — operador em modo crédito fica **fora do "A receber"/Fechamento** (a
  empresa já adiantou; não paga duas vezes). **Só gestão** lança crédito e define o modo (RPC gated;
  operador barrado no banco). **Card de saldo** no Dashboard do operador-crédito (substitui os KPIs de
  "a receber"); coluna **Modo** + modal **Saldo & créditos** na Administração.
- **Resiliência:** o front detecta se a 0014 foi aplicada (`creditoDisponivel`) → antes de aplicar, rodava
  idêntico ao modo despesa (deploy do código separado da aplicação da migration). Ritual de produção:
  dumps salvos (`dump-empresa_usuarios-2026-08-12.txt`, `schema-snapshot-2026-08-12.txt`), "antes"
  reconfirmado, rollback pronto (`rollback-0014.sql`). Pós-aplicação: 5 linhas de `empresa_usuarios`
  intactas, todas `modo_lancamento='despesa'`.

### Feito em 11-12/08 — Gestão de usuários: bloco CONCLUÍDO e validado
- **Fluxo de criar usuário novo VALIDADO** — `leandrolfsg` criado limpo (Auth + `usuarios` +
  `empresa_usuarios` + senha provisória), **sem conta fantasma/órfã**. Com a raiz corrigida (v55
  `papel`→`papel: perfil`) + a blindagem de adoção (v56), o **bloco de gestão de usuários está fechado**.

### PENDENTE / PRIORIDADE — profissionalizar a INFRA do Reembolsos
- **O projeto Reembolsos está em plano SEM backup automático** (diferente da Cobrança, que é **Pro**). A
  0014 foi aplicada com **dump manual como rede de segurança**, justamente porque não há backup do plano.
- **Antes de escalar para mais clientes:** subir o Reembolsos para **Supabase Pro** (backups automáticos +
  PITR). É pré-requisito de segurança para produção com dados reais.

### Feito em 11/08 — Gestão de usuários completa (v52–v56) + Storage + toasts
- **Gestão de usuários na Administração (v52):** Edge Function nova **`gestao-usuarios`** (service role, gate
  no backend por dono/gestor). Ações: **criar** (Auth + `usuarios` + `empresa_usuarios` + senha provisória
  com troca obrigatória no 1º acesso), **editar** (nome/e-mail/perfil), **ativar/desativar**, **senha
  provisória**, **gerar link de acesso** (recovery). O app **força a troca** no 1º acesso; desativado é
  bloqueado. Só gestão gerencia (front + backend). Reenviar por e-mail: pendente (SMTP não configurado).
- **Saga de bugs até a RAIZ (v53–v55):** v47-style. (1) v53: modal de criar/editar **travado** (não fecha
  no backdrop/Esc/voltar) + **erro inline** no modal + gate defensivo do seletor de pessoa. (2) v54: vínculo
  por insert simples + helpers `db()`/`authAdmin()` blindados. (3) **v55 = RAIZ:** o vínculo usava a variável
  **`papel` (inexistente) em vez de `papel: perfil`** → ReferenceError mascarado pelo `"erro ao processar"`
  genérico, deixando órfã. Corrigido; teste real provou os 3 registros criados ponta a ponta.
  - **LIÇÃO (registrada):** bug de Edge Function que persiste → **ler o deploy linha a linha + log de
    execução**, não teorizar; trocar catch genérico por mensagem do passo que falhou. Ver
    `[[depurar-edge-function]]` (memória).
- **Blindagem de adoção de órfã (v56):** (a) `if(!uid)` apaga a conta do Auth; (b) **"e-mail já existe"
  AUTOCURÁVEL** — se a conta é órfã (sem vínculo), a função **adota** (cria vínculo + senha provisória) em
  vez de dar erro; (c) se a limpeza falhar, registra `orfa_nao_removida` em `eventos_seguranca`.
  **PENDENTE DE VALIDAÇÃO:** o teste real da adoção (criar `orfa.teste` que já existe como órfã → adotar)
  **não foi confirmado** (a órfã de teste seguia sem vínculo; foi removida no fecho). Retestar quando quiser.
- **RLS/Storage 0012 Parte 1 (APLICADA):** `comp_select` do bucket `comprovantes` ampliada — **gestor/
  financeiro/dono leem os comprovantes da empresa inteira** (helper `pode_ver_comprovante`, `security
  definer`). **Corrigiu o ERR-1500** (gestor abrindo comprovante de operador). Rollback pronto em
  `supabase/auditoria/rollback-0012-parte1.sql`.
- **Toasts de sucesso destacados (v56):** sucesso vira **pílula verde sólida** (#1E9E57), texto branco,
  **check** bem visível, maior, com "pop" e um pouco mais de tempo; erro com fundo vermelho tênue. Nos dois
  fronts. (Toast mantido embaixo/centralizado — no topo colidiria com o header no mobile.)

### Pendências menores (aplicar/fazer depois)
- **Storage Parte 2 (`0013_storage_pagamentos_empresa.sql`)** — endurece a leitura da pasta `pagamentos/`
  (restringe a leitura do comprovante de lote à empresa). **Só aplicar depois** de testar a leitura de um
  comprovante de LOTE como gestor. SQL pronto, ritual pendente.
- **UX:** submenus na Administração; Console de Gestão no rodapé do menu (só dono); organizar Ajustes.

### Feito em 11/08 — Identidade visual (Inter + tema Preto + divisória do menu)
- **Fonte Inter self-hosted + números tabulares (v50)** — trocada a fonte do app para **Inter** (nítida em
  tela), **self-hosted** (`fonts/inter-latin.woff2` + `-ext`, no `SHELL` do `sw.js` → offline, sem CDN) via
  `@font-face` com `font-display:swap` (fallback de sistema). **Removida a JetBrains Mono** (unificado em
  Inter). Números com **`font-variant-numeric:tabular-nums`** nos contextos numéricos (valores, tabelas,
  dashboard, tabela da conciliação) → dígitos de **largura fixa**, colunas alinhadas; texto proporcional.
- **3º tema "Preto" (v50)** — além de Claro/Escuro, tema **Preto**: `--bg-page:#000`, texto branco,
  **laranja Maradel `#DB8438` mantido**; superfícies quase-pretas (`--surface:#101012`/`#0A0A0B`) para os
  cards não sumirem. Seletor em Ajustes vira **Claro/Escuro/Preto**; toggle **cicla os 3**; persiste em
  `mrd_tema` (console: `tema`). Vale nos **dois fronts**.
- **Linha divisória do menu (v51)** — `border-right:1px solid var(--border)` na sidebar (desktop) nos dois
  fronts, consistente nos 3 temas (no Preto a linha branca leve separa); e no **tema Preto** a sidebar ganha
  tom `#0A0A0B` (levanta o menu do fundo `#000`, acabamento "Claude web"). **Mobile intacto** (a divisória
  fica só no `@media(min-width:980px)`; no celular o menu é gaveta sobreposta). Só CSS.

### Feito em 11/08 — Parte B: Conciliação por IA no Fechamento (validada no aparelho)
- **Parte B (v48)** — anexa **comprovante de PAGAMENTO** no Fechamento; **Edge Function nova `ler-pagamento`**
  (separada da `ler-comprovante`) lê **valor + destinatário** com **schema estrito** `{legivel, valor,
  destinatario}` e **blindagem anti-injeção**. O sistema **casa** os reembolsos em aberto, **propõe** a baixa
  e a pessoa **confirma** — baixa reusa **`darBaixa`** (com o comprovante de pagamento como comprovante do
  lote). **Banco intocado** (reusa `comprovante_pagamento`, `eventos_seguranca`, metering).
- **Ajuste do casamento + apresentação (v49)** — o casamento passou a ser **SOMA POR DATA DE VENCIMENTO**
  (agrupa os em aberto por `vencimento`, soma o grupo inteiro e compara com o valor lido). **Aposentou o
  subset-sum limitado a 4**, que deixava reembolsos de fora (no caso real, 6–7 reembolsos do mesmo vencimento
  davam **931,58** de diferença; **agora fecha exato**). A conferência virou **modal em TABELA grande**
  (Vencimento·Categoria·Fornecedor·Pessoa·Valor) com **recálculo ao vivo** de Total/Diferença ao marcar/
  desmarcar; variante **`lg` do modal (920px, resetada a cada abertura** para não vazar largura aos outros
  modais). **Validado no aparelho** com caso real.
- **PRINCÍPIO da Parte B (permanente):** a IA e o casamento **sempre PROPÕEM; a pessoa sempre DECIDE** —
  **nunca** baixa automática (nem quando bate exato). **Gate só gestão** (`veTudo()`). **Segurança:** o
  comprovante de pagamento é **dado não confiável**; a IA **só lê** (schema fechado valor+destinatário); o
  **destinatário passa pelo detector de injeção + quarentena** (`eventos_seguranca`, painel admin já existe);
  a **baixa é sempre confirmada**. Testes deterministas no harness; comportamento do modelo validado em
  chamada real.

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
> Concluídos e no ar: Conciliação por IA (v48-49), Gestão de usuários (v52-56), Crédito/saldo (v57).
1. **PRIORIDADE — Profissionalizar infra do Reembolsos** (Supabase **Pro** + backups automáticos + **PITR**
   + banco DEV) — o projeto está em plano **SEM backup automático**; pré-requisito antes de escalar clientes.
   Precisa do Leandro presente.
2. **Produtos proibidos + desconto automático.**

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
