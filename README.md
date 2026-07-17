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

- **Início:** cartões de saldo (próximo vencimento, a receber, em atraso) e os
  últimos lançamentos.
- **Lançar:** manual ou com foto do comprovante. Categorias de quilometragem
  calculam o valor por km; compras podem ser parceladas (vencimentos no dia 10).
- **Consultas:** filtros por próximo vencimento, em aberto, em atraso,
  recebidos, parcelados e resumo por categoria. Dá para **copiar** o resumo para
  o financeiro (WhatsApp/e-mail) e **gerar PDF** com os dados de PIX.
- **Marcar como recebidos:** baixa vários lançamentos de uma vez, por mês.
- **Ajustes:** tema claro/escuro, contraste, e os dados de PIX que entram no PDF.

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

## Próximo passo opcional: foto que preenche sozinha (IA)

Hoje a foto é anexada como comprovante. Para a IA ler a nota e preencher os
campos (como fazia o fluxo antigo), dá para adicionar uma **Edge Function** no
Supabase que guarda a chave da IA com segurança. Fica para uma fase seguinte;
o app já está pronto para receber essa função.

---

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | O aplicativo inteiro (interface + lógica). |
| `manifest.webmanifest` | Configuração do PWA (nome, ícones, cores). |
| `sw.js` | Service worker: instala e abre o app rápido. |
| `icons/` | Ícones do app (grafite e terracota, marca Maradel). |
| `supabase-setup.sql` | Script do banco: tabelas, segurança e storage. |
