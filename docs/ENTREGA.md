# Entrega — Reembolsos Maradel

**Leia primeiro.** Este é o mapa da transição; o **território** (detalhe técnico completo) está em `docs/HANDOFF-TECNICO.md` (e `.pdf`). Versão em produção: **v62**.

## Contexto
Reembolsos Maradel é um **SaaS multiempresa (PWA)** de **gestão de reembolso de despesas corporativas** com **leitura de comprovantes por IA**: o colaborador fotografa a nota/cupom/comprovante, a IA lê e pré-preenche o lançamento, e a gestão controla a pagar/receber, vencimentos, aprovações e o fechamento (baixa em lote com comprovante). Já está **em produção, com usuários e dados reais** (empresa-mãe: Maradel Assessoria e Consultoria Contábil). Front vanilla (HTML/CSS/JS, sem framework) no GitHub Pages; backend Supabase (Postgres + Auth + Edge Functions + Storage); IA Google Gemini.

## O que está feito (funciona hoje)
- **Núcleo:** lançar despesa (manual e por **foto + IA**), parcelamento, consultas/filtros, exportação, baixa e estorno, auditoria automática.
- **IA de comprovante:** leitura por Gemini com blindagem anti-injeção (Seção 7 do handoff).
- **Conciliação por IA no Fechamento:** lê o comprovante de pagamento e **propõe** o casamento (a pessoa decide; nunca baixa automática).
- **Gestão de usuários:** criar/editar/ativar/senha provisória/link, com gate por JWT no backend.
- **Crédito/saldo (conta corrente do operador):** modo por operador, crédito avulso, saldo = créditos − despesas.
- **Navegação/UX:** Administração em abas, módulo Financeiro (Fechamento | Saldos), Console de Gestão (só dono), Ajustes em cartões, PWA offline pela casca.
- **Segurança:** RLS por empresa; anti-injeção de prompt + quarentena; **gate por JWT nas Edge Functions de IA/ERP** (empresa validada por pertencimento — corrigido no v62); segredos só no servidor.

## O que falta para vender (prioridades)
1. **Infra profissional — nº 1:** Supabase **Pro + backup automático + PITR + banco DEV** (hoje **sem backup** e sem ambiente de desenvolvimento). Handoff §3, §8.1, §10.
2. **Storage Parte 2 (migration `0013`):** endurecer a leitura de `pagamentos/`. Handoff §7.4.
3. **LGPD:** base legal, política de privacidade, retenção, contrato de operador. Handoff §8.1.
4. **Cobrança/assinatura:** billing (os planos existem no banco, sem cobrança). Handoff §8.1.
5. **Onboarding self-service de empresas** (+ painel do dono do SaaS). Handoff §8.1.

## Como começar (primeiros passos do dev)
1. Ler `docs/HANDOFF-TECNICO.md` — **Seções 1 a 4** (produto, arquitetura, banco, perfis) e o **Apêndice D** (checklist de primeiro dia).
2. Servir a pasta estática e abrir `index.html` (não abrir por `file://` — quebra o service worker).
3. Rodar os testes (sem segredo): `node tests/ajustes.test.mjs`, `node tests/edge-seguranca.test.mjs`, `node supabase/functions/ler-comprovante/seguranca.test.mjs`.
4. Solicitar os **acessos** (abaixo / Apêndice E do handoff).

## Acessos (o dev recebe por convite/canal seguro — nada disso vem no zip)
- **Supabase** (projeto `fwoupyqojfxpipvidvsx`) — convite como membro/admin.
- **GitHub** (`leandro693/leandro.reembolsos`) — acesso de escrita.
- **GitHub Secrets** já configurados (`SUPABASE_ACCESS_TOKEN` — expira ~1 ano; `TEAM_INITIAL_PASSWORD`) — combinar quem repassa/rotaciona.
- **`GEMINI_API_KEY`** (secret da função no painel Supabase).
- **Credenciais Omie** (`app_key`/`app_secret`) — só ao validar o ERP.
- **Usuário real de cada papel** (operador/financeiro/gestor) + **login de dono** para testar.

> Detalhe completo dos acessos no **Apêndice E** do handoff. As credenciais **não** estão no repositório (auditoria de segredos aprovada).

## Estado técnico (resumo)
- **Versão no ar:** v62 (`sw.js` cache `v62` + `APP_VERSION` 62).
- **Branch publicada:** **`claude/app-opinion-u93e9u`** (é a que o GitHub Pages e os workflows publicam — **não** é a `main`; planejar a promoção para `main`).
- **Migrations aplicadas:** até `0014` (a `0013` de Storage está pendente de propósito).
- **Infra:** **sem backup automático hoje** (plano free) — ver prioridade nº 1.
- **Deploy:** push publica front (Pages) e Edge Functions; **migrations só por workflow manual**.

## Contato / handoff
**Transição por documentação.** O código, o `HANDOFF-TECNICO` e este documento cobrem o necessário para assumir o projeto de forma autônoma. Não há suporte contínuo previsto; dúvidas **pontuais de bloqueio** podem ser encaminhadas à Maradel pelo canal combinado.
