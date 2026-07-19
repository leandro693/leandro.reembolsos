# Reembolsos Maradel

Aplicativo (PWA) para os diretores da Maradel lançarem e controlarem reembolsos
pelo celular, com dados na nuvem e segurança de verdade.

- **Login por e-mail e senha** (só os 3 diretores acessam).
- **Nuvem e compartilhado**: os dados ficam no Supabase, com backup automático.
- **Segurança real**: cada diretor só enxerga e altera os próprios lançamentos,
  validado no servidor (Row Level Security), não no aplicativo.
- **Instalável no celular** direto pela tela inicial, sem loja (PWA).
- **Identidade Maradel**: tema claro e escuro, tipografia e cores da marca.
- Lançamento manual ou com foto do comprovante, quilometragem, parcelamento,
  consultas, marcar como recebido, resumo por categoria e relatório em PDF.

Sem n8n. O backend antigo foi substituído pelo Supabase.

---

## Como colocar no ar (passo a passo)

Você faz isso uma única vez. Leva cerca de 15 minutos.

### 1. Criar o projeto no Supabase (grátis)
1. Acesse <https://supabase.com> e crie uma conta.
2. Clique em **New project**. Dê um nome (ex.: `reembolsos-maradel`), defina uma
   senha de banco e escolha a região **South America (São Paulo)**.
3. Aguarde o projeto ficar pronto (1 a 2 minutos).

### 2. Criar as tabelas e a segurança
1. No menu lateral, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo [`supabase-setup.sql`](./supabase-setup.sql) deste repositório,
   copie **todo** o conteúdo, cole no editor e clique em **Run**.
3. Deve aparecer "Success". Isso cria as tabelas, as regras de segurança e o
   armazenamento das fotos de comprovante.

### 3. Criar os 3 usuários (diretores)
1. No menu lateral, abra **Authentication > Users** e clique em **Add user**.
2. Informe o **e-mail** e uma **senha** para o diretor.
3. No campo **User Metadata (Raw JSON)**, coloque o nome que aparece no app:
   ```json
   { "nome": "Leandro" }
   ```
4. Repita para **Márcio** e **Adelson** (cada um com o próprio e-mail e senha).

> Dica: use os e-mails `@maradelcontabil.com`. As senhas você define aqui e
> entrega a cada diretor. Eles podem usar a mesma senha no primeiro acesso e
> você troca depois se quiser.

### 4. Ligar o app ao seu Supabase
1. No Supabase, abra **Project Settings > API** e copie dois valores:
   - **Project URL** (algo como `https://xxxx.supabase.co`)
   - **anon public** (uma chave longa começando com `eyJ...`)
2. Abra o arquivo [`index.html`](./index.html), logo no início do `<script>`,
   e preencha:
   ```js
   const SUPABASE_URL      = 'https://xxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJhbGciOi...';
   ```
   A `anon public` é feita para ficar exposta no app: quem protege os dados são
   as regras de segurança do banco (passo 2), não essa chave.
3. Salve e faça o commit dessa alteração.

### 5. Publicar (GitHub Pages, grátis)
1. Neste repositório, vá em **Settings > Pages**.
2. Em **Source**, escolha **Deploy from a branch**, selecione a branch
   (ex.: `main`) e a pasta **/(root)**. Salve.
3. Em 1 a 2 minutos o GitHub mostra o endereço público, algo como
   `https://leandro693.github.io/leandro.reembolsos/`.
4. Abra esse endereço no navegador. Deve aparecer a tela de login.

> O PWA precisa de HTTPS. O GitHub Pages já entrega HTTPS automaticamente.
> Vercel e Netlify também funcionam, se preferir.

### 6. Instalar no celular
Envie o endereço do passo 5 para os diretores. Cada um faz:
- **Android (Chrome):** abrir o link, tocar no menu e em
  **Instalar aplicativo** / **Adicionar à tela inicial**.
- **iPhone (Safari):** abrir o link, tocar em **Compartilhar** e em
  **Adicionar à Tela de Início**.

Pronto: o app abre em tela cheia, com ícone próprio, como um aplicativo nativo.

---

## Usando o app

- **Dashboard:** cartões de saldo (próximo vencimento, a receber, em atraso),
  gráficos e os lançamentos vencendo em breve.
- **Lançar:** com foto do comprovante (IA preenche) ou manual. Categorias de
  quilometragem calculam o valor por km; compras podem ser parceladas
  (vencimentos no dia 10). O fornecedor tem autocompletar: ao escolher um já
  cadastrado, o CPF/CNPJ vem preenchido.
- **Lançamentos:** filtros por status; botão **Data** com períodos prontos, tanto
  a receber (próximo mês, próximos 3 e 6 meses) quanto passados (mês passado,
  últimos 3 meses), além de este mês, este ano e todo período; e, para quem vê
  todos, filtro por **pessoa**. Tem ainda resumo por categoria, seleção para
  marcar vários como recebidos e o menu **Relatórios** (PDF, balancete com
  comprovantes anexos e exportação em `.xlsx`), que respeita os filtros ativos.
- **Fornecedores:** cadastro (nome, CPF/CNPJ com máscara automática, telefone,
  e-mail e cidade/região). Cresce sozinho a cada lançamento com nota e também pode
  ser editado à mão. Mostra quantos lançamentos e o total de cada um. Criar novos
  é liberado a todos; **editar e excluir são exclusivos do administrador**.
- **Ajustes:** tema claro/escuro, contraste, os dados de PIX que entram no PDF,
  **trocar a senha** de acesso e, para admin/financeiro, a **Visualização** (ver
  os reembolsos de todos ou só os seus). A escolha fica salva e vale para o
  Dashboard e os Lançamentos.

---

## Perguntas comuns

**É seguro?** Sim. O acesso exige login, e as regras de banco (RLS) garantem, no
servidor, que cada diretor só vê e altera os próprios dados. A chave que fica no
app (`anon public`) não dá acesso aos dados sozinha.

**Preciso pagar?** O plano grátis do Supabase e do GitHub Pages atende com folga
o uso de três diretores.

**Onde ficam as fotos dos comprovantes?** Em um armazenamento privado no
Supabase, acessível só pelo dono do lançamento, por link temporário.

**Como atualizar o app depois?** Basta editar os arquivos e fazer commit. Ao
publicar mudança grande, aumente o número em `CACHE` no `sw.js` (ex.: `-v2`)
para os celulares pegarem a versão nova.

---

## IA que lê o comprovante (Google Gemini)

O botão **"Ler comprovante com IA"** manda a foto (ou PDF) para uma **Edge
Function** no seu Supabase, que chama o **Google Gemini** e devolve categoria,
fornecedor, valor e data já preenchidos. A chave do Gemini fica em **segredo no
servidor**, nunca no aplicativo. É o que substitui o antigo fluxo do n8n.

O código da função está em `supabase/functions/ler-comprovante/index.ts`.

### 1. Criar a chave do Gemini (grátis)
1. Acesse <https://aistudio.google.com/app/apikey> e faça login com uma conta Google.
2. Clique em **Create API key** e copie a chave (algo como `AIza...`).

### 2. Publicar a função no Supabase
No painel do Supabase, menu lateral → **Edge Functions**:
1. Clique em **Deploy a new function** (ou **Create a new function**).
2. Nome exatamente: **`ler-comprovante`**.
3. Cole o conteúdo do arquivo `supabase/functions/ler-comprovante/index.ts` no editor.
4. Clique em **Deploy**.

> Alternativa por terminal (se preferir o CLI):
> `supabase functions deploy ler-comprovante`

### 3. Guardar a chave do Gemini como segredo
Ainda em **Edge Functions** → aba **Secrets** (ou **Project Settings → Edge
Functions → Secrets**):
1. **Add new secret**.
2. Nome: `GEMINI_API_KEY` — Valor: a chave `AIza...` do passo 1.
3. Salve.

Pronto. No app, anexe uma foto e toque em **"Ler comprovante com IA"**: os campos
são preenchidos e você só confere e lança. Se a função ainda não estiver
publicada, o app avisa e você preenche manual, sem travar.

> Custo: o Gemini Flash tem cota grátis generosa e é muito barato por imagem.
> Para trocar o modelo, edite `MODELO` no topo da função.

---

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O aplicativo inteiro (interface + lógica). |
| `manifest.webmanifest` | Configuração do PWA (nome, ícones, cores). |
| `sw.js` | Service worker: instala e abre o app rápido. |
| `icons/` | Ícones do app (marca Maradel: grafite e terracota). |
| `supabase-setup.sql` | Script do banco: tabelas, segurança e storage. |
| `supabase-v2-fundacao.sql` | v2: perfis de acesso, fornecedores e campos de nota. Rode depois do setup. |
| `supabase-v3-fornecedor.sql` | v3: telefone e e-mail separados no fornecedor. Rode depois do v2. |
| `supabase/functions/ler-comprovante/` | Edge Function da IA (Gemini) que lê o comprovante. |

### v2 Fase 1 (perfis e fornecedores)

Rode o `supabase-v2-fundacao.sql` no SQL Editor (depois do `supabase-setup.sql`).
Ele cria os papéis de acesso (admin, operador, financeiro), o cadastro de
fornecedores e os campos de nota no lançamento. Papéis:

- **admin** (Leandro): vê tudo e gerencia cadastros.
- **operador** (Márcio, Adelson): lança e vê apenas os próprios.
- **financeiro** (Eliciane): vê todos os reembolsos, somente leitura.

O script já define Leandro como admin. Ao criar os outros usuários, ajuste os
papéis com os comandos comentados no final do arquivo.
