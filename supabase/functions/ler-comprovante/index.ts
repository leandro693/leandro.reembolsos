// ============================================================================
// Edge Function: ler-comprovante
// Recebe a imagem/PDF de um comprovante, pede ao Google Gemini para extrair os
// dados e devolve JSON pronto para preencher o formulário do app.
//
// A chave do Gemini fica em segredo aqui no servidor (nunca no aplicativo).
// Deploy e configuração: ver README (seção "IA que lê o comprovante").
// ============================================================================

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODELO = "gemini-2.0-flash";

// Categorias válidas (iguais às do app). A IA deve escolher exatamente uma.
const CATEGORIAS = [
  "Quilometragem", "Pedágios", "Refeições", "Material de Copa e Cozinha",
  "Software/Licença de Uso", "Construção de imóvel", "Confraternização e Aniversário",
  "Junta Comercial e Outras Taxas - Societário", "Educação / Capacitação",
  "Material de Escritório", "Material de Limpeza", "Equipamentos de Informática",
  "Correios / Consultas de clientes", "Despesas de Frete / Motoboy", "Patrocínios", "Outros",
];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const PROMPT = `Você recebe a imagem (ou PDF) de um comprovante de despesa brasileiro
(nota fiscal, cupom, recibo, fatura). Extraia os dados para reembolso.

Regras:
- "categoria": escolha EXATAMENTE uma desta lista, a que melhor descreve o gasto:
${CATEGORIAS.map((c) => "  - " + c).join("\n")}
  Se não tiver certeza, use "Outros".
- "fornecedor": nome do estabelecimento/empresa emissora.
- "valor": valor TOTAL pago, como número com ponto decimal (ex.: 84.50). Sem "R$".
- "data_emissao": data de emissão no formato AAAA-MM-DD. Se não achar, deixe "".
- "observacoes": um resumo curto do que foi comprado (opcional).
Responda somente com o JSON pedido.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ erro: "método inválido" }, 405);
  if (!GEMINI_KEY) return json({ erro: "GEMINI_API_KEY não configurada" }, 500);

  try {
    const { imageBase64, mimeType } = await req.json();
    if (!imageBase64) return json({ erro: "imagem ausente" }, 400);

    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent?key=${GEMINI_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: mimeType || "image/jpeg", data: imageBase64 } },
            ],
          }],
          generationConfig: {
            temperature: 0,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              properties: {
                categoria: { type: "STRING" },
                fornecedor: { type: "STRING" },
                valor: { type: "NUMBER" },
                data_emissao: { type: "STRING" },
                observacoes: { type: "STRING" },
              },
              required: ["categoria", "fornecedor", "valor"],
            },
          },
        }),
      },
    );

    if (!resp.ok) {
      const t = await resp.text();
      console.error("Gemini erro:", resp.status, t);
      return json({ erro: "falha na IA (" + resp.status + ")" }, 502);
    }

    const data = await resp.json();
    const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    let out: Record<string, unknown> = {};
    try { out = JSON.parse(texto); } catch { out = {}; }

    // valida a categoria devolvida
    if (typeof out.categoria !== "string" || !CATEGORIAS.includes(out.categoria)) {
      out.categoria = "Outros";
    }
    return json(out);
  } catch (e) {
    console.error(e);
    return json({ erro: "erro ao processar" }, 500);
  }
});
