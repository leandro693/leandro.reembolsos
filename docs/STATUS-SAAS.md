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
_(atualizado conforme avança — ver commits)_
- [x] Fundação multiempresa aplicada e verificada.
- [ ] Endurecimento anti-injeção da IA + metering na Edge Function.
- [ ] Painel administrativo (gestor/dono): metering, usuários, categorias,
      setores, políticas, alertas, segurança/auditoria.
- [ ] Número sequencial (#0001) e soft-delete na interface.

## Fase 2/3 (do doc) — ainda não iniciado
Aprovação multinível, relatórios customizáveis, e-mails de evolução, onboarding
de empresas, cobrança/assinatura, API genérica (Omie), antifraude avançado.
Os campos de aprovação (`lancamentos.aprovacao`) já nascem no schema.
