// ============================================================================
// Edge Function: gestao-usuarios  (Administração — gestão de usuários completa)
// Espelha o padrão do sistema de Cobrança (Acordos): criar/editar/senha
// provisória/ativar-desativar/gerar link, TUDO no servidor com service role.
//
// Segurança (não é remendo):
//  - GATE no backend: o chamador é identificado pelo JWT (getUser) e só passa se
//    for DONO (usuarios.is_owner) ou GESTOR ATIVO da empresa alvo. A admin API
//    ignora RLS, então este é o ponto de controle — nunca confiar no front.
//  - Não pode alterar o PRÓPRIO perfil nem desativar a si mesmo.
//  - Senha provisória NUNCA vai a log/auditoria (só a marca de que foi definida).
//  - "Precisa trocar senha" = user_metadata.senha_provisoria=true (sem coluna nova).
//  - Status = empresa_usuarios.ativo (coluna já existente; RLS já respeita).
//  - Auditoria leve das ações sensíveis em eventos_seguranca (e-mail mascarado).
//  - SERVICE_ROLE só existe aqui no servidor.
// ============================================================================

const SUPA_URL    = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY    = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PAPEIS = ["operador", "financeiro", "gestor"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const emailValido = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || ""));
function mascararEmail(e: string): string {
  const [u, d] = String(e || "").split("@");
  if (!d) return "***";
  return (u[0] || "*") + "***@" + d;
}

// REST (PostgREST) com service role. NUNCA lança: qualquer erro de rede/parse vira
// { ok:false } — assim o chamador trata a falha (limpeza + erro claro) em vez de estourar
// no catch geral ("erro ao processar") e deixar conta órfã.
async function db(path: string, method = "GET", body?: unknown, prefer?: string) {
  const headers: Record<string, string> = {
    apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json",
  };
  if (prefer) headers["Prefer"] = prefer;
  try {
    const r = await fetch(`${SUPA_URL}/rest/v1/${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
    const txt = await r.text();
    let data: unknown = null; try { data = txt ? JSON.parse(txt) : null; } catch { data = txt; }
    return { ok: r.ok, status: r.status, data };
  } catch (e) {
    console.error("db() falhou:", path, e);
    return { ok: false, status: 0, data: null };
  }
}

// Auth admin (GoTrue) com service role. Também NUNCA lança (mesma proteção do db()).
async function authAdmin(path: string, method: string, body?: unknown) {
  try {
    const r = await fetch(`${SUPA_URL}/auth/v1/${path}`, {
      method, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    const txt = await r.text();
    let data: Record<string, unknown> = {}; try { data = txt ? JSON.parse(txt) : {}; } catch { data = {}; }
    return { ok: r.ok, status: r.status, data };
  } catch (e) {
    console.error("authAdmin() falhou:", path, e);
    return { ok: false, status: 0, data: {} as Record<string, unknown> };
  }
}

// Identidade do chamador a partir do JWT (não confia no corpo/front).
async function getCaller(token: string) {
  if (!token) return null;
  const r = await fetch(`${SUPA_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${token}` },
  });
  if (!r.ok) return null;
  return await r.json().catch(() => null);
}

async function rpc(nome: string, args: Record<string, unknown>) {
  try {
    const r = await fetch(`${SUPA_URL}/rest/v1/rpc/${nome}`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify(args),
    });
    return r.ok;
  } catch { return false; }
}
async function auditar(empresa: string | null, porUsuario: string, tipo: string, detalhe: Record<string, unknown>) {
  await rpc("registrar_evento_seguranca", {
    p_empresa: empresa ?? null, p_usuario: porUsuario ?? null,
    p_tipo: tipo, p_severidade: "info", p_detalhe: detalhe,
  });
}
// (v56-a) Remove a conta do Auth quando não temos o uid direto (cria pelo e-mail o
// caminho de limpeza): acha o id em public.usuarios e apaga. Best-effort.
async function removerAuthPorEmail(email: string): Promise<boolean> {
  const u = await db(`usuarios?email=eq.${encodeURIComponent(email)}&select=id`);
  const id = Array.isArray(u.data) && u.data[0] ? String((u.data[0] as { id?: string }).id || "") : "";
  if (!id) return false;
  const d = await authAdmin(`admin/users/${id}`, "DELETE");
  return d.ok;
}
// (v56-b) "E-mail já existe": se a conta for ÓRFÃ (sem vínculo em NENHUMA empresa),
// ADOTA (cria vínculo + define senha provisória). Se já for usuário (desta ou de outra
// empresa), NÃO mexe — devolve mensagem clara. Retorna uma Response (json()).
async function adotarOuRecusar(empresa_id: string, callerId: string,
  dados: { nome: string; email: string; perfil: string; senha: string }) {
  const { nome, email, perfil, senha } = dados;
  const u = await db(`usuarios?email=eq.${encodeURIComponent(email)}&select=id`);
  const uid = Array.isArray(u.data) && u.data[0] ? String((u.data[0] as { id?: string }).id || "") : "";
  if (!uid) return json({ erro: "Este e-mail já tem conta no sistema." }, 409);   // sem cadastro localizável -> não adota
  const v = await db(`empresa_usuarios?usuario_id=eq.${uid}&select=empresa_id`);
  const vinc = Array.isArray(v.data) ? (v.data as { empresa_id?: string }[]) : [];
  if (vinc.length > 0) {
    const nesta = vinc.some((r) => r.empresa_id === empresa_id);
    return json({ erro: nesta ? "Este e-mail já é usuário desta empresa." : "Este e-mail já pertence a um usuário de outra empresa." }, 409);
  }
  // ÓRFÃ -> adota: atualiza cadastro, cria o vínculo e (re)define a senha provisória.
  await db(`usuarios?id=eq.${uid}`, "PATCH", { nome, email });
  const vin = await db("empresa_usuarios", "POST", { empresa_id, usuario_id: uid, papel: perfil, ativo: true });
  if (!vin.ok) return json({ erro: "Falha ao vincular o usuário à empresa." }, 502);
  const pw = await authAdmin(`admin/users/${uid}`, "PUT", { password: senha, user_metadata: { nome, senha_provisoria: true } });
  if (!pw.ok) return json({ erro: "Vínculo criado, mas falhou definir a senha provisória." }, 502);
  await auditar(empresa_id, callerId, "usuario_adotado", { email: mascararEmail(email), perfil, troca_obrigatoria: true });
  return json({ ok: true, adotado: true, user_id: uid });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ erro: "método inválido" }, 405);

  try {
    // 1) Identifica o chamador pelo JWT.
    const auth = req.headers.get("Authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    const caller = await getCaller(token);
    if (!caller || !caller.id) return json({ erro: "nao_autenticado" }, 401);

    const body = await req.json().catch(() => ({}));
    const { acao, empresa_id } = body as { acao?: string; empresa_id?: string };
    if (!acao) return json({ erro: "acao_ausente" }, 400);

    // 2) GATE: dono do SaaS OU gestor ATIVO da empresa alvo.
    const owR = await db(`usuarios?id=eq.${caller.id}&select=is_owner`);
    const owner = Array.isArray(owR.data) && owR.data[0]?.is_owner === true;
    let gestor = false;
    if (empresa_id) {
      const vR = await db(`empresa_usuarios?empresa_id=eq.${empresa_id}&usuario_id=eq.${caller.id}&select=papel,ativo`);
      const v = Array.isArray(vR.data) ? vR.data[0] : null;
      gestor = !!v && v.ativo !== false && v.papel === "gestor";
    }
    if (!owner && !gestor) return json({ erro: "sem_permissao" }, 403);

    // ---------------------------------------------------------------- CRIAR
    if (acao === "criar") {
      const nome = String(body.nome || "").trim();
      const email = String(body.email || "").trim().toLowerCase();
      const perfil = String(body.perfil || "");
      const senha = String(body.senha || "");
      if (nome.length < 2) return json({ erro: "Informe o nome completo." }, 400);
      if (!emailValido(email)) return json({ erro: "E-mail inválido." }, 400);
      if (!PAPEIS.includes(perfil)) return json({ erro: "Perfil inválido." }, 400);
      if (senha.length < 8) return json({ erro: "A senha provisória precisa de ao menos 8 caracteres." }, 400);
      if (!empresa_id) return json({ erro: "empresa_ausente" }, 400);

      // Cria a conta no Auth (e-mail já confirmado; marca troca obrigatória).
      const cr = await authAdmin("admin/users", "POST", {
        email, password: senha, email_confirm: true,
        user_metadata: { nome, senha_provisoria: true },
      });
      // (v56-b) E-mail já existe: adota se for órfã; senão, mensagem clara.
      if (!cr.ok) {
        const msg = JSON.stringify(cr.data);
        const existe = /already|registered|exists|duplicate/i.test(msg);
        if (!existe) return json({ erro: "Falha ao criar a conta." }, 502);
        return await adotarOuRecusar(empresa_id, caller.id, { nome, email, perfil, senha });
      }
      // (v56-a) conta criada no Auth, mas sem id utilizável -> tenta remover (sem órfã) e registra.
      const uid = String((cr.data as { id?: string; user?: { id?: string } }).id || (cr.data as { user?: { id?: string } }).user?.id || "");
      if (!uid) {
        const limpou = await removerAuthPorEmail(email);
        if (!limpou) await auditar(empresa_id, caller.id, "orfa_nao_removida", { passo: "sem_uid", email: mascararEmail(email) });
        return json({ erro: "Falha ao criar a conta." }, 502);
      }

      // Cadastro + vínculo. `usuarios` NÃO tem coluna `ativo` (status é empresa_usuarios.ativo).
      // Se QUALQUER passo falhar, apaga a conta do Auth para não deixar órfã; (v56-c) se a
      // própria limpeza falhar, registra em eventos_seguranca (sem silêncio).
      const up = await db("usuarios?on_conflict=id", "POST", { id: uid, nome, email }, "resolution=merge-duplicates");
      if (!up.ok) {
        const d = await authAdmin(`admin/users/${uid}`, "DELETE");
        if (!d.ok) await auditar(empresa_id, caller.id, "orfa_nao_removida", { passo: "usuarios", alvo: uid, email: mascararEmail(email) });
        return json({ erro: "Falha ao cadastrar o usuário." }, 502);
      }
      // INSERT SIMPLES do vínculo. A coluna é `papel`; o VALOR é `perfil` (a variável local).
      // (v55 corrigiu o ReferenceError `papel` -> `papel: perfil`.)
      const vin = await db("empresa_usuarios", "POST", { empresa_id, usuario_id: uid, papel: perfil, ativo: true });
      if (!vin.ok) {
        await db(`usuarios?id=eq.${uid}`, "DELETE");        // desfaz o cadastro recém-criado
        const d = await authAdmin(`admin/users/${uid}`, "DELETE");
        if (!d.ok) await auditar(empresa_id, caller.id, "orfa_nao_removida", { passo: "vinculo", alvo: uid, email: mascararEmail(email) });
        return json({ erro: "Falha ao vincular o usuário à empresa." }, 502);
      }
      await auditar(empresa_id, caller.id, "usuario_criado", { email: mascararEmail(email), perfil, troca_obrigatoria: true });
      return json({ ok: true, user_id: uid });
    }

    // ---------------------------------------------------------------- EDITAR
    if (acao === "editar") {
      const id = String(body.id || "");
      const nome = String(body.nome || "").trim();
      const email = String(body.email || "").trim().toLowerCase();
      const perfil = String(body.perfil || "");
      if (!id) return json({ erro: "id_ausente" }, 400);
      if (nome.length < 2) return json({ erro: "Informe o nome completo." }, 400);
      if (!emailValido(email)) return json({ erro: "E-mail inválido." }, 400);
      if (!PAPEIS.includes(perfil)) return json({ erro: "Perfil inválido." }, 400);
      if (!empresa_id) return json({ erro: "empresa_ausente" }, 400);

      const atualR = await db(`usuarios?id=eq.${id}&select=nome,email`);
      const atual = Array.isArray(atualR.data) ? atualR.data[0] : null;
      if (!atual) return json({ erro: "Usuário não encontrado." }, 404);
      const vinR = await db(`empresa_usuarios?empresa_id=eq.${empresa_id}&usuario_id=eq.${id}&select=papel`);
      const papelAtual = Array.isArray(vinR.data) && vinR.data[0] ? vinR.data[0].papel : null;

      // Não pode alterar o PRÓPRIO perfil.
      if (id === caller.id && papelAtual && perfil !== papelAtual) {
        return json({ erro: "Você não pode alterar o próprio perfil." }, 403);
      }

      const emailMudou = email !== String(atual.email || "").trim().toLowerCase();
      if (emailMudou) {
        const au = await authAdmin(`admin/users/${id}`, "PUT", { email, email_confirm: true });
        if (!au.ok) {
          const existe = /already|registered|exists|duplicate/i.test(JSON.stringify(au.data));
          return json({ erro: existe ? "Este e-mail já tem conta no sistema." : "Falha ao atualizar o e-mail no login." }, existe ? 409 : 502);
        }
      }
      const uu = await db(`usuarios?id=eq.${id}`, "PATCH", { nome, email });
      if (!uu.ok) {
        if (emailMudou) await authAdmin(`admin/users/${id}`, "PUT", { email: atual.email, email_confirm: true });
        return json({ erro: "Falha ao salvar o cadastro." }, 502);
      }
      await db(`empresa_usuarios?empresa_id=eq.${empresa_id}&usuario_id=eq.${id}`, "PATCH", { papel: perfil });
      await auditar(empresa_id, caller.id, "usuario_editado", {
        antes: { nome: atual.nome, email: mascararEmail(atual.email), perfil: papelAtual },
        depois: { nome, email: mascararEmail(email), perfil },
      });
      return json({ ok: true });
    }

    // ------------------------------------------------- SENHA PROVISÓRIA
    if (acao === "senha_provisoria") {
      const id = String(body.id || "");
      const senha = String(body.senha || "");
      if (!id) return json({ erro: "id_ausente" }, 400);
      if (senha.length < 8) return json({ erro: "A senha provisória precisa de ao menos 8 caracteres." }, 400);
      const au = await authAdmin(`admin/users/${id}`, "PUT", { password: senha, user_metadata: { senha_provisoria: true } });
      if (!au.ok) return json({ erro: "Falha ao definir a senha provisória." }, 502);
      await auditar(empresa_id ?? null, caller.id, "senha_provisoria_definida", { alvo: id, troca_obrigatoria: true });
      return json({ ok: true });
    }

    // ------------------------------------------------- ATIVAR / DESATIVAR
    if (acao === "ativar") {
      const id = String(body.id || "");
      const ativo = body.ativo === true;
      if (!id) return json({ erro: "id_ausente" }, 400);
      if (!empresa_id) return json({ erro: "empresa_ausente" }, 400);
      if (id === caller.id && !ativo) return json({ erro: "Você não pode desativar a si mesmo." }, 403);
      const uu = await db(`empresa_usuarios?empresa_id=eq.${empresa_id}&usuario_id=eq.${id}`, "PATCH", { ativo });
      if (!uu.ok) return json({ erro: "Falha ao salvar o status." }, 502);
      await auditar(empresa_id, caller.id, ativo ? "usuario_reativado" : "usuario_desativado", { alvo: id });
      return json({ ok: true });
    }

    // ------------------------------------------------- LINK DE ACESSO
    if (acao === "link_acesso") {
      const id = String(body.id || "");
      if (!id) return json({ erro: "id_ausente" }, 400);
      const uR = await db(`usuarios?id=eq.${id}&select=email`);
      const alvo = Array.isArray(uR.data) ? uR.data[0] : null;
      if (!alvo) return json({ erro: "Usuário não encontrado." }, 404);
      const gl = await authAdmin("admin/generate_link", "POST", { type: "recovery", email: alvo.email });
      if (!gl.ok) return json({ erro: "Falha ao gerar o link de acesso." }, 502);
      const link = String((gl.data as { action_link?: string }).action_link || "");
      await auditar(empresa_id ?? null, caller.id, "link_acesso_gerado", { alvo: id });
      return json({ ok: true, link });
    }

    return json({ erro: "acao_desconhecida" }, 400);
  } catch (e) {
    console.error(e);
    return json({ erro: "erro ao processar" }, 500);
  }
});
