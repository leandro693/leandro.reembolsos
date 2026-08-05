-- READ-ONLY: exemplos concretos (pago vs a receber) + cruzamento status x situacao x data_pagamento.
select json_build_object(
  'exemplos_pagos', (select json_agg(row_to_json(p)) from (
     select status, situacao, data_pagamento, parcela_num, parcela_total, (id_compra is not null) as e_parcela
     from public.lancamentos where status='pago' and deleted_at is null
     order by data_pagamento desc nulls last limit 5) p),
  'exemplos_a_receber', (select json_agg(row_to_json(a)) from (
     select status, situacao, data_pagamento, parcela_num, parcela_total, (id_compra is not null) as e_parcela
     from public.lancamentos where status<>'pago' and deleted_at is null
     order by criado_em desc limit 5) a),
  'cruzamento', (select json_agg(row_to_json(c)) from (
     select status, situacao, (data_pagamento is not null) as tem_data_pag, count(*) as qtd
     from public.lancamentos where deleted_at is null
     group by status, situacao, (data_pagamento is not null)
     order by status, situacao, 3) c)
) as r;
