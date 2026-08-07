# Status da refundação SaaS multiempresa

> Trabalho autônomo noturno. Este documento registra o que foi feito, como
> reverter e o que falta. Fonte de verdade da arquitetura: `docs/ARQUITETURA.md`.

---

## Estado atual — fim de 06/08/2026 (âncora; ESTADO INCOMUM: deploy travado por incidente do GitHub)

> **Atenção ao retomar (07/08):** houve incidente de infraestrutura do GitHub hoje
> (Actions/Pages degradados desde ~15:22 UTC; webhooks throttled). **Não é o nosso
> código.** Há **pendência de deploy** (v35) e **pendência de commit** (v36). Siga a
> sequência abaixo antes de qualquer coisa.

### 0. Pendências e sequência correta ao retomar
1. **Confirmar se o v35 subiu**: `curl -s https://leandro693.github.io/leandro.reembolsos/sw.js | grep -o 'reembolsos-maradel-v[0-9]*-saas'`.
   - Ao fim de 06/08 o site público ainda servia **v34** (deploy do Pages falhando por timeout do serviço, não por conteúdo — o build/Jekyll sempre passou).
2. **Leandro testa a memória de categoria no aparelho** (v35).
3. **Só então commitar o v36** ("por pessoa") — está no **working tree**, testado, sem commit.
4. **Leandro testa "por pessoa"** (v36).

### 1. Feito hoje (06/08)
- **(a) Memória de categoria por estabelecimento (v35)** — **commitada (`1a68471`) e pushada**, mas
  **DEPLOY PENDENTE** pelo incidente do GitHub. Sugere a categoria mais usada do fornecedor quando a
  IA cai em "Outros"/vazio; consulta a `lista` em memória (RLS por empresa, `deleted_at is null`);
  casa por CNPJ→`normNome`; só categoria ativa; empate pela mais recente; preenchimento silencioso.
- **(b) "Por pessoa" vira filtro (v36)** — **IMPLEMENTADO e TESTADO (tudo verde), mas NÃO commitado**
  (código no **working tree**: `index.html` + `sw.js`). Detalhes para retomar:
  - Filtro de pessoa aplicado em **`baseLista()`** (só `veTudo() && escopoVer==='todos' && pessoaFiltro`)
    → recalcula **dashboard (KPIs/gráficos/últimos/"por pessoa") E lista** de uma vez.
  - **Seletor também no topo do Dashboard** (`#dashPessoa`), gêmeo do de Lançamentos, **gated por `veTudo()`**.
  - `setPessoa` sincroniza os 2 selects + persiste em `localStorage['mrd_pessoa']` + re-render da tela ativa.
  - Persistência **validada no load** (`validarPessoaSalva`): se a pessoa não tem mais lançamentos, volta a "Todas".
  - **`sw.js` v36 + `APP_VERSION` 36** (bump conjunto **já feito no código**, falta só commitar).
  - Mensagem de commit combinada p/ o v36: `feat: "por pessoa" vira filtro (recalcula dashboard e lista; seletor no Dashboard)`.

### 2. Versão
- **Repositório: v36** (working tree). **Último commit: v35 (`1a68471`)** + commit-gatilho vazio `3510eed`.
- **Site público: v34** (deploy pendente). Bump conjunto `sw.js`+`APP_VERSION` (CLAUDE.md §11.3).

### 3. Fila seguinte (após validar "por pessoa")
- **Modal de input** (trocar os `prompt()` de renomear setor/categoria/motivo).
- **Grandes (quiz próprio):** produtos proibidos + desconto automático; profissionalizar infra
  (**Supabase Pro** + backup + **banco DEV**).

### 4. Ponto aberto (mantido)
- As **59 linhas** em `lancamentos` com `deleted_at` preenchido — confirmar, **logado como a empresa**,
  se os lançamentos ativos esperados aparecem. Registro em `supabase/auditoria/pago-campos.txt`.

---

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
