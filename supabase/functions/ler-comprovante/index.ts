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

REGRA 1: baseie-se APENAS no que está escrito no documento enviado. NUNCA invente,
adivinhe ou use exemplos. Se um campo não estiver visível, deixe vazio (0 no valor).

REGRA 2: seja BEM FLEXÍVEL. Vale QUALQUER papel que mostre uma despesa com um valor,
mesmo informal: nota fiscal, cupom fiscal, cupom de conferência, comanda, pré-conta,
recibo, fatura, boleto, ticket, papel de padaria, contas de consumo (energia, água,
telefone, internet) E TAMBÉM comprovantes de pagamento de maquininha de cartão
(PagBank, PagSeguro, Cielo, Rede, Stone, SumUp, GetNet, Mercado Pago): esses mostram
"COMPRA CRÉDITO/DÉBITO", valor, data e o nome/CPF do recebedor. Para TODOS esses,
"legivel": true.
Use "legivel": false SOMENTE quando a imagem estiver ilegível, em branco, muito cortada,
ou claramente não for um documento de despesa (ex.: uma paisagem, uma selfie).
NUNCA escreva que o documento é "para simples conferência" ou coisa parecida.

Campos:
- "legivel": true se dá para ler uma despesa (ver Regra 2); senão false.
- "fornecedor": nome da empresa/estabelecimento ou da PESSOA que recebeu o pagamento
  (em recibo de maquininha, é o nome do vendedor, ex.: "Arlete Henrique Alves").
- "valor": o valor TOTAL do documento (o "TOTAL" ou o valor da compra, já com taxa de
  serviço se houver), número com ponto decimal (ex.: 65.00). Sem "R$".
- "data_emissao": data no formato AAAA-MM-DD. Aceite formatos como "18/JUL/2026" e converta.
- "numero_nota": número da nota, cupom, recibo ou da autorização/CV da maquininha. Se não houver, "".
- "cnpj": documento do emitente/vendedor. Pode ser CNPJ (00.000.000/0000-00) OU CPF
  (000.000.000-00), o que aparecer no comprovante. Se não houver, "".
- "categoria": escolha EXATAMENTE uma desta lista, a que melhor descreve o gasto:
${CATEGORIAS.map((c) => "  - " + c).join("\n")}
  Conta de luz, água, telefone, internet ou aluguel, quando não houver item específico, use "Outros".
- "observacoes": resumo ÚTIL do que foi a despesa para a empresa, curto. PRIORIZE os
  principais itens/produtos comprados que aparecem no documento
  (ex.: "Café, açúcar e copos descartáveis"; "Almoço: 2 pratos e refrigerante";
  "Conta de energia, competência MAI/2026"). Pode incluir mês de referência/competência.
  NUNCA inclua dados de pagamento ou de máquina de cartão: PDV, OPR, número do caixa,
  tipo/bandeira de cartão, número de autorização, NSU, código de transação ou operador.
  Não repita aqui o valor total, a categoria, o número da nota nem o CNPJ.

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
                numero_nota: { type: "STRING" },
                cnpj: { type: "STRING" },
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
