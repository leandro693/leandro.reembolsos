-- READ-ONLY probe: papel usado pela Management API e se a RLS bloqueia o SELECT.
select json_build_object(
  'current_user', current_user,
  'session_user', session_user,
  'lanc_relrowsecurity', (select relrowsecurity from pg_class where oid='public.lancamentos'::regclass),
  'lanc_relforcerowsecurity', (select relforcerowsecurity from pg_class where oid='public.lancamentos'::regclass),
  'lanc_owner', (select pg_get_userbyid(relowner) from pg_class where oid='public.lancamentos'::regclass),
  'lanc_total', (select count(*) from public.lancamentos),
  'pago_status', (select count(*) from public.lancamentos where status='pago'),
  'com_data_pag', (select count(*) from public.lancamentos where data_pagamento is not null),
  'situacao_pago', (select count(*) from public.lancamentos where situacao='pago')
) as probe;
