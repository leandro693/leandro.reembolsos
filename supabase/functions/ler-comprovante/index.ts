// ============================================================================
// Edge Function: ler-comprovante
// Recebe a imagem/PDF de um comprovante, pede ao Google Gemini para extrair os
// dados e devolve JSON pronto para preencher o formulário do app.
//
// A chave do Gemini fica em segredo aqui no servidor (nunca no aplicativo).
// Deploy e configuração: ver README (seção "IA que lê o comprovante").
// ============================================================================

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODELO = "gemini-2.5-flash";

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

const PROMPT = `Você é um leitor de comprovantes de despesa brasileiros: nota fiscal, cupom,
recibo, fatura e contas de consumo (energia, água, telefone, internet).

REGRA MAIS IMPORTANTE: baseie-se APENAS no que está escrito no documento enviado.
NUNCA invente, adivinhe ou use exemplos. Se você não consegue ler o documento, ou se
ele não é um comprovante, responda com "legivel": false e todos os outros campos vazios.

Campos:
- "legivel": true somente se você realmente leu um comprovante neste documento; senão false.
- "fornecedor": nome exato da empresa/estabelecimento EMISSORA que aparece no documento.
- "valor": o valor TOTAL a pagar do documento, número com ponto decimal (ex.: 319.57). Sem "R$".
- "data_emissao": data de emissão no formato AAAA-MM-DD. Se não aparecer, deixe "".
- "categoria": escolha EXATAMENTE uma desta lista, a que melhor descreve o gasto:
${CATEGORIAS.map((c) => "  - " + c).join("\n")}
  Conta de luz, água, telefone, internet ou aluguel, quando não houver item específico, use "Outros".
- "observacoes": resumo curto do que é a despesa, baseado no documento (ex.: "Conta de energia MAI/2026").

Responda somente com o JSON pedido, sem texto extra.`;

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
                legivel: { type: "BOOLEAN" },
                fornecedor: { type: "STRING" },
                valor: { type: "NUMBER" },
                data_emissao: { type: "STRING" },
                categoria: { type: "STRING" },
                observacoes: { type: "STRING" },
              },
              required: ["legivel"],
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
    console.log("Gemini retornou:", texto.slice(0, 600)); // diagnóstico (aparece em Logs)
    let out: Record<string, unknown> = {};
    try { out = JSON.parse(texto); } catch { out = {}; }

    // valida a categoria só quando o documento foi lido
    if (out.legivel) {
      if (typeof out.categoria !== "string" || !CATEGORIAS.includes(out.categoria)) {
        out.categoria = "Outros";
      }
    }
    return json(out);
  } catch (e) {
    console.error(e);
    return json({ erro: "erro ao processar" }, 500);
  }
});
