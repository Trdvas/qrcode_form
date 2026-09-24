-- ============================================================================
-- criar_agendamento passa a marcar o orçamento de origem (quando informado)
-- como 'convertido_em_agendamento' após criar o agendamento com sucesso.
-- ============================================================================

create or replace function criar_agendamento(p_session_id text, p_veiculo text, p_data text, p_hora_inicio text, p_duracao_horas text default '4', p_orcamento_id text default null)
returns table(status text, agendamento_id uuid, inicio text, fim text)
language plpgsql
as $$
declare
  v_inicio timestamptz;
  v_fim timestamptz;
  v_id uuid;
  v_duracao numeric;
  v_orcamento_id uuid;
  v_veiculo_id uuid;
  v_veiculo_motor_id uuid;
begin
  v_duracao := coalesce(nullif(regexp_replace(coalesce(p_duracao_horas, ''), '[^0-9.]', '', 'g'), ''), '4')::numeric;
  v_inicio := (nullif(trim(p_data), '') || ' ' || nullif(trim(p_hora_inicio), ''))::timestamptz;
  if v_inicio is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::text;
    return;
  end if;
  v_fim := v_inicio + (v_duracao || ' hours')::interval;

  -- Trava: não permite serviço passar das 16h nem começar antes das 8h
  if (v_inicio::time < time '08:00') or (v_fim::time > time '16:00') then
    return query select 'fora_do_horario'::text, null::uuid, null::text, null::text;
    return;
  end if;

  v_orcamento_id := nullif(trim(p_orcamento_id), '')::uuid;
  if v_orcamento_id is not null then
    select o.veiculo_id, o.veiculo_motor_id into v_veiculo_id, v_veiculo_motor_id
    from orcamentos o
    where o.id = v_orcamento_id;
  end if;

  begin
    insert into agendamentos (session_id, veiculo, veiculo_id, veiculo_motor_id, orcamento_id, data_hora_inicio, data_hora_fim, status)
    values (p_session_id, p_veiculo, v_veiculo_id, v_veiculo_motor_id, v_orcamento_id, v_inicio, v_fim, 'confirmado')
    returning id into v_id;
  exception when exclusion_violation then
    return query select 'conflito'::text, null::uuid, null::text, null::text;
    return;
  end;

  if v_orcamento_id is not null then
    update orcamentos set status = 'convertido_em_agendamento' where id = v_orcamento_id;
  end if;

  return query select 'ok'::text, v_id, to_char(v_inicio, 'DD/MM/YYYY HH24:MI'), to_char(v_fim, 'DD/MM/YYYY HH24:MI');
end;
$$;
