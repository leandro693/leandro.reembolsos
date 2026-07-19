-- ============================================================================
-- 0002 — Metering de IA + registro de segurança (funções usadas pela Edge Function).
-- Idempotente.
-- ============================================================================

-- Ainda há cota de leitura por IA neste mês para a empresa?
create or replace function public.tem_cota_ia(p_empresa uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(
    (select cm.leituras_consumidas from public.consumo_mensal cm
      where cm.empresa_id = p_empresa and cm.ano_mes = to_char(now(),'YYYY-MM')), 0
  ) < coalesce(
    (select p.cota_leituras_mensal from public.empresas e
       join public.planos p on p.id = e.plano_id where e.id = p_empresa), 999999
  );
$$;

-- Consumo/cota atual (para o painel).
create or replace function public.consumo_ia(p_empresa uuid)
returns table(consumidas int, cota int) language sql stable security definer set search_path=public as $$
  select coalesce((select leituras_consumidas from public.consumo_mensal
                    where empresa_id=p_empresa and ano_mes=to_char(now(),'YYYY-MM')),0),
         coalesce((select p.cota_leituras_mensal from public.empresas e
                    join public.planos p on p.id=e.plano_id where e.id=p_empresa),0);
$$;

-- Registra 1 leitura de IA (log + incremento do contador do mês).
create or replace function public.registrar_leitura_ia(
  p_empresa uuid, p_usuario uuid, p_modelo text, p_ok boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_empresa is null then return; end if;
  insert into public.uso_ia(empresa_id, usuario_id, modelo, sucesso)
    values (p_empresa, p_usuario, coalesce(p_modelo,''), coalesce(p_ok,true));
  if coalesce(p_ok,true) then
    insert into public.consumo_mensal(empresa_id, ano_mes, leituras_consumidas)
      values (p_empresa, to_char(now(),'YYYY-MM'), 1)
    on conflict (empresa_id, ano_mes)
      do update set leituras_consumidas = consumo_mensal.leituras_consumidas + 1;
  end if;
end;
$$;

-- Registra um evento de segurança (quarentena de injeção etc.).
create or replace function public.registrar_evento_seguranca(
  p_empresa uuid, p_usuario uuid, p_tipo text, p_severidade text, p_detalhe jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.eventos_seguranca(empresa_id, usuario_id, tipo, severidade, detalhe, status)
    values (p_empresa, p_usuario, p_tipo, coalesce(p_severidade,'media'), coalesce(p_detalhe,'{}'::jsonb), 'quarentena');
end;
$$;

-- Registra um alerta (duplicata/limite).
create or replace function public.registrar_alerta(
  p_empresa uuid, p_lancamento uuid, p_tipo text, p_detalhe jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.alertas(empresa_id, lancamento_id, tipo, detalhe)
    values (p_empresa, p_lancamento, p_tipo, coalesce(p_detalhe,'{}'::jsonb));
end;
$$;

select 'metering + seguranca ok' as status;
