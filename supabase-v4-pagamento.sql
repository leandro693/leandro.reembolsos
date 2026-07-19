-- ============================================================================
-- REEMBOLSOS MARADEL - v4: comprovante de PAGAMENTO na baixa.
-- Guarda a prova de que o reembolso foi pago (PIX/transferência), anexada ao
-- marcar lançamentos como recebidos. Um mesmo pagamento pode cobrir vários
-- lançamentos (que somam o valor pago), inclusive de pessoas diferentes.
-- Rode UMA VEZ no SQL Editor (ou pelo workflow). É idempotente.
-- ============================================================================

-- Coluna que guarda o caminho do arquivo do comprovante de pagamento.
alter table public.lancamentos
  add column if not exists comprovante_pagamento text default '';

-- Os comprovantes de pagamento ficam numa pasta compartilhada ("pagamentos/")
-- do bucket privado, legível por qualquer usuário autenticado da equipe (o
-- caminho é um UUID e só aparece através dos lançamentos que a pessoa pode ver).
drop policy if exists comp_pag_insert on storage.objects;
drop policy if exists comp_pag_select on storage.objects;
create policy comp_pag_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'pagamentos');
create policy comp_pag_select on storage.objects for select to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = 'pagamentos');
