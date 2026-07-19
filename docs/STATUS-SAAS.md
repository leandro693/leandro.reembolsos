# Status da refundação SaaS multiempresa

> Trabalho autônomo noturno. Este documento registra o que foi feito, como
> reverter e o que falta. Fonte de verdade da arquitetura: `docs/ARQUITETURA.md`.

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
      só um botão de renomear e um **liga/desliga** (switch). Cada linha tem um
      campo de **código externo** para mapear a categoria/setor ao ERP (ex.: Omie),
      preenchido manualmente (integração automática é Fase 3). (migration 0005)

### Ainda aberto (evolução, precisa de infra externa ou é organização interna)
- [ ] Migrar o modelo de **parcelas** para a tabela `parcelas` (hoje parcela é
      uma linha de `lancamentos` com `id_compra`; funciona bem).
- [ ] **E-mails de evolução** e avisos por e-mail (precisa de provedor SMTP/serviço).
- [ ] **Cobrança/assinatura** (gateway de pagamento), **integração Omie**,
      **LGPD** formal e **antifraude avançado** — Fase 3, dependem de contas/credenciais.
- [ ] Criar o **login** do gestor de uma nova empresa direto pelo app (hoje o
      usuário é criado pelo fluxo de convite/painel Supabase e depois vinculado).

## Fase 2/3 (do doc) — ainda não iniciado
Aprovação multinível, relatórios customizáveis, e-mails de evolução, onboarding
de empresas, cobrança/assinatura, API genérica (Omie), antifraude avançado.
Os campos de aprovação (`lancamentos.aprovacao`) já nascem no schema.
