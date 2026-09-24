-- ============================================================================
-- Corrige a segunda pendência de normalização: orcamentos.veiculo guardava só
-- um texto concatenado (modelo || montadora || ano), sem nenhuma referência
-- de volta pro catálogo. Não dava pra consultar "todos os orçamentos do Gol
-- VI" sem LIKE em texto livre.
--
-- Adiciona veiculo_id (câmbio) e veiculo_motor_id (motor) como FK opcional,
-- preenchidas pelas próprias funções de registro -- que já resolvem o id
-- exato da linha antes de gravar o orçamento, então isso não muda nada no
-- lado do n8n (mesma assinatura de função, mesmas colunas retornadas).
--
-- agendamentos.veiculo fica de fora por ora: criar_agendamento recebe o
-- veículo como texto livre do agente de IA (via $fromAI), sem passar por
-- nenhuma consulta que resolva um id -- ligar isso a uma FK exigiria mudar
-- a chamada da tool no workflow do n8n, não só a função SQL.
-- ============================================================================

alter table orcamentos add column if not exists veiculo_id uuid references veiculos (id) on delete set null;
alter table orcamentos add column if not exists veiculo_motor_id uuid references veiculos_motor (id) on delete set null;

create index if not exists idx_orcamentos_veiculo_id on orcamentos (veiculo_id);
create index if not exists idx_orcamentos_veiculo_motor_id on orcamentos (veiculo_motor_id);

-- registrar_orcamento (câmbio): passa a resolver e gravar o id do veículo.
create or replace function registrar_orcamento(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, orcamento_id uuid, veiculo text, valor_total numeric)
language plpgsql
as $$
declare
  v_veiculo text;
  v_veiculo_id uuid;
  v_valor numeric;
  v_count int;
  v_orcamento_id uuid;
  v_motor text;
  v_ano int;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select count(*) into v_count from veiculos v
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::uuid, null::text, null::numeric;
    return;
  elsif v_count > 1 then
    return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select v.id, v.modelo || ' ' || v.montadora || ' ' || v.ano::text,
    (v.litros_oleo_cambio + coalesce(v.litros_oleo_limpeza, 0)) * p.preco_litro
      + coalesce(f_ext.preco, 0) + coalesce(f_int.preco, 0) + s.preco_mao_obra
  into v_veiculo_id, v_veiculo, v_valor
  from veiculos v
  join produtos p on p.id = v.produto_oleo_id
  join servicos s on s.id = v.servico_id
  left join filtros f_ext on f_ext.id = v.filtro_externo_id
  left join filtros f_int on f_int.id = v.filtro_interno_id
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));

  insert into orcamentos (session_id, veiculo, veiculo_id, valor_total, status)
  values (p_session_id, v_veiculo, v_veiculo_id, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select 'ok'::text, v_orcamento_id, v_veiculo, v_valor;
end;
$$;

-- registrar_orcamento_motor: já resolve v_id_escolhido internamente (migration
-- 0005) -- só precisa gravar esse id também.
create or replace function registrar_orcamento_motor(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, orcamento_id uuid, veiculo text, valor_total numeric)
language plpgsql
as $$
declare
  v_veiculo text;
  v_valor numeric;
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_orcamento_id uuid;
  v_motor text;
  v_ano int;
  v_id_escolhido uuid;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select count(*), count(distinct lower(coalesce(v.motor_descricao, ''))),
    min(v.litros_oleo_motor), max(v.litros_oleo_motor)
  into v_count, v_motores_distintos, v_litros_min, v_litros_max
  from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select v.id into v_id_escolhido
  from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
  order by v.ano_fim desc, v.litros_oleo_motor desc
  limit 1;

  select v.modelo || ' ' || v.montadora,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  into v_veiculo, v_valor
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where v.id = v_id_escolhido;

  insert into orcamentos (session_id, veiculo, veiculo_motor_id, valor_total, status)
  values (p_session_id, v_veiculo, v_id_escolhido, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select 'ok'::text, v_orcamento_id, v_veiculo, v_valor;
end;
$$;
