-- Auditoria (SOMENTE LEITURA) — os campos extraídos pela IA estão sendo gravados?
-- Conta linhas de lancamentos com cada coluna de extração preenchida. Não altera nada.
select json_build_object(
  'total',              count(*),
  'nao_excluidos',      count(*) filter (where deleted_at is null),
  'com_cnpj_estab',     count(*) filter (where coalesce(cnpj_estabelecimento,'') <> ''),
  'com_data_extraida',  count(data_extraida),
  'com_valor_extraido', count(valor_extraido),
  'com_ia_json',        count(ia_json_bruto),
  'ia_lido_true',       count(*) filter (where ia_lido is true),
  'com_estab_nome',     count(*) filter (where coalesce(estabelecimento_nome,'') <> ''),
  'com_numero_nota_form', count(*) filter (where coalesce(numero_nota,'') <> ''),
  'com_cnpj_form',      count(*) filter (where coalesce(cnpj,'') <> '')
) as extraidos
from public.lancamentos;
