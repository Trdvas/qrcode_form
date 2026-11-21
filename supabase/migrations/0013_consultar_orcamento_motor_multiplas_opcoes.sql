-- ============================================================================
-- Corrige dois problemas de comportamento do agente de IA, ambos com a mesma
-- causa raiz: consultar_orcamento_motor sempre escolhia UMA linha de
-- veiculos_motor arbitrariamente (a de maior ano_fim/litros) e devolvia só o
-- preço e a viscosidade dela -- nunca a marca/especificação do óleo, nem as
-- outras opções cadastradas pro mesmo motor (lembrar: cadastramos até 5-7
-- opções de óleo por motor, em faixas de preço diferentes).
--
-- Resultado: o agente não sabia responder "qual é a marca e a quantidade de
-- óleo", e não tinha como oferecer/aceitar uma viscosidade diferente da que
-- calhou de ser escolhida arbitrariamente -- porque a existência das outras
-- opções nunca chegava até ele.
--
-- Agora a função retorna, pra motor identificado sem ambiguidade real
-- (mesma motorização, litragem dentro da tolerância de 300ml): TODAS as
-- opções de óleo cadastradas pra ele, cada uma com marca, especificação,
-- viscosidade e litragem. "Ambíguo" continua reservado pra quando é
-- realmente uma motorização diferente (não uma opção de óleo diferente).
-- ============================================================================

drop function if exists consultar_orcamento_motor(text, text, text, text);
create or replace function consultar_orcamento_motor(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, marca text, especificacao text, viscosidade text, litros numeric, valor_oleo numeric, valor_filtro numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_motor text;
  v_ano int;
  v_ano_fim_escolhido int;
  v_litros_escolhido numeric;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
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
    return query select 'nao_encontrado'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    -- motorizações diferentes, ou litragem além da tolerância: ambiguidade real.
    return query select 'ambiguo'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  -- um único motor identificado (talvez com litragem variando até 300ml entre
  -- cadastros duplicados): pega o cadastro mais atual como referência de
  -- ano/litros, e devolve TODAS as opções de óleo cadastradas para ele.
  select v.ano_fim, v.litros_oleo_motor into v_ano_fim_escolhido, v_litros_escolhido
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
    p.marca,
    p.especificacao,
    p.viscosidade,
    v.litros_oleo_motor,
    ceil(v.litros_oleo_motor) * p.preco_litro,
    coalesce(f.preco, 0),
    s.preco_mao_obra,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
    and v.ano_fim = v_ano_fim_escolhido
    and v.litros_oleo_motor = v_litros_escolhido
  order by valor_total asc;
end;
$$;

-- registrar_orcamento_motor: passa a aceitar a viscosidade que o cliente
-- confirmou (opcional -- se não vier, mantém o comportamento antigo de
-- pegar a opção mais barata entre as disponíveis, pra não quebrar chamadas
-- já em produção até o n8n ser atualizado pra enviar o parâmetro).
drop function if exists registrar_orcamento_motor(text, text, text, text, text);
create or replace function registrar_orcamento_motor(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null, p_viscosidade text default null)
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
  v_viscosidade text;
  v_ano int;
  v_id_escolhido uuid;
begin
  v_motor := nullif(trim(p_motor), '');
  v_viscosidade := nullif(trim(p_viscosidade), '');
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

  -- entre as opções de óleo do motor identificado, escolhe a que bate com a
  -- viscosidade informada (se veio); senão, a mais barata (comportamento
  -- anterior, mantido por compatibilidade).
  select v.id into v_id_escolhido
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
    and (v_viscosidade is null or trim(lower(p.viscosidade)) = trim(lower(v_viscosidade)))
  order by v.ano_fim desc, (ceil(v.litros_oleo_motor) * p.preco_litro) asc
  limit 1;

  if v_id_escolhido is null then
    -- viscosidade pedida não existe entre as opções desse motor
    return query select 'viscosidade_indisponivel'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

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
