-- ============================================================================
-- Resolve o caso de ambiguidade que o cliente não consegue desfazer sozinho
-- (ex: Amarok 2017 motor "2.0" -- existem 3 motorizações cadastradas, todas
-- com a mesma litragem, diferindo só por detalhe técnico que o dono do carro
-- tipicamente não sabe informar: com/sem filtro de particulado, bi-turbo).
--
-- Antes, nesses casos a função sempre devolvia "ambiguo" e o agente ficava
-- pedindo uma informação (litragem) que nem ajudava a desambiguar, porque é
-- igual nas três opções.
--
-- Agora: marca-se qual motorização é a "versão padrão" pra cada grupo
-- ambíguo (veiculos_motor.padrao_ambiguidade). Se exatamente uma das opções
-- candidatas estiver marcada, a função usa ela e devolve status
-- "ok_versao_padrao" em vez de "ok" -- o agente informa o orçamento
-- normalmente, mas avisa que assumiu a versão mais comum e que o cliente
-- pode confirmar na oficina se o motor dele for diferente. Sem marcação
-- (ou mais de uma marcada), continua "ambiguo" como antes.
-- ============================================================================

alter table veiculos_motor add column if not exists padrao_ambiguidade boolean not null default false;

-- Amarok: "2.0 L4 CRDi/TD 16V - C/ DPF (D)" é a configuração padrão no Brasil
-- (filtro de particulado é exigência do PROCONVE desde 2012; a versão S/DPF
-- praticamente não circula aqui, e o Bi-Turbo é uma variante de motorização
-- mais rara/alta performance). Marca essa como padrão.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'amarok'
  and motor_descricao = '2.0 L4 CRDi/TD 16V - C/ DPF (D)';

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
  v_motor_escolhido text;
  v_count_padrao int;
  v_status text;
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

  v_status := 'ok';

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    -- ambiguidade real de motorização: só segue se exatamente UMA das
    -- motorizações candidatas estiver marcada como versão padrão -- nesse
    -- caso, passa a filtrar por ela (motor_descricao exato) em vez do texto
    -- que o cliente informou.
    select v.motor_descricao, count(*) over ()
    into v_motor_escolhido, v_count_padrao
    from veiculos_motor v
    where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
      and trim(lower(v.montadora)) = trim(lower(p_montadora))
      and v_ano between v.ano_inicio and v.ano_fim
      and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
      and v.produto_oleo_motor_id is not null
      and v.servico_motor_id is not null
      and v.padrao_ambiguidade = true;

    if coalesce(v_count_padrao, 0) <> 1 then
      return query select 'ambiguo'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
      return;
    end if;

    v_status := 'ok_versao_padrao';
    v_motor := v_motor_escolhido;
  end if;

  -- um único motor identificado (diretamente, ou via versão padrão marcada
  -- acima, que já deixou v_motor com o texto exato dela): devolve TODAS as
  -- opções de óleo cadastradas para ele.
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
  select v_status,
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

-- registrar_orcamento_motor: mesma lógica de versão padrão.
drop function if exists registrar_orcamento_motor(text, text, text, text, text, text);
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
  v_motor_escolhido text;
  v_count_padrao int;
  v_viscosidade text;
  v_ano int;
  v_id_escolhido uuid;
  v_status_base text;
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

  v_status_base := 'ok';

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    select v.motor_descricao, count(*) over ()
    into v_motor_escolhido, v_count_padrao
    from veiculos_motor v
    where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
      and trim(lower(v.montadora)) = trim(lower(p_montadora))
      and v_ano between v.ano_inicio and v.ano_fim
      and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
      and v.produto_oleo_motor_id is not null
      and v.servico_motor_id is not null
      and v.padrao_ambiguidade = true;

    if coalesce(v_count_padrao, 0) <> 1 then
      return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
      return;
    end if;

    v_status_base := 'ok_versao_padrao';
    v_motor := v_motor_escolhido;
  end if;

  -- entre as opções de óleo do motor identificado, escolhe a que bate com a
  -- viscosidade informada (se veio); senão, a mais barata.
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

  return query select v_status_base, v_orcamento_id, v_veiculo, v_valor;
end;
$$;
