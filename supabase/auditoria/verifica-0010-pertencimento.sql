-- Auditoria (SOMENTE LEITURA) — teste de PERTENCIMENTO da RPC.
-- Executado pelo workflow SEM JWT (auth.uid() = null): usuario_e_owner()=false e
-- meu_papel(<empresa alheia>)=null -> a guarda DEVE levantar 'sem acesso a esta empresa'.
-- Ou seja: espera-se ERRO aqui (prova de que empresa_id arbitrário é rejeitado).
select * from public.checar_duplicata_documento(
  '00000000-0000-0000-0000-000000000000'::uuid, '11.222.333/0001-81', '123', null, null);
