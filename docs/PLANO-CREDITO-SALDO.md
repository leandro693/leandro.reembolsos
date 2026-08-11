# Plano — Sistema de crédito/saldo (conta corrente do operador)

> **Status:** DE-PARA **aprovado** (11/08/2026), decisões A–E fechadas. **Não implementado.**
> Retomar por aqui em 12/08. **Toca banco (migration 0014) → ritual de produção.**

## Conceito
- **Modo "despesa" (atual, padrão):** operador lança, a empresa deve/reembolsa; há "a receber",
  fechamento, baixa. **Nada muda.**
- **Modo "crédito" (novo):** a gestão adianta crédito (avulso, quando quiser); o operador gasta e vê o
  **saldo = créditos − despesas** cair. **Acumula** (não zera no mês). Saldo negativo **avisa, não bloqueia**.

## Decisões aprovadas (A–E)
- **A.** `modo_lancamento` fica em **`empresa_usuarios`** (é por empresa, como `papel`/`ativo`).
- **B.** Saldo calculado por **RPC `security definer`** (fonte única, autoritativa, gated).
- **C.** Crédito e modo via **RPCs gated** (não Edge Function), com **`lancado_por = auth.uid()` no servidor**.
- **D.** **Excluir operadores em modo crédito do "A receber"/Fechamento** já na **v1** (crítico: sem isso,
  risco de pagar o operador-crédito duas vezes).
- **E.** Migration **0014** com **ritual de produção completo** (registro do "antes" + backup + OK antes de aplicar).

## 1) Banco (migration 0014 — 0013 já é a Parte 2 do storage, pendente)
Aditivo e idempotente. Registro do "antes" em `supabase/auditoria/` antes de aplicar.

**Coluna nova:**
```sql
alter table public.empresa_usuarios
  add column if not exists modo_lancamento text not null default 'despesa'
  check (modo_lancamento in ('despesa','credito'));
```
Default `'despesa'` → novos e existentes nascem no modo atual (não quebra nada).

**Tabela nova `creditos_operador`:**
```
id uuid pk · empresa_id uuid fk empresas · usuario_id uuid fk usuarios · valor numeric(14,2)
data date · lancado_por uuid · observacao text · criado_em timestamptz default now() · deleted_at timestamptz
```
**RLS (espelha `lanc_select` da 0008):**
- **SELECT:** `usuario_e_owner()` **OU** (`empresa_id in empresas_do_usuario()` **E**
  (`usuario_id = auth.uid()` **OU** `meu_papel(empresa_id) in ('gestor','financeiro')`)).
  → operador vê só o próprio; gestão vê a empresa inteira.
- **INSERT/UPDATE (soft-delete):** só gestão (`usuario_e_owner() OR meu_papel in ('gestor','financeiro')`).
  Defesa em profundidade; a escrita real vai por RPC.

## 2) Cálculo do saldo — RPC `security definer`
```
saldo_operador(p_empresa uuid, p_usuario uuid) returns numeric  (security definer, search_path=public)
  gate: caller é o PRÓPRIO operador (p_usuario = auth.uid()) OU gestão da empresa (owner/gestor/financeiro)
  retorna: coalesce(sum(creditos_operador.valor  where empresa,usuario, deleted_at is null),0)
         - coalesce(sum(lancamentos.valor_total   where empresa, user_id=usuario,
                        deleted_at is null and aprovacao is distinct from 'rejeitado'),0)
```
- Despesas = soma de `valor_total` dos lançamentos do operador na empresa, **não excluídos** e **não rejeitados**
  (parcelas contam cada uma).
- Chamada: no Dashboard do operador (ao abrir e após cada lançamento via `after()`) e na gestão para ver
  o saldo de qualquer operador. Consistente com a RLS.

## 3) Interface
- **(a) Definir o modo (gestão):** na tabela **Usuários** (Administração), um controle por linha
  (`select` Despesa/Crédito), só gestão → RPC `set_modo_operador`.
- **(b) Lançar crédito (gestão):** ação na linha do usuário (ícone carteira) → **modal "Saldo & créditos"**:
  saldo atual + histórico de créditos + form "Novo crédito" (valor, data=hoje, observação) → RPC `lancar_credito`.
- **(c) Operador vê o saldo:** **card de SALDO em destaque no topo do Dashboard**, **só no modo crédito**
  ("Saldo disponível: 3.250,00", verde). No modo despesa o card não aparece (Dashboard idêntico ao de hoje).
- **(d) Aviso de saldo negativo:** `saldo < 0` → card **vermelho** + alerta "Saldo negativo — gastou X além do
  crédito". **Não bloqueia** o lançamento (opcional: toast de atenção ao ficar negativo).

## 4) Segurança (backend, não só front) — 3 RPCs `security definer`
Padrão das RPCs de vocês (`checar_duplicata_*`, `vincular_usuario_empresa`), com **gate de papel no SQL**:
- **`lancar_credito(p_empresa, p_usuario, p_valor, p_data, p_obs)`** — exige caller **owner/gestor/financeiro**;
  grava `lancado_por = auth.uid()` **no servidor** (não dá para forjar quem lançou).
- **`set_modo_operador(p_empresa, p_usuario, p_modo)`** — mesmo gate; altera **só** `modo_lancamento`
  (não mexe em papel/ativo). RPC porque a policy de UPDATE de `empresa_usuarios` hoje é gestor-only; a RPC
  deixa financeiro também sem afrouxar a edição de papel/ativo.
- **`saldo_operador(...)`** — gate: próprio operador **ou** gestão.
- O **operador nunca** lança o próprio crédito nem muda o próprio modo: as RPCs checam o **papel do caller**
  (barrado no banco mesmo forjando o front). RLS como segunda camada.

## 5) Decisão D — excluir operadores-crédito do fluxo de reembolso (v1)
- Os lançamentos de um operador em modo **crédito** **não** entram em "A receber"/Fechamento/"a pagar"
  (a empresa já adiantou o dinheiro). Exclusão simples por `modo_lancamento`.
- **Onde aplicar:** o cálculo de "em aberto"/"a receber"/Fechamento passa a **desconsiderar** lançamentos de
  operadores em modo crédito (por empresa). Precisa saber o modo de cada `user_id` — via join a
  `empresa_usuarios.modo_lancamento` (ou um set de user_ids em modo crédito carregado no front para a gestão).
  Definir no detalhamento amanhã se filtra no front (a gestão já carrega os vínculos) ou numa view/RPC.

## Versão / ritual
- Bump conjunto `sw.js`/`APP_VERSION`. Branch `claude/app-opinion-u93e9u`, PT.
- **Ritual (E):** salvar "antes" (tabela/coluna inexistentes), descrever rollback
  (`drop table creditos_operador; alter table empresa_usuarios drop column modo_lancamento; drop function ...`),
  **parar e esperar OK explícito + backup** antes de disparar a 0014.

## Testes antes do commit (1–8)
1. Definir operador como crédito (via RPC, gate). 2. Gestão lança 5.000. 3. Saldo = créditos − despesas e cai ao
lançar. 4. Negativo avisa e deixa lançar. 5. Operador em despesa inalterado. 6. Gate: operador barrado no backend
ao tentar lançar crédito/mudar o próprio modo. 7. Saldo acumula entre meses. 8. Desktop e mobile.
+ guardas determinísticas das RPCs (gate por papel) no harness.

## Pontos a detalhar amanhã
- Onde exatamente filtrar o modo crédito no Fechamento/Dashboard (front vs view/RPC).
- UI final do card de saldo (posição no topo do Dashboard) e do modal "Saldo & créditos".
- Se o operador-crédito ainda anexa comprovante/segue o mesmo formulário de lançar (provavelmente sim; só muda a
  leitura de saldo e a exclusão do reembolso).
