-- ============================================================================
-- 0003 — Auditoria automática de lançamentos (trigger).
-- Registra criar/editar/marcar_pago/estornar/excluir em eventos_auditoria,
-- com dados_antes/dados_depois. Idempotente.
-- ============================================================================

create or replace function public.fn_auditar_lancamento()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_acao text;
begin
  if TG_OP = 'INSERT' then
    v_acao := 'criou';
  else
    if new.deleted_at is not null and old.deleted_at is null then v_acao := 'excluiu';
    elsif new.status = 'pago' and coalesce(old.status,'') <> 'pago' then v_acao := 'marcou_pago';
    elsif new.status <> 'pago' and old.status = 'pago' then v_acao := 'estornou';
    else v_acao := 'editou';
    end if;
  end if;

  insert into public.eventos_auditoria
    (empresa_id, usuario_id, entidade, entidade_id, acao, dados_antes, dados_depois)
  values
    (coalesce(new.empresa_id, old.empresa_id), auth.uid(), 'lancamento',
     coalesce(new.id, old.id), v_acao,
     case when TG_OP = 'INSERT' then null else to_jsonb(old) end,
     to_jsonb(new));
  return null;
end;
$$;

drop trigger if exists trg_auditar_lancamento on public.lancamentos;
create trigger trg_auditar_lancamento
  after insert or update on public.lancamentos
  for each row execute function public.fn_auditar_lancamento();

select 'auditoria ok' as status;
