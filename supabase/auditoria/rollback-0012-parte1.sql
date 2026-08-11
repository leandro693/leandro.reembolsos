-- ROLLBACK da 0012 (Parte 1) — reverte comp_select para a regra original (só o próprio
-- uploader) e remove o helper. Só policy, sem tocar dados. Reverte 100% a Parte 1.
-- (comp_pag_select NÃO foi alterada pela Parte 1, então não é tocada aqui.)
drop policy if exists comp_select on storage.objects;
create policy comp_select on storage.objects for select to authenticated
  using (bucket_id = 'comprovantes' and (storage.foldername(name))[1] = (auth.uid())::text);
drop function if exists public.pode_ver_comprovante(text);
select 'rollback 0012 parte 1 ok (comp_select voltou ao original)' as status;
