# Arquitetura — SaaS de Reembolsos (Maradel) · Fase 1

Referência in-repo da estrutura implementada. Detalhe narrativo completo no
documento de handoff do produto. Fonte de verdade do schema: as migrations em
`supabase/migrations/`.

## Princípios
1. **Multiempresa desde o dia zero** — `empresa_id` em toda tabela de negócio,
   isolamento por **RLS**, não por filtro de aplicação.
2. **Usuário ↔ empresa é N:N** — papel e setor vivem no vínculo (`empresa_usuarios`).
3. **Dono do SaaS** — flag `is_owner` em `usuarios`, fora do RLS de empresa.
4. **A IA nunca executa ações** — só extrai dados para um schema fechado.
5. **Conteúdo externo é dado não confiável** — nunca instrução (anti-injeção).
6. **Soft-delete + auditoria** em tudo que é financeiro.

## Tabelas (migration 0001)
`planos`, `empresas`, `usuarios`, `empresa_usuarios`, `setores`, `categorias`,
`contadores`, `lancamentos`, `parcelas`, `comprovantes`, `politicas_limite`,
`alertas`, `uso_ia`, `consumo_mensal`, `eventos_auditoria`, `eventos_seguranca`.

## RLS (padrão)
Funções `security definer`: `empresas_do_usuario()`, `usuario_e_owner()`,
`meu_papel(empresa)`, `minha_empresa()`. Toda tabela de negócio libera acesso só
à(s) empresa(s) do usuário; dono do SaaS vê tudo. Papel fino (operador vê os
próprios; financeiro/gestor veem a empresa) é aplicado nas policies e reforçado
na Edge Function.

## Papéis
- `operador` — lança e vê os próprios.
- `financeiro` — vê a empresa, marca pago/estorna, relatórios.
- `gestor` — visão completa da empresa, cadastros, aprova (Fase 2).
- `is_owner` — dono do SaaS (administra empresas e planos).

## Metering e planos
1 leitura de IA = 1 cota; manual não consome. Cota mensal por empresa
(`planos.cota_leituras_mensal`), consumo em `consumo_mensal`, log em `uso_ia`.
Ao esgotar: bloqueia leitura por IA, libera manual, avisa gestor + dono.
Cobrança é Fase 3.

## Segurança de IA (anti-injeção) — piso obrigatório
Conteúdo do comprovante entra **delimitado como dado**; saída em **schema
estrito** (rejeição total fora do schema); **vocabulário de categoria fechado**
por empresa; **detector de padrões suspeitos** antes da IA → quarentena em
`eventos_seguranca` (revisão humana, nunca descarte automático); escapar HTML na
UI; nomes de arquivo sanitizados; signed URLs curtas; validação de CNPJ e teto
de sanidade de valor. Testes de injeção obrigatórios.

## Edge Functions
- `ler-comprovante` — leitura por IA (Gemini Flash) com anti-injeção, validação
  de schema/vocabulário, sanidade e metering.
- Triggers no banco: numeração sequencial, defaults de empresa, rollup de situação.

## Roadmap
- **Fase 1** (atual): multiempresa + RLS + núcleo + duplicata + limites +
  dashboard + metering + segurança de IA.
- **Fase 2**: aprovação multinível + relatórios customizáveis + e-mails +
  onboarding de empresas.
- **Fase 3**: API genérica (Omie) + painel do dono + cobrança + LGPD + antifraude.
