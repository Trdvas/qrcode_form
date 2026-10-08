-- ============================================================================
-- A 0017 trocou o casamento de modelo de "contém a substring" (LIKE '%...%')
-- para "é exatamente igual" -- isso corrigiu Fox colidindo com Spacefox/
-- Crossfox, mas quebrou um caso oposto: "Gol VI" e "Gol VII" são o MESMO
-- nome de modelo ("Gol") com a geração como sufixo no cadastro, e cliente
-- nenhum sabe informar "VI" ou "VII" de cabeça. Com igualdade exata, buscar
-- "Gol" não bate em "Gol VI"/"Gol VII" -> nao_encontrado.
--
-- A regra certa é por PALAVRA inteira, não por substring nem por igualdade
-- total: o modelo buscado tem que ser a primeira palavra do modelo
-- cadastrado (igual, ou seguida de espaço e mais texto) -- nunca no meio de
-- uma palavra.
--   "Gol"  bate em "Gol"      (igual)
--   "Gol"  bate em "Gol VI"   (prefixo de palavra + sufixo de geração)
--   "Gol"  bate em "Gol VII"  (idem)
--   "Gol"  NÃO bate em "Golf"      (é outra palavra, "Golf" != "Gol")
--   "Fox"  NÃO bate em "Spacefox"  ("Spacefox" não começa com "Fox ")
--   "Fox"  NÃO bate em "Crossfox"  (idem)
--   "RAV4" bate em "RAV 4"   (diferença de espaço/pontuação, já tolerada)
--
-- Função auxiliar reaproveitada nas duas funções de motor, pra não repetir
-- a mesma expressão várias vezes.
-- ============================================================================

create or replace function veiculo_modelo_bate(v_modelo text, p_modelo text)
returns boolean
language sql
immutable
as $$
  select
    -- igualdade exata ignorando espaço/pontuação (ex: "RAV4" = "RAV 4")
    regexp_replace(upper(v_modelo), '[^A-Z0-9]', '', 'g')
      = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    or
    -- o termo buscado é a(s) primeira(s) palavra(s) do modelo cadastrado,
    -- seguido de espaço e mais texto (ex: "Gol" é prefixo de palavra de "Gol VI")
    trim(regexp_replace(regexp_replace(upper(v_modelo), '[^A-Z0-9]', ' ', 'g'), '\s+', ' ', 'g'))
      like trim(regexp_replace(regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', ' ', 'g'), '\s+', ' ', 'g')) || ' %'
$$;

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
  where veiculo_modelo_bate(v.modelo, p_modelo)
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
    select v.motor_descricao, count(*) over ()
    into v_motor_escolhido, v_count_padrao
    from veiculos_motor v
    where veiculo_modelo_bate(v.modelo, p_modelo)
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

  select v.ano_fim, v.litros_oleo_motor into v_ano_fim_escolhido, v_litros_escolhido
  from veiculos_motor v
  where veiculo_modelo_bate(v.modelo, p_modelo)
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
  where veiculo_modelo_bate(v.modelo, p_modelo)
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
    and v.ano_fim = v_ano_fim_escolhido
    and v.litros_oleo_motor = v_litros_escolhido
  order by valor_total asc;
end;
$$;

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
  where veiculo_modelo_bate(v.modelo, p_modelo)
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
    where veiculo_modelo_bate(v.modelo, p_modelo)
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

  select v.id into v_id_escolhido
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  where veiculo_modelo_bate(v.modelo, p_modelo)
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

-- Conferência: deve voltar status = ok_versao_padrao, só com dados do Gol VII
-- (não mais nao_encontrado, e sem misturar Gol VI).
select * from consultar_orcamento_motor('Gol', 'Volkswagen', '2017', '1.6');

-- E o Fox continua funcionando sem reabrir a colisão com Spacefox/Crossfox.
select * from consultar_orcamento_motor('Fox', 'Volkswagen', '2016', '1.6');
