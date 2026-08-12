select json_agg(row_to_json(t) order by t.criado_em) as dump
from (select * from public.empresa_usuarios) t;
