// ============================================================================
// Edge Function: importar-erp  (SaaS — integração com sistemas de gestão)
// Busca as categorias no ERP do cliente (Omie hoje; estrutura pronta para
// outros ERPs) e as importa para a empresa. As credenciais do ERP ficam
// no servidor (tabela integracoes_erp, lida com service role); o app nunca
// as recebe de volta.
//
// Fluxo:
//  - valida empresa/provedor e se a integração está ATIVA e com credenciais;
//  - chama a API do ERP (paginada);
//  - casa cada categoria por codigo_externo e, se não achar, por nome;
//  - cria as novas e grava o código do ERP nas existentes;
//  - registra a data da última sincronização.
// ============================================================================

const SUPA_URL    = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// ---- Helpers REST (service role) -------------------------------------------
async function restGet(path: string) {
  const r = await fetch(`${SUPA_URL}/rest/v1/${path}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  if (!r.ok) return null;
  return await r.json().catch(() => null);
}
async function restSend(method: string, path: string, body: unknown, prefer = "") {
  const r = await fetch(`${SUPA_URL}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(prefer ? { Prefer: prefer } : {}),
    },
    body: JSON.stringify(body),
  });
  return r.ok;
}

// normaliza nome para casar categorias (sem acento, minúsculo, sem espaços extra)
const norm = (s: string) =>
  (s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, " ").trim();

// ---- Provedor: Omie --------------------------------------------------------
// Lista as categorias (plano de contas gerencial) do Omie, paginado.
async function omieCategorias(appKey: string, appSecret: string) {
  const out: Array<{ codigo: string; descricao: string; inativa: boolean; totalizadora: boolean }> = [];
  let pagina = 1, totalPaginas = 1;
  do {
    const resp = await fetch("https://app.omie.com.br/api/v1/geral/categorias/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        call: "ListarCategorias",
        app_key: appKey, app_secret: appSecret,
        param: [{ pagina, registros_por_pagina: 100 }],
      }),
    });
    const data = await resp.json().catch(() => null);
    if (!resp.ok || !data) {
      const msg = (data && (data.faultstring || data.faultString)) || `HTTP ${resp.status}`;
      throw new Error(String(msg));
    }
    totalPaginas = Number(data.total_de_paginas || 1);
    const arr = Array.isArray(data.categoria_cadastro) ? data.categoria_cadastro : [];
    for (const c of arr) {
      const codigo = String(c.codigo ?? c.codigo_categoria ?? "").trim();
      const descricao = String(c.descricao ?? c.descricao_padrao ?? "").trim();
      if (!descricao) continue;
      out.push({
        codigo,
        descricao,
        inativa: String(c.conta_inativa ?? "N").toUpperCase() === "S",
        totalizadora: String(c.totalizadora ?? "N").toUpperCase() === "S",
      });
    }
    pagina++;
  } while (pagina <= totalPaginas && pagina <= 50); // teto de segurança
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ erro: "Método não suportado" }, 405);
  if (!SUPA_URL || !SERVICE_KEY) return json({ erro: "Servidor sem configuração" }, 500);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { return json({ erro: "Corpo inválido" }, 400); }

  const empresaId = String(body.empresa_id ?? "");
  const provedor  = String(body.provedor ?? "omie").toLowerCase();
  if (!empresaId) return json({ erro: "Empresa não informada" }, 400);
  if (provedor !== "omie") return json({ erro: "ERP ainda não suportado" }, 400);

  // 1) Credenciais da integração (só o servidor lê o segredo).
  const cfgArr = await restGet(
    `integracoes_erp?empresa_id=eq.${empresaId}&provedor=eq.${provedor}&select=app_key,app_secret,ativo&limit=1`,
  );
  const cfg = Array.isArray(cfgArr) ? cfgArr[0] : null;
  if (!cfg) return json({ erro: "Integração não configurada" }, 400);
  if (!cfg.ativo) return json({ erro: "Integração desativada" }, 400);
  if (!cfg.app_key || !cfg.app_secret) return json({ erro: "Credenciais incompletas" }, 400);

  // 2) Busca no ERP.
  let cats;
  try {
    cats = await omieCategorias(String(cfg.app_key), String(cfg.app_secret));
  } catch (e) {
    return json({ erro: "ERP recusou: " + (e instanceof Error ? e.message : "erro") }, 400);
  }
  // Ignora totalizadoras (não são categorias de despesa lançáveis).
  cats = cats.filter((c) => !c.totalizadora);

  // 3) Categorias atuais da empresa (para casar por código ou nome).
  const atuais: Array<{ id: string; nome: string; codigo_externo: string | null }> =
    (await restGet(`categorias?empresa_id=eq.${empresaId}&select=id,nome,codigo_externo`)) || [];
  const porCodigo = new Map<string, string>();
  const porNome = new Map<string, string>();
  for (const a of atuais) {
    if (a.codigo_externo) porCodigo.set(a.codigo_externo, a.id);
    porNome.set(norm(a.nome), a.id);
  }

  let criadas = 0, atualizadas = 0;
  const novas: Array<Record<string, unknown>> = [];
  for (const c of cats) {
    const id = (c.codigo && porCodigo.get(c.codigo)) || porNome.get(norm(c.descricao));
    if (id) {
      // Já existe: garante o código do ERP gravado.
      if (c.codigo) {
        const ok = await restSend("PATCH", `categorias?id=eq.${id}`, { codigo_externo: c.codigo });
        if (ok) atualizadas++;
      }
    } else {
      novas.push({
        empresa_id: empresaId, nome: c.descricao, tipo_calculo: "valor",
        ativo: !c.inativa, codigo_externo: c.codigo || "",
      });
    }
  }
  if (novas.length) {
    const ok = await restSend("POST", "categorias", novas, "return=minimal");
    if (ok) criadas = novas.length;
  }

  // 4) Marca a última sincronização.
  await restSend("PATCH", `integracoes_erp?empresa_id=eq.${empresaId}&provedor=eq.${provedor}`,
    { ultima_sync: new Date().toISOString() });

  return json({ ok: true, criadas, atualizadas, total_erp: cats.length });
});
