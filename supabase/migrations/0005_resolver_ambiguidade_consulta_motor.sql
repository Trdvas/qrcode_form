-- ============================================================================
-- Aplica a mesma tolerância de litragem (300ml) na CONSULTA de orçamento de
-- motor, não só no cadastro. A busca por aproximação (LIKE) pode trazer mais
-- de um candidato; antes disso sempre virava "ambíguo". Agora só continua
-- "ambíguo" quando os candidatos têm motorização (motor_descricao)
-- diferente, ou litragem além de 300ml — caso contrário, resolve sozinho
-- escolhendo o cadastro mais atual (maior ano_fim), igual ao trigger de
-- cadastro (migration 0004).
-- ============================================================================

create or replace function consultar_orcamento_motor(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, viscosidade text, valor_oleo numeric, valor_filtro numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_motor text;
  v_ano int;
  v_id_escolhido uuid;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
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
    return query select 'nao_encontrado'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    -- motorizações diferentes, ou litragem além da tolerância: ambiguidade real.
    return query select 'ambiguo'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  -- um único candidato, ou vários que só diferem em até 300ml de litragem
  -- na mesma motorização: escolhe o mais atual (maior ano_fim).
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

  return query
  select 'ok'::text,
    v.modelo || ' ' || v.montadora,
    v.viscosidade_recomendada,
    ceil(v.litros_oleo_motor) * p.preco_litro,
    coalesce(f.preco, 0),
    s.preco_mao_obra,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where v.id = v_id_escolhido;
end;
$$;

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

  insert into orcamentos (session_id, veiculo, valor_total, status)
  values (p_session_id, v_veiculo, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select 'ok'::text, v_orcamento_id, v_veiculo, v_valor;
end;
$$;
