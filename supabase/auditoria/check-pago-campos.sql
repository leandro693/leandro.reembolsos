-- READ-ONLY: distribuicao de deleted_at + pagos e amostra (sem filtro de deleted_at).
select json_build_object(
  'total', (select count(*) from public.lancamentos),
  'del_null', (select count(*) from public.lancamentos where deleted_at is null),
  'del_notnull', (select count(*) from public.lancamentos where deleted_at is not null),
  'pagos', (select json_agg(row_to_json(p)) from (
     select status, situacao, data_pagamento, (deleted_at is null) as ativo, parcela_num, parcela_total, (id_compra is not null) as e_parcela
     from public.lancamentos where status='pago' limit 5) p),
  'amostra_recentes', (select json_agg(row_to_json(a)) from (
     select status, situacao, data_pagamento, (deleted_at is null) as ativo
     from public.lancamentos order by criado_em desc limit 6) a)
) as r;
