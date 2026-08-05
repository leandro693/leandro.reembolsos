-- READ-ONLY: qual campo marca REALMENTE pagamento/recebimento?
-- Cruza status x situacao x (data_pagamento preenchida), no geral e nas parceladas.
-- Se status='pago' <=> data_pagamento not null <=> situacao='pago' de forma consistente,
-- entao a fonte da verdade e status (situacao e derivada) e estaPago deve olhar status/data_pagamento.
select escopo, status, situacao, (data_pagamento is not null) as tem_data_pag, count(*) as qtd
from (
  select 'todos'::text as escopo, status, situacao, data_pagamento
    from public.lancamentos where deleted_at is null
  union all
  select 'parceladas'::text, status, situacao, data_pagamento
    from public.lancamentos where deleted_at is null and parcela_total is not null
) t
group by escopo, status, situacao, tem_data_pag
order by escopo, status, situacao, tem_data_pag;
