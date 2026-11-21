-- ============================================================================
-- Estende a FK de veículo pra agendamentos (mesmo motivo do 0007: permitir
-- relatório/consulta por veículo sem LIKE em texto livre).
--
-- Diferença do orcamentos: criar_agendamento recebe o veículo como texto
-- solto do agente de IA (via $fromAI), sem nenhuma consulta que resolva um
-- id antes. A solução é aceitar um p_orcamento_id opcional (o agente já tem
-- esse id em mãos, devolvido por registrar_orcamento/registrar_orcamento_motor
-- na mesma conversa) e copiar o veiculo_id/veiculo_motor_id de lá.
--
-- O parâmetro é adicionado no FINAL da assinatura, com default null -- uma
-- chamada antiga com 5 argumentos posicionais continua funcionando sem
-- mudar nada no n8n; só passa a preencher a FK quando o workflow for
-- atualizado pra enviar o orcamento_id.
-- ============================================================================

alter table agendamentos add column if not exists veiculo_id uuid references veiculos (id) on delete set null;
alter table agendamentos add column if not exists veiculo_motor_id uuid references veiculos_motor (id) on delete set null;
alter table agendamentos add column if not exists orcamento_id uuid references orcamentos (id) on delete set null;

create index if not exists idx_agendamentos_veiculo_id on agendamentos (veiculo_id);
create index if not exists idx_agendamentos_veiculo_motor_id on agendamentos (veiculo_motor_id);

drop function if exists criar_agendamento(text, text, text, text, text);
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

  return query select 'ok'::text, v_id, to_char(v_inicio, 'DD/MM/YYYY HH24:MI'), to_char(v_fim, 'DD/MM/YYYY HH24:MI');
end;
$$;
